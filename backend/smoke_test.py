"""Run real API inference against one fixed-test image without training."""

import io
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image

from backend.app import app, load_model


SAMPLE_IMAGE = str(
    Path(r"E:\KLTN\school-objects.v1i.yolo26\test\images")
    / "abacus_024b62c32524_jpg.rf.ca7bad72dc5185727cd71bb3cba4edf5.jpg"
)


def main() -> None:
    with TestClient(app) as client:
        print("startup_cache", load_model.cache_info())
        for model_id in ("e4", "e0", "e4", "e1"):
            with open(SAMPLE_IMAGE, "rb") as image:
                response = client.post(
                    "/predict",
                    files={"file": ("sample.jpg", image, "image/jpeg")},
                    data={"model_id": model_id, "confidence": "0.25"},
                )
            payload = response.json()
            print(
                model_id,
                response.status_code,
                payload.get("model_id"),
                payload.get("model_label"),
                payload.get("image_width"),
                payload.get("image_height"),
                len(payload.get("detections", [])),
                round(payload.get("latency_ms", 0), 2),
                payload.get("device"),
            )
            assert response.status_code == 200, payload
            assert payload["model_id"] == model_id
            assert payload["image_width"] > 0 and payload["image_height"] > 0
            assert all(0 <= item["class_id"] < 15 for item in payload["detections"])
            assert all(
                0 <= item["box"][0] <= item["box"][2] <= payload["image_width"]
                and 0 <= item["box"][1] <= item["box"][3] <= payload["image_height"]
                for item in payload["detections"]
            )

        invalid = client.post(
            "/predict",
            files={"file": ("bad.txt", b"not-an-image", "text/plain")},
            data={"model_id": "e4"},
        )
        assert invalid.status_code == 415

        unknown_model = client.post(
            "/predict",
            files={"file": ("sample.jpg", b"image", "image/jpeg")},
            data={"model_id": "not-registered"},
        )
        assert unknown_model.status_code == 400

        non_square_bytes = io.BytesIO()
        Image.new("RGB", (640, 360), "white").save(non_square_bytes, format="JPEG")
        non_square = client.post(
            "/predict",
            files={
                "file": (
                    "non-square.jpg",
                    non_square_bytes.getvalue(),
                    "application/octet-stream",
                )
            },
            data={"model_id": "e4"},
        )
        assert non_square.status_code == 200, non_square.text
        assert non_square.json()["image_width"] == 640
        assert non_square.json()["image_height"] == 360
        assert all(
            0 <= item["box"][0] <= item["box"][2] <= 640
            and 0 <= item["box"][1] <= item["box"][3] <= 360
            for item in non_square.json()["detections"]
        )

        research = client.get("/research-results")
        assert research.status_code == 200, research.text
        assert research.json()["artifact_matches_reported"] is True
        print("final_cache", load_model.cache_info())
        print("research", research.status_code, True)


if __name__ == "__main__":
    main()
