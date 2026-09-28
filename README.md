# Cài đặt XrayR

Kho này chứa trình cài đặt, trình quản lý, mẫu cấu hình và tệp Docker cho [XrayR](https://github.com/fsh2502/XrayR). Giao diện và hướng dẫn được viết bằng tiếng Việt; các khóa cấu hình YAML giữ nguyên tên để tương thích.

## Cài nhanh có hướng dẫn

```bash
curl -fsSL https://raw.githubusercontent.com/fsh2502/XrayR-release/master/quick-install.sh -o quick-install.sh
bash quick-install.sh
```

Nhập tên miền, loại panel, địa chỉ và khóa API, ID node, loại node. Script ghi `/etc/XrayR/config.yml` và sao lưu cấu hình cũ. Với Trojan TLS, script tạo chứng chỉ tự ký ở `/etc/XrayR/cert/`. Client phải tin cậy chứng chỉ hoặc bật `allowInsecure`; nếu dùng công khai, nên thay bằng chứng chỉ CA đáng tin cậy. Node trên panel phải bật TLS và dùng đúng tên miền.

## Cài thủ công hoặc nâng cấp

```bash
curl -fsSL https://raw.githubusercontent.com/fsh2502/XrayR-release/master/install.sh -o install.sh
bash install.sh
```

Để chọn phiên bản, dùng `bash install.sh v0.9.6`. Bản thử nghiệm nâng Xray-core 26.9.9 chưa phải bản ổn định; sau khi có tag thử nghiệm, chỉ định tag của bản đó. Trình cài đặt trên nhánh `upgrade-xray-core-26.9.9` kiểm tra SHA-256, giữ nguyên cấu hình, sao lưu binary và tự khôi phục nếu XrayR không khởi động.

Sau cài đặt, chạy `XrayR` để mở menu hoặc dùng `XrayR status`, `XrayR log`, `XrayR update [phiên-bản]`. Cấu hình nằm ở `/etc/XrayR/config.yml`; xem [mẫu cấu hình](config/config.yml).

## Lưu ý tương thích khi nâng lõi

Xray-core 26.9.9 đã bỏ các header vận chuyển cũ `srtp`, `tls`, `utp`, `wechat`, `wireguard`, Shadowsocks `none/plain` và tùy chọn `DisableIVCheck`. Hãy kiểm tra các node trước khi nâng cấp. Dịch vụ chạy thành công chưa đủ chứng minh client kết nối được; thử từng giao thức, TLS/REALITY và thống kê lưu lượng trên nút thử nghiệm. Bản `v0.9.6` vẫn là lựa chọn ổn định trong lúc kiểm tra.

## Docker

```bash
git clone https://github.com/fsh2502/XrayR-release.git
cd XrayR-release
docker compose up -d
```

Sửa `config/config.yml` trước khi chạy. `docker-compose.yml` gắn thư mục `./config` vào `/etc/XrayR` và dùng chế độ mạng host. Với bản thử nghiệm, không dùng thẻ ảnh `latest` cho đến khi ảnh của nhánh nâng cấp đã được phát hành và kiểm thử.
