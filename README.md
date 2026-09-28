# Cài đặt XrayR

## Node v2Pro trên nhánh Xray-core 26.9.9

Trong `quick-install.sh`, chọn `NewV2board` cho panel [v2Pro](https://github.com/fsh2502/v2Pro). Chọn node VMess, VLESS, Trojan, Shadowsocks hoặc Hysteria 2 (không obfs), đúng với loại node đã tạo trên panel. Với TLS, chọn chứng chỉ tự ký hoặc đường dẫn PEM sẵn có; với REALITY, chọn chế độ không có chứng chỉ. Hysteria 1, Hysteria 2 có obfs, TUIC và AnyTLS chưa được backend XrayR này hỗ trợ. `v2node` không được dùng ở đây.

Bản thử nghiệm `v0.9.7-rc.5` giữ Xray-core 26.9.9 và dùng commit REALITY ngay trước thay đổi kiểm tra ClientHello mới để tương thích với sing-box/Hiddify. Bản `v0.9.7-rc.3` hoạt động với client Xray-core nhưng bị sing-box 1.14.0 từ chối ở bước xác thực REALITY. `rc.4` vẫn có các sửa lỗi đọc `tls_settings` v2Pro của `rc.3`.

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

Để chọn phiên bản, dùng `bash install.sh v0.9.6`. Bản thử nghiệm nâng Xray-core 26.9.9 không phải bản ổn định; cần chỉ định tag `v0.9.7-rc.5` khi gọi trực tiếp `install.sh`. Trình cài đặt trên nhánh `upgrade-xray-core-26.9.9` kiểm tra SHA-256, giữ nguyên cấu hình, sao lưu binary và tự khôi phục nếu XrayR không khởi động.

Thử bản `v0.9.7-rc.5` trên VPS/node riêng (không thay bản ổn định mặc định). `quick-install.sh` trên nhánh này cũng chọn bản đó khi không đặt `XRAYR_VERSION`:

```bash
XRAYR_VERSION=v0.9.7-rc.5 bash <(curl -fsSL https://raw.githubusercontent.com/fsh2502/XrayR-release/upgrade-xray-core-26.9.9/quick-install.sh)
```

Nếu đã có cấu hình và chỉ muốn nâng binary, dùng `XrayR update v0.9.7-rc.5` hoặc tải `install.sh` trên cùng nhánh rồi gọi `bash install.sh v0.9.7-rc.5`. Với VLESS REALITY từ v2Pro, đặt `DisableLocalREALITYConfig: true` và `EnableREALITY: false` trong `ControllerConfig`, `CertMode: none` trong `CertConfig`; panel phải có `tls=2`, khóa REALITY, `server_name` và `short_id` hợp lệ. Hãy thử client, TLS/REALITY và báo cáo lưu lượng trên node thử nghiệm trước khi nâng node đang phục vụ người dùng.

Sau cài đặt, chạy `XrayR` để mở menu hoặc dùng `XrayR status`, `XrayR log`, `XrayR update [phiên-bản]`. Cấu hình nằm ở `/etc/XrayR/config.yml`; xem [mẫu cấu hình](config/config.yml).

Gỡ cài đặt bằng mục 12 trong menu hoặc `XrayR uninstall`. Lệnh gỡ dừng dịch vụ, xóa service, binary, trình quản lý và liên kết `xrayr`; cấu hình, chứng chỉ và bản sao lưu vẫn được giữ. Sau khi gỡ thành công, màn hình hiện lệnh `rm -rf -- /etc/XrayR /usr/local/XrayR` để bạn tự xóa các thư mục còn lại nếu không cần dữ liệu trong đó.

## Lưu ý tương thích khi nâng lõi

Xray-core 26.9.9 đã bỏ các header vận chuyển cũ `srtp`, `tls`, `utp`, `wechat`, `wireguard`, Shadowsocks `none/plain` và tùy chọn `DisableIVCheck`. Hãy kiểm tra các node trước khi nâng cấp. Để tương thích sing-box, bản `rc.5` chưa áp dụng quy tắc REALITY mới yêu cầu ClientHello có X25519MLKEM768 đứng trước X25519; commit REALITY được chọn vẫn chứa sửa lỗi rò rỉ tài nguyên ngay trước quy tắc đó. Dịch vụ chạy thành công chưa đủ chứng minh client kết nối được; thử từng giao thức, TLS/REALITY và thống kê lưu lượng trên nút thử nghiệm. Bản `v0.9.6` vẫn là lựa chọn ổn định trong lúc kiểm tra.

## Lưu lượng và giới hạn IP trực tuyến trong rc.5

`NewV2board` đọc `device_limit` của từng người dùng từ v2Pro; `ApiConfig.DeviceLimit` lớn hơn 0 sẽ ghi đè giá trị đó. XrayR báo các IP hoạt động về `/api/v1/server/UniProxy/alive`, đọc tổng số IP từ `/alivelist` và từ chối IP mới khi hết suất. Một IP được xem là hoạt động trong 100 giây sau kết nối hoặc lần truyền dữ liệu cuối. Số IP giữa các node được đồng bộ theo chu kỳ `ControllerConfig.UpdatePeriodic` và bộ nhớ đệm 60 giây của panel, nên giới hạn nhiều node có thể trễ trong lúc kết nối đồng thời.

Lưu lượng gửi về `/push` là byte ứng dụng theo hai chiều (lên, xuống). v2Pro áp dụng `rate` của node khi cộng vào hạn mức tài khoản. `rc.5` giữ lại các byte phát sinh trong lúc đợi panel xác nhận báo cáo, và chỉ xóa phần đã gửi khi panel trả `data: true`.

Mã v2Pro gốc còn hai giới hạn trong tác vụ `traffic:update`: truy vấn người dùng chỉ theo danh sách có tải xuống nên có thể bỏ qua phiên chỉ tải lên; thao tác đọc rồi xóa hash Redis có thể mất lượt ghi đồng thời. Vì vậy số liệu tài khoản trên panel chưa được bảo đảm chính xác tuyệt đối cho đến khi sửa riêng tác vụ này trên panel.

## Docker

```bash
git clone https://github.com/fsh2502/XrayR-release.git
cd XrayR-release
docker compose up -d
```

Sửa `config/config.yml` trước khi chạy. `docker-compose.yml` gắn thư mục `./config` vào `/etc/XrayR` và dùng chế độ mạng host. Với bản thử nghiệm, không dùng thẻ ảnh `latest` cho đến khi ảnh của nhánh nâng cấp đã được phát hành và kiểm thử.
