#!/usr/bin/env bash

set -Eeuo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

INSTALL_REF="${XRAYR_INSTALL_REF:-master}"
INSTALL_URL="${XRAYR_INSTALL_URL:-https://raw.githubusercontent.com/fsh2502/XrayR-release/${INSTALL_REF}/install.sh}"
CONFIG_FILE="${XRAYR_CONFIG_FILE:-/etc/XrayR/config.yml}"
CERT_DIR="${XRAYR_CERT_DIR:-/etc/XrayR/cert}"
SKIP_INSTALL="${XRAYR_SKIP_INSTALL:-0}"
SKIP_SERVICE="${XRAYR_SKIP_SERVICE:-0}"
work_dir=""

cleanup() {
    if [[ -n "${work_dir}" && -d "${work_dir}" ]]; then
        rm -rf -- "${work_dir}"
    fi
}
trap cleanup EXIT

die() {
    echo -e "${red}Lỗi: $*${plain}" >&2
    exit 1
}

info() {
    echo -e "${green}$*${plain}"
}

warn() {
    echo -e "${yellow}$*${plain}"
}

yaml_quote() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    printf '"%s"' "${value}"
}

valid_domain() {
    local domain="$1" label
    local labels=()

    [[ ${#domain} -le 253 && "${domain}" == *.* ]] || return 1
    IFS='.' read -r -a labels <<< "${domain}"
    for label in "${labels[@]}"; do
        [[ "${label}" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || return 1
    done
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "Hãy chạy script bằng tài khoản root."
    fi
}

install_packages() {
    local packages=(curl openssl)

    if command -v curl >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "${packages[@]}"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "${packages[@]}"
    else
        die "Không tìm thấy apt-get, dnf hoặc yum để cài curl/openssl."
    fi
}

prompt_domain() {
    while true; do
        read -r -p "Domain của node (ví dụ node.example.com): " DOMAIN
        DOMAIN=${DOMAIN,,}
        if valid_domain "${DOMAIN}"; then
            return
        fi
        warn "Domain không hợp lệ. Chỉ dùng chữ thường, số, dấu chấm và dấu gạch ngang."
    done
}

prompt_panel_type() {
    echo ""
    echo "Chọn loại panel:"
    echo "  1) SSpanel"
    echo "  2) NewV2board (mặc định)"
    echo "  3) PMpanel"
    echo "  4) Proxypanel"
    echo "  5) V2RaySocks"
    echo "  6) GoV2Panel"
    echo "  7) BunPanel"

    while true; do
        read -r -p "Lựa chọn [2]: " PANEL_CHOICE
        PANEL_CHOICE=${PANEL_CHOICE:-2}
        case "${PANEL_CHOICE}" in
            1) PANEL_TYPE="SSpanel"; return ;;
            2) PANEL_TYPE="NewV2board"; return ;;
            3) PANEL_TYPE="PMpanel"; return ;;
            4) PANEL_TYPE="Proxypanel"; return ;;
            5) PANEL_TYPE="V2RaySocks"; return ;;
            6) PANEL_TYPE="GoV2Panel"; return ;;
            7) PANEL_TYPE="BunPanel"; return ;;
            *) warn "Lựa chọn không hợp lệ." ;;
        esac
    done
}

