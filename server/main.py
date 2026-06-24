import asyncio
import base64
import json
import re
import numpy as np
import cv2
import torch
import ollama
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import Response
from contextlib import asynccontextmanager

model_manager = None
sam_predictor = None
_gpu_semaphore = None
_waiting_count = 0

SAM_CHECKPOINT = "sam_vit_b_01ec64.pth"


def detect_handwriting_boxes_llava(image_bgr: np.ndarray) -> list:
    h, w = image_bgr.shape[:2]
    _, encoded = cv2.imencode('.jpg', image_bgr, [cv2.IMWRITE_JPEG_QUALITY, 85])
    img_base64 = base64.b64encode(encoded.tobytes()).decode('utf-8')

    prompt = (
        f"This is a Korean textbook page ({w}x{h} pixels). "
        "Find all handwritten marks (student annotations, pen or pencil writing) "
        "that are NOT part of the original printed content. "
        "Return ONLY a JSON array of pixel bounding boxes: "
        '[{"x1":int,"y1":int,"x2":int,"y2":int}]. '
        "If no handwriting found, return []. No other text."
    )

    try:
        response = ollama.chat(
            model='llava',
            messages=[{
                'role': 'user',
                'content': prompt,
                'images': [img_base64]
            }]
        )
        text = response['message']['content']
        match = re.search(r'\[.*?\]', text, re.DOTALL)
        if not match:
            return []

        boxes = json.loads(match.group())
        valid = []
        for b in boxes:
            x1 = max(0, min(int(b.get('x1', 0)), w - 1))
            y1 = max(0, min(int(b.get('y1', 0)), h - 1))
            x2 = max(0, min(int(b.get('x2', w)), w))
            y2 = max(0, min(int(b.get('y2', h)), h))
            if x2 - x1 > 5 and y2 - y1 > 5:
                valid.append([x1, y1, x2, y2])
        print(f"LLaVA 감지 영역: {len(valid)}개 → {valid}")
        return valid
    except Exception as e:
        print(f"LLaVA 오류: {e}")
        return []


def create_mask_with_sam(image_bgr: np.ndarray, boxes: list) -> np.ndarray:
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    sam_predictor.set_image(image_rgb)

    combined = np.zeros(image_bgr.shape[:2], dtype=np.uint8)
    for box in boxes:
        masks, _, _ = sam_predictor.predict(
            box=np.array(box, dtype=float)[None, :],
            multimask_output=False,
        )
        combined = cv2.bitwise_or(combined, (masks[0] * 255).astype(np.uint8))
    return combined


def _run_pipeline(image_bgr: np.ndarray) -> np.ndarray:
    from iopaint.schema import InpaintRequest, HDStrategy, LDMSampler

    boxes = detect_handwriting_boxes_llava(image_bgr)
    if not boxes:
        print("필기 없음 → 원본 반환")
        return image_bgr

    mask = create_mask_with_sam(image_bgr, boxes)
    if mask.sum() == 0:
        return image_bgr

    req = InpaintRequest(hd_strategy=HDStrategy.ORIGINAL, ldm_sampler=LDMSampler.ddim)
    return model_manager(image_bgr, mask, req)


@asynccontextmanager
async def lifespan(app: FastAPI):
    global model_manager, sam_predictor, _gpu_semaphore
    _gpu_semaphore = asyncio.Semaphore(1)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"디바이스: {device}")

    print("LaMa 로딩 중...")
    from iopaint.model_manager import ModelManager
    model_manager = ModelManager(name="lama", device=device)

    print("SAM 로딩 중...")
    from segment_anything import sam_model_registry, SamPredictor
    sam = sam_model_registry["vit_b"](checkpoint=SAM_CHECKPOINT)
    sam.to(device)
    sam_predictor = SamPredictor(sam)

    print("모든 모델 로딩 완료")
    yield
    model_manager = None
    sam_predictor = None


app = FastAPI(title="필기 제거 서버", lifespan=lifespan)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "cuda": torch.cuda.is_available(),
        "gpu": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None,
        "waiting": _waiting_count,
    }


@app.post("/remove-handwriting")
async def remove_handwriting(file: UploadFile = File(...)):
    global _waiting_count

    if (file.content_type
            and not file.content_type.startswith("image/")
            and file.content_type != "application/octet-stream"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드 가능합니다")

    data = await file.read()
    np_arr = np.frombuffer(data, np.uint8)
    image_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if image_bgr is None:
        raise HTTPException(status_code=400, detail="이미지 디코딩 실패")

    _waiting_count += 1
    try:
        async with _gpu_semaphore:
            _waiting_count -= 1
            loop = asyncio.get_event_loop()
            result_bgr = await loop.run_in_executor(None, _run_pipeline, image_bgr)
    except Exception:
        _waiting_count -= 1
        raise

    _, encoded = cv2.imencode(".jpg", result_bgr, [cv2.IMWRITE_JPEG_QUALITY, 92])
    return Response(content=encoded.tobytes(), media_type="image/jpeg")
