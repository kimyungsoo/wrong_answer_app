import io
import numpy as np
import cv2
import torch
from PIL import Image
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import Response
from contextlib import asynccontextmanager

model_manager = None


def create_handwriting_mask(image_bgr: np.ndarray) -> np.ndarray:
    """
    이미지에서 필기 영역을 자동 감지해 마스크 생성.
    흰 배경 위의 연필/볼펜 필기를 탐지한다.
    """
    hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)

    # 1) 색깔 있는 필기 (파란/빨간 볼펜 등)
    colored_mask = np.zeros(gray.shape, dtype=np.uint8)

    blue_lo, blue_hi = np.array([90, 40, 40]), np.array([130, 255, 255])
    red_lo1, red_hi1 = np.array([0, 40, 40]), np.array([10, 255, 255])
    red_lo2, red_hi2 = np.array([160, 40, 40]), np.array([180, 255, 255])
    green_lo, green_hi = np.array([40, 40, 40]), np.array([85, 255, 255])

    for lo, hi in [(blue_lo, blue_hi), (red_lo1, red_hi1),
                   (red_lo2, red_hi2), (green_lo, green_hi)]:
        colored_mask = cv2.bitwise_or(colored_mask, cv2.inRange(hsv, lo, hi))

    # 2) 연필 자국 (어두운 회색, 채도 낮음)
    _, pencil_mask = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY_INV)
    saturation = hsv[:, :, 1]
    low_sat = cv2.inRange(saturation, 0, 30)
    pencil_mask = cv2.bitwise_and(pencil_mask, low_sat)

    # 3) 인쇄된 텍스트(검정)는 제외 — 매우 어두운 픽셀 마스크 제거
    printed_text = cv2.inRange(gray, 0, 60)
    pencil_mask = cv2.bitwise_and(pencil_mask, cv2.bitwise_not(printed_text))

    mask = cv2.bitwise_or(colored_mask, pencil_mask)

    # 마스크를 살짝 팽창시켜 경계를 부드럽게
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    mask = cv2.dilate(mask, kernel, iterations=2)

    return mask


def inpaint_with_lama(image_bgr: np.ndarray, mask: np.ndarray) -> np.ndarray:
    from iopaint.schema import InpaintRequest, HDStrategy, LDMSampler

    req = InpaintRequest(
        hd_strategy=HDStrategy.ORIGINAL,
        ldm_sampler=LDMSampler.ddim,
    )
    result = model_manager(image_bgr, mask, req)
    return result


@asynccontextmanager
async def lifespan(app: FastAPI):
    global model_manager
    print("LaMa 모델 로딩 중...")
    from iopaint.model_manager import ModelManager
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"사용 디바이스: {device}")
    model_manager = ModelManager(name="lama", device=device)
    print("모델 로딩 완료")
    yield
    model_manager = None


app = FastAPI(title="필기 제거 서버", lifespan=lifespan)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "cuda": torch.cuda.is_available(),
        "gpu": torch.cuda.get_device_name(0) if torch.cuda.is_available() else None,
    }


@app.post("/remove-handwriting")
async def remove_handwriting(file: UploadFile = File(...)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드 가능합니다")

    data = await file.read()
    np_arr = np.frombuffer(data, np.uint8)
    image_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if image_bgr is None:
        raise HTTPException(status_code=400, detail="이미지 디코딩 실패")

    mask = create_handwriting_mask(image_bgr)

    # 필기 감지 안 되면 원본 반환
    if mask.sum() == 0:
        return Response(content=data, media_type="image/jpeg")

    result_bgr = inpaint_with_lama(image_bgr, mask)

    _, encoded = cv2.imencode(".jpg", result_bgr, [cv2.IMWRITE_JPEG_QUALITY, 92])
    return Response(content=encoded.tobytes(), media_type="image/jpeg")
