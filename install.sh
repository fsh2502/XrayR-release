#!/usr/bin/env bash
set -Eeuo pipefail

# Cài đặt/nâng cấp XrayR, giữ nguyên cấu hình và tự khôi phục binary nếu khởi động lỗi.
REPO="${XRAYR_BINARY_REPO:-fsh2502/XrayR-Installer}"
SCRIPT_REPO="${XRAYR_SCRIPT_REPO:-fsh2502/XrayR-Installer}"
SCRIPT_REF="${XRAYR_INSTALL_REF:-v0.9.8}"
INSTALL_DIR="${XRAYR_INSTALL_DIR:-/usr/local/XrayR}"
CONFIG_DIR="${XRAYR_CONFIG_DIR:-/etc/XrayR}"
SERVICE_FILE="${XRAYR_SERVICE_FILE:-/etc/systemd/system/XrayR.service}"
MANAGER_FILE="${XRAYR_MANAGER_FILE:-/usr/bin/XrayR}"
ALIAS_FILE="${XRAYR_ALIAS_FILE:-/usr/bin/xrayr}"
tmp_dir=""

say() { printf '%s\n' "$*"; }
die() { say "Lỗi: $*" >&2; exit 1; }
cleanup() { [[ -z "$tmp_dir" ]] || rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

[[ ${EUID} -eq 0 ]] || die "Hãy chạy bằng tài khoản root."
command -v systemctl >/dev/null || die "Máy chủ phải dùng systemd."

case "$(uname -m)" in
    x86_64|amd64) arch=64 ;;
    aarch64|arm64) arch=arm64-v8a ;;
    s390x) arch=s390x ;;
    *) die "Kiến trúc $(uname -m) chưa được trình cài đặt này hỗ trợ." ;;
esac

for tool in curl unzip sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl unzip coreutils
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y curl unzip coreutils
        elif command -v yum >/dev/null 2>&1; then
            yum install -y curl unzip coreutils
        else
            die "Thiếu $tool; hãy cài curl, unzip và coreutils."
        fi
        break
    fi
done

version="${1:-}"
if [[ -z "$version" ]]; then
    version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
    [[ -n "$version" ]] || die "Không tìm thấy bản phát hành ổn định mới nhất. Có thể chỉ định phiên bản: bash install.sh v0.9.6"
fi
[[ "$version" == v* ]] || version="v${version}"
[[ "$version" =~ ^v[0-9A-Za-z][0-9A-Za-z._-]*$ ]] || die "Phiên bản không hợp lệ."

tmp_dir=$(mktemp -d)
asset="XrayR-linux-${arch}.zip"
base="https://github.com/${REPO}/releases/download/${version}/${asset}"
say "Đang tải XrayR ${version} (${arch})..."
curl -fL --retry 3 -o "$tmp_dir/$asset" "$base" || die "Không tải được gói cài đặt."
curl -fL --retry 3 -o "$tmp_dir/$asset.dgst" "$base.dgst" || die "Không tải được mã kiểm tra SHA-256."
expected=$(tr -d '\r' < "$tmp_dir/$asset.dgst" | awk 'tolower($1) ~ /sha.*256/ {print $NF}' | tail -n 1)
[[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || die "Mã SHA-256 trong bản phát hành không hợp lệ."
actual=$(sha256sum "$tmp_dir/$asset" | awk '{print $1}')
[[ "${actual,,}" == "${expected,,}" ]] || die "SHA-256 không khớp; không thay đổi bản đang chạy."
unzip -p "$tmp_dir/$asset" XrayR > "$tmp_dir/XrayR" || die "Gói cài đặt thiếu binary XrayR."
chmod 755 "$tmp_dir/XrayR"
"$tmp_dir/XrayR" version >/dev/null || die "Binary mới không chạy được trên máy chủ này."
if [[ ! -f "$SERVICE_FILE" ]]; then
    curl -fsSL "https://raw.githubusercontent.com/${SCRIPT_REPO}/${SCRIPT_REF}/XrayR.service" \
        -o "$tmp_dir/XrayR.service" || die "Không tải được tệp dịch vụ systemd."
fi

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$INSTALL_DIR/backups"
backup=""
if [[ -f "$INSTALL_DIR/XrayR" ]]; then
    backup="$INSTALL_DIR/backups/XrayR.$(date +%Y%m%d-%H%M%S)"
    cp -p "$INSTALL_DIR/XrayR" "$backup"
    say "Đã sao lưu binary cũ: $backup"
fi

was_active=0
if systemctl is-active --quiet XrayR; then was_active=1; fi
systemctl stop XrayR 2>/dev/null || true
install -m 755 "$tmp_dir/XrayR" "$INSTALL_DIR/XrayR"

if [[ ! -f "$SERVICE_FILE" ]]; then
    install -m 644 "$tmp_dir/XrayR.service" "$SERVICE_FILE"
fi

for name in config.yml dns.json route.json custom_outbound.json custom_inbound.json rulelist geoip.dat geosite.dat; do
    if [[ ! -f "$CONFIG_DIR/$name" ]]; then
        if unzip -p "$tmp_dir/$asset" "$name" > "$tmp_dir/$name" 2>/dev/null; then
            install -m 644 "$tmp_dir/$name" "$CONFIG_DIR/$name"
        fi
    fi
done

systemctl daemon-reload
if [[ -z "$backup" ]]; then systemctl enable XrayR >/dev/null; fi
if [[ "$was_active" -eq 1 ]]; then
    systemctl start XrayR || true
    sleep 3
    if ! systemctl is-active --quiet XrayR; then
        say "Bản mới không khởi động được. Đang khôi phục binary cũ..." >&2
        systemctl stop XrayR 2>/dev/null || true
        if [[ -n "$backup" ]]; then
            install -m 755 "$backup" "$INSTALL_DIR/XrayR"
            systemctl start XrayR || true
        fi
        die "Nâng cấp thất bại. Xem: journalctl -u XrayR -n 50 --no-pager"
    fi
fi

curl -fsSL "https://raw.githubusercontent.com/${SCRIPT_REPO}/${SCRIPT_REF}/XrayR.sh" \
    -o "$tmp_dir/XrayR.sh" && install -m 755 "$tmp_dir/XrayR.sh" "$MANAGER_FILE" || true
if [[ ! -e "$ALIAS_FILE" && ! -L "$ALIAS_FILE" ]]; then ln -s "$MANAGER_FILE" "$ALIAS_FILE"; fi

say "Đã cài XrayR ${version}. Cấu hình cũ được giữ tại $CONFIG_DIR."
if [[ "$was_active" -eq 0 && -z "$backup" ]]; then
    say "Cài đặt mới: hãy cấu hình $CONFIG_DIR/config.yml rồi chạy systemctl start XrayR."
elif [[ "$was_active" -eq 0 ]]; then
    say "Dịch vụ trước đó đang dừng và vẫn được giữ ở trạng thái dừng."
else
    say "Trạng thái: $(systemctl is-active XrayR 2>/dev/null || true). Xem log: XrayR log"
fi
