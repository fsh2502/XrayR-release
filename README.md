# Cài đặt XrayR v0.9.8

Hỗ trợ máy chủ Linux `amd64`, `arm64` hoặc `s390x` dùng systemd. Chạy bằng tài khoản root hoặc `sudo`. Trình cài sẽ tự chọn binary theo kiến trúc và kiểm tra SHA-256 trước khi cài.

## Cài nhanh và cấu hình node

```bash
curl -fsSLo quick-install.sh https://raw.githubusercontent.com/fsh2502/XrayR-release/v0.9.8/quick-install.sh
sudo bash quick-install.sh
```

Nhập tên miền, loại panel, địa chỉ API, API key, ID node và giao thức theo hướng dẫn. Với panel v2Pro, chọn `NewV2board`. Trình cài tạo `/etc/XrayR/config.yml` và khởi động dịch vụ.

## Cài thủ công hoặc nâng cấp

```bash
curl -fsSLo install.sh https://raw.githubusercontent.com/fsh2502/XrayR-release/v0.9.8/install.sh
sudo bash install.sh v0.9.8
sudo nano /etc/XrayR/config.yml
sudo systemctl start XrayR
sudo systemctl status XrayR --no-pager
```

Khi cài lần đầu, sửa `ApiHost`, `ApiKey`, `NodeID` và `NodeType` trong cấu hình mẫu trước khi khởi động. Khi nâng cấp, trình cài giữ cấu hình hiện có và sao lưu binary cũ. Xem lỗi khởi động bằng `journalctl -u XrayR -n 50 --no-pager`.

## Cài từ gói độc lập

Chép tệp `XrayR-standalone-v0.9.8.zip` lên máy chủ, rồi chạy:

```bash
unzip XrayR-standalone-v0.9.8.zip
cd XrayR-standalone-v0.9.8
sudo bash quick-install.sh
```

Gói này chứa sẵn binary cho ba kiến trúc trên, nên không cần tải binary khi cài. Để tự sửa cấu hình, chạy `sudo bash install.sh`, chỉnh `/etc/XrayR/config.yml`, rồi `sudo systemctl start XrayR`.