prompt_api() {
    while true; do
        read -r -p "API URL của panel (http:// hoặc https://): " API_HOST
        API_HOST=${API_HOST%/}
        if [[ "${API_HOST}" =~ ^https?://[^[:space:]]+$ ]]; then
            break
        fi
        warn "API URL phải bắt đầu bằng http:// hoặc https://."
    done

    while [[ -z "${API_KEY:-}" ]]; do
        read -r -s -p "API key: " API_KEY
        echo ""
        [[ -n "${API_KEY}" ]] || warn "API key không được để trống."
    done

    while true; do
        read -r -p "Node ID: " NODE_ID
        if [[ "${NODE_ID}" =~ ^[1-9][0-9]*$ ]]; then
            break
        fi
        warn "Node ID phải là số nguyên lớn hơn 0."
    done
}

prompt_node_type() {
    echo ""
    echo "Chọn loại node:"
    echo "  1) V2ray"
    echo "  2) Vmess"
    echo "  3) Vless"
    echo "  4) Trojan + TLS (tự tạo chứng chỉ tự ký)"
    echo "  5) Trojan (không tạo chứng chỉ cục bộ)"
    echo "  6) Shadowsocks"
    echo "  7) Shadowsocks-Plugin"

    SELF_SIGNED_TLS=false
    ENABLE_VLESS=false
    while true; do
        read -r -p "Lựa chọn [4]: " NODE_CHOICE
        NODE_CHOICE=${NODE_CHOICE:-4}
        case "${NODE_CHOICE}" in
            1) NODE_TYPE="V2ray"; return ;;
            2) NODE_TYPE="Vmess"; return ;;
            3) NODE_TYPE="Vless"; ENABLE_VLESS=true; return ;;
            4) NODE_TYPE="Trojan"; SELF_SIGNED_TLS=true; return ;;
            5) NODE_TYPE="Trojan"; return ;;
            6) NODE_TYPE="Shadowsocks"; return ;;
            7) NODE_TYPE="Shadowsocks-Plugin"; return ;;
            *) warn "Lựa chọn không hợp lệ." ;;
        esac
    done
}

show_summary() {
    echo ""
    echo "Thông tin sẽ cấu hình:"
    echo "  Tên miền:         ${DOMAIN}"
    echo "  Loại panel:       ${PANEL_TYPE}"
    echo "  Địa chỉ API:      ${API_HOST}"
    echo "  Khóa API:         ******"
    echo "  ID node:          ${NODE_ID}"
    echo "  Loại node:        ${NODE_TYPE}"
    echo "  Chứng chỉ TLS:    $([[ "${SELF_SIGNED_TLS}" == true ]] && echo 'tự ký' || echo 'không dùng')"
    echo ""

    read -r -p "Tiếp tục cài đặt? [Y/n]: " CONFIRM
    case "${CONFIRM:-y}" in
        y|Y|yes|YES) ;;
        *) die "Đã hủy theo yêu cầu." ;;
    esac
}

install_xrayr() {
    if [[ "${SKIP_INSTALL}" == "1" ]]; then
        warn "Bỏ qua cài binary vì XRAYR_SKIP_INSTALL=1."
        return
    fi

    install_packages
    work_dir=$(mktemp -d)
    curl -fsSL "${INSTALL_URL}" -o "${work_dir}/install.sh"
    chmod +x "${work_dir}/install.sh"
    (
        cd "${work_dir}"
        bash ./install.sh "${XRAYR_VERSION:-}"
    )
}

create_self_signed_certificate() {
    local openssl_config
    local cert_file="${CERT_DIR}/${DOMAIN}.cert"
    local key_file="${CERT_DIR}/${DOMAIN}.key"

    if [[ "${SELF_SIGNED_TLS}" != true ]]; then
        CERT_MODE="none"
        CERT_FILE=""
        KEY_FILE=""
        return
    fi

    command -v openssl >/dev/null 2>&1 || install_packages
    mkdir -p "${CERT_DIR}"
    chmod 700 "${CERT_DIR}" 2>/dev/null || true
    openssl_config=$(mktemp)
    cat > "${openssl_config}" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3_req
prompt = no

[dn]
CN = ${DOMAIN}

[v3_req]
subjectAltName = DNS:${DOMAIN}
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF

    umask 077
    if ! openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 3650 \
        -keyout "${key_file}" \
        -out "${cert_file}" \
        -config "${openssl_config}" >/dev/null 2>&1; then
        rm -f -- "${openssl_config}"
        die "Không thể tạo chứng chỉ tự ký cho ${DOMAIN}."
    fi
    rm -f -- "${openssl_config}"
    chmod 600 "${key_file}"
    chmod 644 "${cert_file}"

    openssl x509 -in "${cert_file}" -noout -checkend 0 >/dev/null \
        || die "Chứng chỉ vừa tạo không hợp lệ."

    CERT_MODE="file"
    CERT_FILE="${cert_file}"
    KEY_FILE="${key_file}"
}

