# Backend kiểm chứng tùy chọn

Ứng dụng Android không dùng backend này để nhận diện. Thư mục được giữ lại để
đối chiếu checkpoint, số liệu nghiên cứu và thử API trên máy phát triển khi cần.
E4 được nạp khi server khởi động; E0/E1 chỉ được nạp lần đầu khi được yêu cầu.

```powershell
python -m pip install -r backend\requirements.txt
python -m uvicorn backend.app:app --host 0.0.0.0 --port 8000
```

Mặc định API đọc đúng các artifact tại `E:\KLTN`. Có thể đổi bằng biến môi
trường `E0_CHECKPOINT`, `E1_CHECKPOINT`, `E4_CHECKPOINT`, `E4_RESULTS_CSV`,
`E1_RESULTS_SOURCE` và `E1_PREDICTIONS`.

Thiết lập demo được trả cùng mỗi dự đoán: ảnh 512 px, confidence mặc định 0.25,
IoU 0.70, không class-agnostic NMS và không có bộ lọc/ghép box tự viết. Latency
là số đo thực của riêng yêu cầu trên thiết bị chạy server, gồm preprocess,
inference và postprocess; đây không phải AP/mAP.
