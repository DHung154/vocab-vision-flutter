"""FastAPI inference service for the thesis Flutter demo.

The service keeps each selected YOLO checkpoint in memory after its first load.
It does not train, alter checkpoints, or add a custom box-merging stage.
"""

from __future__ import annotations

import csv
import io
import os
import statistics
import threading
import time
from functools import lru_cache
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image, ImageOps, UnidentifiedImageError
from ultralytics import YOLO


EXPECTED_CLASSES = [
    "abacus",
    "backpack",
    "chalk",
    "chalkboard",
    "crayon",
    "cup",
    "eraser",
    "glue_stick",
    "kids_chair",
    "notebook",
    "paintbrush",
    "pencil",
    "pencil_sharpener",
    "ruler",
    "scissors",
]

MODELS = {
    "e0": {
        "label": "YOLO26-S — Cơ sở (đối chứng)",
        "checkpoint": Path(
            os.getenv(
                "E0_CHECKPOINT",
                r"E:\KLTN\runs\E0_yolo26s_seed0\weights\best.pt",
            )
        ),
    },
    "e1": {
        "label": "YOLO26-S — InterpIoU cố định",
        "checkpoint": Path(
            os.getenv(
                "E1_CHECKPOINT",
                r"E:\KLTN\runs\E1_interpiou_seed0\weights\best.pt",
            )
        ),
    },
    "e4": {
        "label": "YOLO26-S — E4 (nhóm đề xuất)",
        "checkpoint": Path(
            os.getenv(
                "E4_CHECKPOINT",
                r"E:\KLTN\runs\E4_balanced_seed0\weights\best.pt",
            )
        ),
    },
}

SUMMARY_PATH = Path(
    os.getenv(
        "E4_RESULTS_CSV",
        r"E:\KLTN\outputs\yolo_seed_test_fixed\summary.csv",
    )
)
E1_REPORTED_SOURCE = Path(
    os.getenv(
        "E1_RESULTS_SOURCE",
        r"E:\KLTN\analysis\fair_rewrite_teacher_notes_20260825\source_content.txt",
    )
)
E1_PREDICTIONS_PATH = Path(
    os.getenv(
        "E1_PREDICTIONS",
        r"E:\KLTN\outputs\preds_yolo\E1_test.json",
    )
)

REPORTED_SEED0 = {
    "E0": {"AP50": 0.819106, "AP75": 0.770006, "mAP50_95": 0.735504},
    "E1": {"AP50": 0.805292, "AP75": 0.758314, "mAP50_95": 0.728457},
    "E4": {"AP50": 0.822160, "AP75": 0.771408, "mAP50_95": 0.738551},
}

MAX_UPLOAD_BYTES = 20 * 1024 * 1024
DEMO_IOU_THRESHOLD = 0.7
_model_locks = {model_id: threading.Lock() for model_id in MODELS}
_loaded_model_ids: set[str] = set()

