#!/usr/bin/env bash
set -u

SCRIPT_REF="${XRAYR_INSTALL_REF:-upgrade-xray-core-26.9.9}"
BASE_URL="https://raw.githubusercontent.com/fsh2502/XrayR-release/${SCRIPT_REF}"
CONFIG_FILE="/etc/XrayR/config.yml"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
BINARY="/usr/local/XrayR/XrayR"

error() { printf 'Lỗi: %s\n' "$*" >&2; return 1; }
installed() { [[ -f "$SERVICE_FILE" && -x "$BINARY" ]]; }
require_root() { [[ ${EUID} -eq 0 ]] || error "Hãy chạy lệnh này bằng root."; }
require_install() { installed || error "XrayR chưa được cài đặt."; }

download_install() {
    local temp_file
    temp_file=$(mktemp) || return 1
    if ! curl -fsSL "${BASE_URL}/install.sh" -o "$temp_file"; then
        rm -f -- "$temp_file"
        return 1
    fi
    bash "$temp_file" "${1:-}"
    local result=$?
    rm -f -- "$temp_file"
    return "$result"
}

install_xrayr() { require_root && download_install "${1:-}"; }
update_xrayr() { require_root && require_install && download_install "${1:-}"; }

edit_config() {
    require_root && require_install || return 1
    "${EDITOR:-vi}" "$CONFIG_FILE" || return 1
    printf 'Khởi động lại XrayR để áp dụng cấu hình? [Y/n]: '
    local answer
    read -r answer
    case "${answer:-y}" in
        y|Y|yes|YES) systemctl restart XrayR && systemctl status XrayR --no-pager -l ;;
    esac
}

uninstall_xrayr() {
    require_root && require_install || return 1
    printf 'Gỡ XrayR? Cấu hình trong /etc/XrayR sẽ được giữ lại. [y/N]: '
    local answer
    read -r answer
    [[ "$answer" == y || "$answer" == Y ]] || { printf 'Đã hủy.\n'; return 0; }
    systemctl stop XrayR || true
    systemctl disable XrayR || true
    rm -f -- "$SERVICE_FILE"
    systemctl daemon-reload
    # Chỉ xóa binary và dữ liệu cài đặt; không xóa cấu hình/chứng chỉ của người dùng.
    rm -f -- "$BINARY"
    printf 'Đã gỡ XrayR. Cấu hình vẫn ở /etc/XrayR.\n'
}

show_version() { require_install && "$BINARY" version; }
show_status() {
    require_install || return 1
    systemctl status XrayR --no-pager -l
}
show_log() { require_install && journalctl -u XrayR.service -e --no-pager -f; }

update_shell() {
    require_root || return 1
    local temp_file
    temp_file=$(mktemp) || return 1
    if curl -fsSL "${BASE_URL}/XrayR.sh" -o "$temp_file"; then
        install -m 755 "$temp_file" /usr/bin/XrayR
        printf 'Đã cập nhật trình quản lý.\n'
    else
        error "Không tải được trình quản lý."
    fi
    local result=$?
    rm -f -- "$temp_file"
    return "$result"
}

show_help() {
    cat <<'EOF'
Trình quản lý XrayR (dành cho bản cài systemd, không dùng cho Docker)
  XrayR                 Mở menu
  XrayR install         Cài bản ổn định mới nhất
  XrayR update [vX.Y.Z] Nâng cấp (giữ cấu hình, tự quay lui nếu khởi động lỗi)
  XrayR config          Sửa cấu hình
  XrayR start|stop|restart|status
  XrayR enable|disable  Bật/tắt khởi động cùng hệ thống
  XrayR log             Xem nhật ký
  XrayR version         Xem phiên bản
  XrayR uninstall       Gỡ binary, giữ cấu hình
  XrayR update_shell    Cập nhật trình quản lý
EOF
}

run_command() {
    case "${1:-}" in
        install) install_xrayr "${2:-}" ;;
        update) update_xrayr "${2:-}" ;;
        config) edit_config ;;
        uninstall) uninstall_xrayr ;;
        start|stop|restart|enable|disable)
            require_root && require_install && systemctl "$1" XrayR ;;
        status) show_status ;;
        log) show_log ;;
        version) show_version ;;
        update_shell) update_shell ;;
        help|-h|--help) show_help ;;
        *) error "Lệnh không hợp lệ: $1"; show_help; return 1 ;;
    esac
}

show_menu() {
    local choice
    while true; do
        printf '\nTrình quản lý XrayR — https://github.com/fsh2502/XrayR\n'
        if installed; then
            printf 'Trạng thái: %s\n' "$(systemctl is-active XrayR 2>/dev/null || true)"
        else
            printf 'Trạng thái: chưa cài đặt\n'
        fi
        cat <<'EOF'
  1) Cài đặt             2) Nâng cấp             3) Sửa cấu hình
  4) Khởi động           5) Dừng                 6) Khởi động lại
  7) Trạng thái          8) Nhật ký              9) Phiên bản
 10) Tự khởi động       11) Tắt tự khởi động    12) Gỡ cài đặt
 13) Cập nhật menu       0) Thoát
EOF
        read -r -p 'Chọn: ' choice || return 0
        case "$choice" in
            0) return 0 ;;
            1) run_command install ;;
            2) read -r -p 'Phiên bản (để trống = bản ổn định mới nhất): ' version
               run_command update "$version" ;;
            3) run_command config ;;
            4) run_command start ;;
            5) run_command stop ;;
            6) run_command restart ;;
            7) run_command status ;;
            8) run_command log ;;
            9) run_command version ;;
            10) run_command enable ;;
            11) run_command disable ;;
            12) run_command uninstall ;;
            13) run_command update_shell ;;
            *) printf 'Lựa chọn không hợp lệ.\n' ;;
        esac
    done
}

if [[ $# -eq 0 ]]; then
    show_menu
else
    run_command "$@"
fi