write_config() {
    local config_dir backup_file temp_config
    local q_panel q_api q_key q_type q_domain q_cert q_key_file

    config_dir=$(dirname "${CONFIG_FILE}")
    mkdir -p "${config_dir}"
    chmod 755 "${config_dir}" 2>/dev/null || true

    if [[ -f "${CONFIG_FILE}" ]]; then
        backup_file="${CONFIG_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
        cp -a "${CONFIG_FILE}" "${backup_file}"
        info "Đã sao lưu cấu hình cũ: ${backup_file}"
    fi

    q_panel=$(yaml_quote "${PANEL_TYPE}")
    q_api=$(yaml_quote "${API_HOST}")
    q_key=$(yaml_quote "${API_KEY}")
    q_type=$(yaml_quote "${NODE_TYPE}")
    q_domain=$(yaml_quote "${DOMAIN}")
    q_cert=$(yaml_quote "${CERT_FILE}")
    q_key_file=$(yaml_quote "${KEY_FILE}")
    temp_config="${CONFIG_FILE}.tmp.$$"

    cat > "${temp_config}" <<EOF
Log:
  Level: warning
  AccessPath:
  ErrorPath:
DnsConfigPath:
RouteConfigPath:
InboundConfigPath:
OutboundConfigPath:
ConnectionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
  - PanelType: ${q_panel}
    ApiConfig:
      ApiHost: ${q_api}
      ApiKey: ${q_key}
      NodeID: ${NODE_ID}
      NodeType: ${q_type}
      Timeout: 30
      EnableVless: ${ENABLE_VLESS}
      VlessFlow: "xtls-rprx-vision"
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath:
      DisableCustomConfig: false
    ControllerConfig:
      ListenIP: "0.0.0.0"
      SendIP: "0.0.0.0"
      UpdatePeriodic: 60
      EnableDNS: false
      DNSType: "AsIs"
      DisableUploadTraffic: false
      DisableGetRule: false
      DisableIVCheck: false
      DisableSniffing: false
      EnableProxyProtocol: false
      EnableFallback: false
      DisableLocalREALITYConfig: false
      EnableREALITY: false
      CertConfig:
        CertMode: "${CERT_MODE}"
        CertDomain: ${q_domain}
        CertFile: ${q_cert}
        KeyFile: ${q_key_file}
        RejectUnknownSni: false
EOF

    chmod 600 "${temp_config}"
    mv -f "${temp_config}" "${CONFIG_FILE}"
    info "Đã lưu cấu hình: ${CONFIG_FILE}"
}

start_service() {
    if [[ "${SKIP_SERVICE}" == "1" ]]; then
        warn "Bỏ qua systemd vì XRAYR_SKIP_SERVICE=1."
        return
    fi

    systemctl daemon-reload
    systemctl enable XrayR >/dev/null 2>&1 || true
    if systemctl restart XrayR; then
        sleep 2
    fi

    if systemctl is-active --quiet XrayR; then
        info "XrayR đang chạy."
    else
        warn "XrayR chưa chạy thành công. 20 dòng log gần nhất:"
        journalctl -u XrayR --no-pager -n 20 || true
        return 1
    fi
}

main() {
    if [[ "${SKIP_INSTALL}" != "1" || "${SKIP_SERVICE}" != "1" ]]; then
        require_root
    fi

    echo "============================================"
    echo "       Cài nhanh và cấu hình XrayR"
    echo "============================================"

    prompt_domain
    prompt_panel_type
    prompt_api
    prompt_node_type
    show_summary
    install_xrayr
    create_self_signed_certificate
    write_config

    if [[ "${SELF_SIGNED_TLS}" == true ]]; then
        warn "Trojan TLS dùng chứng chỉ tự ký. Client phải tin cậy chứng chỉ này hoặc bật allowInsecure."
        warn "Node trên panel cũng phải bật TLS và dùng domain ${DOMAIN}."
    fi

    start_service
    echo ""
    info "Hoàn tất. Quản lý bằng lệnh: XrayR"
}

main "$@"