app = FastAPI(title="Vocab Vision E4 API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


def _class_names(model: YOLO) -> list[str]:
    names = model.names
    if isinstance(names, dict):
        keys = sorted(names)
        if keys != list(range(len(EXPECTED_CLASSES))):
            raise RuntimeError(f"Class ID không liên tục 0..14: {keys}")
        return [str(names[index]) for index in keys]
    return [str(name) for name in names]


@lru_cache(maxsize=len(MODELS))
def load_model(model_id: str) -> YOLO:
    """Load a registered checkpoint once, then reuse that exact instance."""
    config = MODELS.get(model_id)
    if config is None:
        raise ValueError(f"Model không được hỗ trợ: {model_id}")
    checkpoint = config["checkpoint"]
    if not checkpoint.is_file():
        raise FileNotFoundError(f"Không tìm thấy checkpoint: {checkpoint}")

    model = YOLO(str(checkpoint))
    actual_names = _class_names(model)
    if actual_names != EXPECTED_CLASSES:
        raise RuntimeError(
            "Checkpoint sai class map. "
            f"Mong đợi {EXPECTED_CLASSES}, nhận được {actual_names}."
        )
    _loaded_model_ids.add(model_id)
    return model


def _read_summary() -> list[dict[str, str]]:
    if not SUMMARY_PATH.is_file():
        raise FileNotFoundError(f"Không tìm thấy tệp kết quả: {SUMMARY_PATH}")
    with SUMMARY_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    required = {"method", "seed", "AP50", "AP75", "mAP50_95"}
    if not rows or not required.issubset(rows[0]):
        raise ValueError(f"Sai cấu trúc summary.csv; cần các cột {sorted(required)}")
    return rows


def _row_metrics(row: dict[str, str]) -> dict[str, float]:
    return {key: float(row[key]) for key in ("AP50", "AP75", "mAP50_95")}


def research_payload() -> dict:
    rows = _read_summary()
    by_method: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        by_method.setdefault(row["method"], []).append(row)

    differences: list[str] = []
    seed0: dict[str, dict] = {}
    labels = {
        "E0": "YOLO26-S cơ sở",
        "E1": "InterpIoU cố định",
        "E4": "E4 affine + EMA",
    }

    for method in ("E0", "E4"):
        matching = [row for row in by_method.get(method, []) if int(row["seed"]) == 0]
        if len(matching) != 1:
            differences.append(
                f"summary.csv cần đúng một dòng {method}, seed 0; hiện có {len(matching)}."
            )
            continue
        metrics = _row_metrics(matching[0])
        seed0[method] = {"method": method, "label": labels[method], **metrics}
        for metric, reported in REPORTED_SEED0[method].items():
            if abs(metrics[metric] - reported) > 0.0000005:
                differences.append(
                    f"{method} seed 0 {metric}: artifact={metrics[metric]:.9f}, "
                    f"đã báo cáo={reported:.6f}."
                )

    # summary.csv intentionally contains only the repeated-seed E0/E4 study.
    # E1 is the locked seed-0 reference from the separately verified report source.
    if not E1_REPORTED_SOURCE.is_file():
        differences.append(f"Không tìm thấy nguồn số liệu E1: {E1_REPORTED_SOURCE}")
    else:
        source_text = E1_REPORTED_SOURCE.read_text(encoding="utf-8", errors="replace")
        expected_tokens = ("0,805292", "0,758314", "0,728457")
        if not all(token in source_text for token in expected_tokens):
            differences.append("Nguồn E1 không chứa đủ ba giá trị seed 0 đã báo cáo.")
    if not E1_PREDICTIONS_PATH.is_file():
        differences.append(f"Không tìm thấy prediction fixed-test E1: {E1_PREDICTIONS_PATH}")
    seed0["E1"] = {
        "method": "E1",
        "label": labels["E1"],
        **REPORTED_SEED0["E1"],
    }

    aggregate: dict[str, dict] = {}
    for method in ("E0", "E4"):
        method_rows = sorted(by_method.get(method, []), key=lambda row: int(row["seed"]))
        seeds = [int(row["seed"]) for row in method_rows]
        if seeds != [0, 1, 2]:
            differences.append(
                f"{method}: cần các seed [0, 1, 2] trong summary.csv, nhận được {seeds}."
            )
            continue
        aggregate[method] = {
            "method": method,
            "label": labels[method],
            "seed_count": len(method_rows),
            "seeds": seeds,
            "mean": {
                metric: statistics.mean(float(row[metric]) for row in method_rows)
                for metric in ("AP50", "AP75", "mAP50_95")
            },
            "sample_std": {
                metric: statistics.stdev(float(row[metric]) for row in method_rows)
                for metric in ("AP50", "AP75", "mAP50_95")
            },
        }

    return {
        "title": "Kết quả thực nghiệm E4",
        "artifact_matches_reported": not differences,
        "differences": differences,
        "seed0": [seed0[key] for key in ("E0", "E1", "E4") if key in seed0],
        "three_seed": [aggregate[key] for key in ("E0", "E4") if key in aggregate],
        "sources": {
            "summary_csv": str(SUMMARY_PATH),
            "e1_seed0": str(E1_REPORTED_SOURCE),
            "e1_predictions": str(E1_PREDICTIONS_PATH),
            "note": "summary.csv chỉ chứa E0/E4; E1 là kết quả seed 0 từ bảng kiểm thử đã khóa.",
        },
        "protocol": {
            "split": "fixed test",
            "seed0": 0,
            "three_seed": "seed 0, 1, 2; mean và sample standard deviation (n-1)",
            "evaluator": "faster-coco-eval 1.7.2 theo giao thức đánh giá gốc",
        },
    }


@app.get("/health")
def health() -> dict:
    status = {
        model_id: {
            "label": config["label"],
            "checkpoint": str(config["checkpoint"]),
            "checkpoint_exists": config["checkpoint"].is_file(),
            "loaded": model_id in _loaded_model_ids,
        }
        for model_id, config in MODELS.items()
    }
    return {
        "status": "ok" if all(item["checkpoint_exists"] for item in status.values()) else "error",
        "models": status,
        "summary_exists": SUMMARY_PATH.is_file(),
    }


@app.get("/models")
def models() -> dict:
    return {
        "models": [
            {
                "id": model_id,
                "label": config["label"],
                "available": config["checkpoint"].is_file(),
            }
            for model_id, config in MODELS.items()
        ],
        "default_model_id": "e4",
    }


@app.get("/research-results")
def research_results() -> dict:
    try:
        return research_payload()
    except (FileNotFoundError, ValueError) as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.post("/predict")
async def predict(
    file: UploadFile = File(...),
    selected_model: str = Form("e4", alias="model_id"),
    confidence: float = Form(0.25),
) -> dict:
    model_id = selected_model
    if model_id not in MODELS:
        raise HTTPException(status_code=400, detail=f"Model không được hỗ trợ: {model_id}")
    if not 0.0 < confidence <= 1.0:
        raise HTTPException(status_code=400, detail="confidence phải nằm trong (0, 1].")
    if (
        file.content_type
        and file.content_type != "application/octet-stream"
        and not file.content_type.startswith("image/")
    ):
        raise HTTPException(status_code=415, detail="Đầu vào phải là tệp ảnh.")

    raw = await file.read(MAX_UPLOAD_BYTES + 1)
    if not raw:
        raise HTTPException(status_code=400, detail="Tệp ảnh rỗng.")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Ảnh vượt quá giới hạn 20 MB.")
    try:
        image = ImageOps.exif_transpose(Image.open(io.BytesIO(raw))).convert("RGB")
    except (UnidentifiedImageError, OSError) as error:
        raise HTTPException(status_code=400, detail="Không đọc được dữ liệu ảnh.") from error

    try:
        model = load_model(model_id)
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        raise HTTPException(status_code=503, detail=str(error)) from error

    started = time.perf_counter()
    with _model_locks[model_id]:
        predictions = model.predict(
            source=image,
            imgsz=512,
            conf=confidence,
            iou=DEMO_IOU_THRESHOLD,
            agnostic_nms=False,
            verbose=False,
        )
    latency_ms = (time.perf_counter() - started) * 1000.0

    result = predictions[0]
    names = _class_names(model)
    detections = []
    if result.boxes is not None:
        boxes = result.boxes.xyxy.detach().cpu().tolist()
        scores = result.boxes.conf.detach().cpu().tolist()
        class_ids = result.boxes.cls.detach().cpu().tolist()
        for box, score, raw_class_id in zip(boxes, scores, class_ids):
            class_id = int(raw_class_id)
            detections.append(
                {
                    "class_id": class_id,
                    "label": names[class_id],
                    "confidence": float(score),
                    "box": [float(value) for value in box],
                }
            )

    height, width = result.orig_shape
    try:
        device = str(next(model.model.parameters()).device)
    except StopIteration:
        device = "unknown"
    return {
        "image_width": int(width),
        "image_height": int(height),
        "detections": detections,
        "model_id": model_id,
        "model_label": MODELS[model_id]["label"],
        "latency_ms": latency_ms,
        "device": device,
        "latency_scope": "server preprocess + inference + postprocess của yêu cầu này",
        "demo_settings": {
            "confidence_threshold": confidence,
            "iou_threshold": DEMO_IOU_THRESHOLD,
            "image_size": 512,
            "agnostic_nms": False,
            "custom_overlap_filter": False,
            "postprocess": "Ultralytics mặc định của checkpoint; không thêm lọc/ghép box tùy chỉnh",
        },
    }


@app.on_event("startup")
def preload_e4() -> None:
    """Fail early and keep the proposed E4 model ready for later requests."""
    load_model("e4")
