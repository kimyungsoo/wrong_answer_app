import asyncio
import numpy as np
import cv2
import torch
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import Response
from contextlib import asynccontextmanager

model_manager = None
_gpu_semaphore = None
_waiting_count = 0
_ocr = None


def detect_handwriting_mask(image_bgr: np.ndarray) -> np.ndarray:
    h, w = image_bgr.shape[:2]

    protected = np.zeros((h, w), dtype=np.uint8)

    # PaddleOCR로 인쇄 텍스트 영역 보호
    result = _ocr.ocr(image_bgr)
    text_count = 0
    if result and result[0]:
        for line in result[0]:
            if not line:
                continue
            box = np.array(line[0], dtype=np.int32)
            box[:, 0] = np.clip(box[:, 0], 0, w)
            box[:, 1] = np.clip(box[:, 1], 0, h)
            cv2.fillPoly(protected, [box], 255)
            text_count += 1

    # 그림/도표 보호: 큰 사각형 윤곽선 검출
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 30, 100)
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    figure_count = 0
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area > h * w * 0.005:  # 전체 이미지의 0.5% 이상인 큰 영역
            x, y, cw, ch = cv2.boundingRect(cnt)
            cv2.rectangle(protected, (x, y), (x + cw, y + ch), 255, -1)
            figure_count += 1

    print(f"텍스트 보호: {text_count}개, 그림 보호: {figure_count}개")

    # 보호 영역 여백 확장
    kernel = np.ones((10, 10), np.uint8)
    protected = cv2.dilate(protected, kernel, iterations=1)

    # 어두운 픽셀 감지
    _, dark = cv2.threshold(gray, 140, 255, cv2.THRESH_BINARY_INV)

    # 보호 영역 제외 = 필기 후보
    handwriting = cv2.bitwise_and(dark, cv2.bitwise_not(protected))

    # 노이즈 제거
    kernel_open = np.ones((3, 3), np.uint8)
    handwriting = cv2.morphologyEx(handwriting, cv2.MORPH_OPEN, kernel_open)

    # 마스크 팽창
    kernel_dilate = np.ones((5, 5), np.uint8)
    handwriting = cv2.dilate(handwriting, kernel_dilate, iterations=2)

    pixel_count = int(np.sum(handwriting > 0))
    print(f"필기 후보 픽셀: {pixel_count}개")
    return handwriting


def _run_pipeline(image_bgr: np.ndarray) -> np.ndarray:
    from iopaint.schema import InpaintRequest, HDStrategy, LDMSampler

    mask = detect_handwriting_mask(image_bgr)
    if mask.sum() == 0:
        print("필기 없음 → 원본 반환")
        return image_bgr

    req = InpaintRequest(hd_strategy=HDStrategy.ORIGINAL, ldm_sampler=LDMSampler.ddim)
    return model_manager(image_bgr, mask, req)


@asynccontextmanager
async def lifespan(app: FastAPI):
    global model_manager, _gpu_semaphore, _ocr
    _gpu_semaphore = asyncio.Semaphore(1)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"디바이스: {device}")

    print("PaddleOCR 로딩 중...")
    from paddleocr import PaddleOCR
    _ocr = PaddleOCR(lang='korean')

    print("LaMa 로딩 중...")
    from iopaint.model_manager import ModelManager
    model_manager = ModelManager(name="lama", device=device)

    print("모든 모델 로딩 완료")
    yield
    model_manager = None
    _ocr = None


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
