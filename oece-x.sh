#!/usr/bin/env bash
#=======================================================================
#  oece-x.sh — VPS 體檢與一鍵部署測試工具
#
#  幫你在 3 分鐘內判斷一台 VPS 到底能不能用、值不值。
#  系統體檢 · 網路測速 · 回程路由 · 環境安裝 · 部署 Demo · Sub2API
#
#  Project : https://github.com/web3-ai-game/oece-x-sh
#  Channel : YouTube @oece-x · https://oece-x.com
#  License : MIT
#
#  本工具不含任何繞過網路封鎖之功能，僅供 VPS 測試與學習用途。
#=======================================================================

SCRIPT_VERSION="1.1.0"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/web3-ai-game/oece-x-sh/main/oece-x.sh"

set -Eeuo pipefail

#-----------------------------------------------------------------------
# 全局常量
#-----------------------------------------------------------------------
OECE_HOME="${HOME}/.oece-x"
OECE_BIN="${OECE_HOME}/bin"
OECE_DEMO_DIR="${OECE_HOME}/demo"
DEMO_CONTAINER="oece-x-demo"
DEMO_PORT_DEFAULT="8888"

# Sub2API（官方 Docker Compose 一鍵部署封裝）
# 上游: https://github.com/Wei-Shaw/sub2api
# 安裝目錄刻意不用 /opt/sub2api，避免與本機已有 api.oece-x.com 實例衝突
SUB2API_DIR_DEFAULT="/opt/oece-sub2api"
SUB2API_PROJECT="oece-sub2api"
SUB2API_PORT_DEFAULT="8080"
SUB2API_GH_RAW="https://raw.githubusercontent.com/Wei-Shaw/sub2api/main/deploy"
SUB2API_COMPOSE_URL="${SUB2API_GH_RAW}/docker-compose.local.yml"
SUB2API_ENV_EXAMPLE_URL="${SUB2API_GH_RAW}/.env.example"
SUB2API_CRED_FILE="${OECE_HOME}/sub2api-credentials.txt"
SUB2API_DUCKDNS_FILE="${OECE_HOME}/duckdns.env"

# NextTrace（開源回程路由工具）— 釘死版本 + 內嵌 SHA256 校驗
# 來源: https://github.com/nxtrace/NTrace-core/releases
NEXTTRACE_VERSION="v1.7.1"
NEXTTRACE_BASE_URL="https://github.com/nxtrace/NTrace-core/releases/download/${NEXTTRACE_VERSION}"
NEXTTRACE_SHA256_AMD64="1f4c559cbdf6f667a1a9e050567c9cf1fc11741e8cc1e50f5fdcaf2dbb247232"
NEXTTRACE_SHA256_ARM64="9c2f1b79e7d0e37f59ebe685aec1d5c41fb8f3407f54e17b34656712eaa66fd9"

# Ookla Speedtest CLI（可選深度測速，官方發佈）
OOKLA_VERSION="1.2.0"
OOKLA_BASE_URL="https://install.speedtest.net/app/cli"

# 三網回程公開測試節點（僅作路由探測目標，非本項目資產）
# 格式: 名稱|IP
ROUTE_NODES_FULL=(
    "北京電信|219.141.136.12"
    "北京聯通|202.106.50.1"
    "北京移動|221.179.155.161"
    "上海電信|202.96.209.133"
    "上海聯通|210.22.97.1"
    "上海移動|211.136.112.200"
    "廣州電信|58.60.188.222"
    "廣州聯通|210.21.196.6"
    "廣州移動|120.196.165.24"
)
ROUTE_NODES_QUICK=(
    "上海電信|202.96.209.133"
    "上海聯通|210.22.97.1"
    "上海移動|211.136.112.200"
)

# Cloudflare 測速端點（公開）
CF_SPEED_HOST="https://speed.cloudflare.com"

# curl 通用參數：HTTPS 校驗、超時、重試
CURL_OPTS=(--fail --silent --show-error --location --retry 3 --retry-delay 1 --connect-timeout 10)

# 運行時狀態
TMP_DIR="$(mktemp -d /tmp/oece-x.XXXXXX)"
OS_ID=""
OS_PRETTY=""
ARCH=""
PKG_MGR=""
APT_UPDATED=0

#-----------------------------------------------------------------------
# 顏色與輸出
#-----------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_MAGENTA=$'\033[0;35m'
    C_CYAN=$'\033[0;36m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN=""
fi

info()  { printf '%s[資訊]%s %s\n' "$C_CYAN"   "$C_RESET" "$*"; }
ok()    { printf '%s[完成]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s[注意]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()   { printf '%s[錯誤]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }

divider() { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────" "$C_RESET"; }

section() {
    printf '\n%s%s◆ %s%s\n' "$C_BOLD" "$C_MAGENTA" "$*" "$C_RESET"
    divider
}

# 計算字串顯示寬度（中文字 3 bytes 顯示 2 格，ASCII 1 byte 1 格）
display_width() {
    local s="$1" total ascii nonascii
    total=$(printf '%s' "$s" | wc -c)
    ascii=$(printf '%s' "$s" | tr -cd '\1-\177' | wc -c)
    nonascii=$(( total - ascii ))
    printf '%d' $(( ascii + nonascii * 2 / 3 ))
}

# 對齊輸出 key-value（key 統一補齊到 14 格顯示寬度）
kv() {
    local key="$1" val="$2" w pad
    w=$(display_width "$key")
    pad=$(( 14 - w ))
    [ "$pad" -lt 1 ] && pad=1
    printf ' %s%s%s%*s%s\n' "$C_CYAN" "$key" "$C_RESET" "$pad" "" "$val"
}

#-----------------------------------------------------------------------
# 確認與交互
#-----------------------------------------------------------------------
confirm() {
    local prompt="$1" reply
    printf '%s%s%s [y/N]: ' "$C_YELLOW" "$prompt" "$C_RESET"
    read -r reply || reply=""
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *)           return 1 ;;
    esac
}

# 危險操作二次確認：必須完整輸入 yes
confirm_danger() {
    local prompt="$1" reply
    printf '%s⚠ %s%s\n' "$C_RED" "$prompt" "$C_RESET"
    printf '%s  確認請完整輸入 yes（其他任何輸入取消）:%s ' "$C_RED" "$C_RESET"
    read -r reply || reply=""
    [ "$reply" = "yes" ]
}

pause() {
    printf '\n%s按 Enter 返回主選單...%s' "$C_DIM" "$C_RESET"
    read -r _ || true
}

disclaimer() {
    printf '\n%s⚠ 本工具僅供測試，結果僅供參考%s\n' "$C_DIM" "$C_RESET"
}

#-----------------------------------------------------------------------
# 錯誤處理與清理
#-----------------------------------------------------------------------
on_error() {
    local line="$1" code="$2"
    err "內部錯誤：第 ${line} 行命令失敗（exit=${code}）"
    err "歡迎回報 issue: https://github.com/web3-ai-game/oece-x-sh/issues"
}
trap 'on_error $LINENO $?' ERR

on_exit() {
    rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap on_exit EXIT

on_interrupt() {
    printf '\n'
    warn "已中斷，再見。"
    exit 130
}
trap on_interrupt INT

#-----------------------------------------------------------------------
# 環境檢測
#-----------------------------------------------------------------------
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "本腳本需要 root 權限（安裝依賴 / Docker / 路由探測需要）。"
        err "請改用：sudo bash oece-x.sh"
        exit 1
    fi
}

detect_os() {
    if [ "$(uname -s)" != "Linux" ]; then
        err "本腳本僅支援 Linux（Debian / Ubuntu / CentOS 系）。"
        exit 1
    fi
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_PRETTY="${PRETTY_NAME:-unknown}"
    else
        OS_ID="unknown" OS_PRETTY="unknown"
    fi

    case "$OS_ID" in
        debian|ubuntu)                       PKG_MGR="apt" ;;
        centos|rhel|rocky|almalinux|fedora)  PKG_MGR="dnf"
                                             command -v dnf >/dev/null 2>&1 || PKG_MGR="yum" ;;
        *)
            warn "未識別的發行版：${OS_PRETTY}（官方支援 Debian/Ubuntu/CentOS 系）"
            if command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
            elif command -v dnf >/dev/null 2>&1;   then PKG_MGR="dnf"
            elif command -v yum >/dev/null 2>&1;   then PKG_MGR="yum"
            else
                err "找不到可用的包管理器（apt/dnf/yum），無法繼續。"
                exit 1
            fi
            ;;
    esac
}

detect_arch() {
    local m
    m="$(uname -m)"
    case "$m" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)
            err "暫不支援的架構：${m}（目前支援 amd64 / arm64）"
            exit 1
            ;;
    esac
}

# 統一包安裝入口
pkg_install() {
    case "$PKG_MGR" in
        apt)
            if [ "$APT_UPDATED" -eq 0 ]; then
                info "更新 apt 索引..."
                apt-get update -qq || warn "apt 索引更新失敗，嘗試繼續安裝"
                APT_UPDATED=1
            fi
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
            ;;
        dnf) dnf install -y -q "$@" ;;
        yum) yum install -y -q "$@" ;;
    esac
}

# 啟動時基礎依賴檢查（curl / tar 是全腳本前提）
ensure_deps() {
    local missing=()
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v tar  >/dev/null 2>&1 || missing+=("tar")
    if [ "${#missing[@]}" -gt 0 ]; then
        warn "缺少基礎依賴：${missing[*]}"
        if confirm "是否自動安裝？"; then
            pkg_install "${missing[@]}" ca-certificates
            ok "依賴安裝完成"
        else
            err "缺少必要依賴，無法繼續。"
            exit 1
        fi
    fi
}

#-----------------------------------------------------------------------
# 安全下載：HTTPS-only、顯示來源、重試、清楚報錯
#-----------------------------------------------------------------------
safe_download() {
    local url="$1" dest="$2"
    case "$url" in
        https://*) : ;;
        *)
            err "拒絕非 HTTPS 下載來源：${url}"
            return 1
            ;;
    esac
    info "下載來源: ${url}"
    if ! curl "${CURL_OPTS[@]}" --progress-bar -o "$dest" "$url"; then
        err "下載失敗：${url}"
        err "請檢查網路連通性，或稍後重試。"
        return 1
    fi
    return 0
}

# SHA256 校驗，不過即刪檔
verify_sha256() {
    local file="$1" expected="$2" actual
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [ "$actual" != "$expected" ]; then
        err "SHA256 校驗失敗！"
        err "  預期: ${expected}"
        err "  實際: ${actual}"
        err "檔案已刪除。可能是下載損壞或來源被篡改，請勿使用。"
        rm -f "$file"
        return 1
    fi
    ok "SHA256 校驗通過"
    return 0
}

#-----------------------------------------------------------------------
# 公網 IP（多來源降級）
#-----------------------------------------------------------------------
get_public_ip() {
    local family="$1" ip=""   # family: 4 或 6
    ip=$(curl -"$family" -fsS --max-time 8 "https://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null \
        | awk -F= '/^ip=/{print $2}') || ip=""
    if [ -z "$ip" ]; then
        ip=$(curl -"$family" -fsS --max-time 8 "https://api.ip.sb/ip" -A "Mozilla/5.0 oece-x.sh" 2>/dev/null) || ip=""
    fi
    if [ -z "$ip" ]; then
        ip=$(curl -"$family" -fsS --max-time 8 "https://ifconfig.me" 2>/dev/null) || ip=""
    fi
    printf '%s' "$ip"
}

#=======================================================================
# 模塊 1 · 系統體檢
#=======================================================================
module_sysinfo() {
    section "系統體檢"

    local cpu_model cpu_cores cpu_freq
    cpu_model=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null) || cpu_model=""
    [ -z "$cpu_model" ] && cpu_model=$(lscpu 2>/dev/null | awk -F': +' '/Model name/{print $2; exit}') || true
    [ -z "$cpu_model" ] && cpu_model="未知"
    cpu_cores=$(nproc 2>/dev/null) || cpu_cores="?"
    cpu_freq=$(awk -F': ' '/cpu MHz/{printf "%.0f MHz", $2; exit}' /proc/cpuinfo 2>/dev/null) || cpu_freq=""
    [ -z "$cpu_freq" ] && cpu_freq="未知"

    # 直接讀 /proc/meminfo，不依賴 procps（極簡系統可能沒有 free 命令）
    local mem_total mem_avail mem_used swap_total
    mem_total=$(awk '/^MemTotal:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null) || mem_total="?"
    mem_avail=$(awk '/^MemAvailable:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null) || mem_avail=""
    if [ -n "$mem_avail" ] && [ "$mem_total" != "?" ]; then
        mem_used=$(( mem_total - mem_avail ))
    else
        mem_used="?"
    fi
    swap_total=$(awk '/^SwapTotal:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null) || swap_total="?"

    local disk_line disk_total disk_used disk_pct
    disk_line=$(df -h / | awk 'NR==2{print $2" "$3" "$5}')
    disk_total=$(printf '%s' "$disk_line" | awk '{print $1}')
    disk_used=$(printf '%s' "$disk_line" | awk '{print $2}')
    disk_pct=$(printf '%s' "$disk_line" | awk '{print $3}')

    local virt
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt=$(systemd-detect-virt 2>/dev/null) || virt="none"
    elif [ -f /.dockerenv ]; then
        virt="container (docker)"
    elif [ -f /run/.containerenv ]; then
        virt="container (podman)"
    elif grep -qi hypervisor /proc/cpuinfo 2>/dev/null; then
        virt="虛擬機（具體類型未知）"
    else
        virt="none / 未檢出"
    fi
    [ "$virt" = "none" ] && virt="無（獨立伺服器或未檢出）"

    local kernel uptime_str cc qdisc
    kernel=$(uname -r)
    uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //') || uptime_str=""
    [ -z "$uptime_str" ] && uptime_str=$(awk '{printf "%.1f 小時", $1/3600}' /proc/uptime)
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null) || cc="未知"
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null) || qdisc="未知"
    local bbr_tag=""
    [ "$cc" = "bbr" ] && bbr_tag=" ${C_GREEN}✓ BBR 已啟用${C_RESET}"

    info "正在獲取公網 IP 與 ASN 資訊..."
    local ipv4 ipv6 geo_info asn_org geo_loc
    ipv4=$(get_public_ip 4)
    ipv6=$(get_public_ip 6)
    [ -z "$ipv4" ] && ipv4="未檢出"
    [ -z "$ipv6" ] && ipv6="未檢出"

    asn_org="" geo_loc=""
    geo_info=$(curl -fsS --max-time 8 "https://ipinfo.io" 2>/dev/null) || geo_info=""
    if [ -n "$geo_info" ]; then
        asn_org=$(printf '%s' "$geo_info" | sed -n 's/.*"org": *"\([^"]*\)".*/\1/p' | head -1)
        geo_loc=$(printf '%s' "$geo_info" | sed -n 's/.*"country": *"\([^"]*\)".*/\1/p' | head -1)
        local city
        city=$(printf '%s' "$geo_info" | sed -n 's/.*"city": *"\([^"]*\)".*/\1/p' | head -1)
        [ -n "$city" ] && geo_loc="${geo_loc} · ${city}"
    fi
    [ -z "$asn_org" ] && asn_org="未知"
    [ -z "$geo_loc" ] && geo_loc="未知"

    printf '\n'
    kv "系統"      "$OS_PRETTY"
    kv "內核"      "$kernel"
    kv "架構"      "$ARCH ($(uname -m))"
    kv "虛擬化"    "$virt"
    kv "運行時長"  "$uptime_str"
    divider
    kv "CPU 型號"  "$cpu_model"
    kv "CPU 核數"  "${cpu_cores} 核 @ ${cpu_freq}"
    kv "記憶體"    "${mem_used} MB / ${mem_total} MB"
    kv "Swap"      "${swap_total} MB"
    kv "磁碟 (/)"  "${disk_used} / ${disk_total}（已用 ${disk_pct}）"
    divider
    kv "TCP 擁塞"  "${cc}${bbr_tag}"
    kv "隊列算法"  "$qdisc"
    kv "IPv4"      "$ipv4"
    kv "IPv6"      "$ipv6"
    kv "ASN / ISP" "$asn_org"
    kv "地理位置"  "$geo_loc"

    disclaimer
}

#=======================================================================
# 模塊 2 · 網路測速
#=======================================================================

# Cloudflare 延遲：取 5 次 TCP 建連時間，算平均與抖動
cf_latency() {
    local samples="" t
    for _ in 1 2 3 4 5; do
        t=$(curl -fsS -o /dev/null --max-time 10 -w '%{time_connect}' "${CF_SPEED_HOST}/cdn-cgi/trace" 2>/dev/null) || t=""
        [ -n "$t" ] && samples="${samples}${t} "
    done
    if [ -z "$samples" ]; then
        printf 'fail'
        return 0
    fi
    # 輸出: 平均ms 抖動ms
    printf '%s' "$samples" | awk '{
        n = NF; sum = 0
        for (i = 1; i <= n; i++) sum += $i
        avg = sum / n
        dev = 0
        for (i = 1; i <= n; i++) { d = $i - avg; if (d < 0) d = -d; dev += d }
        printf "%.1f %.1f", avg * 1000, dev / n * 1000
    }'
}

# Cloudflare 下載測速：bytes 檔位，回傳 Mbps
# 注意：curl 超時（exit 28）不算失敗——%{speed_download} 是至今平均速度，
# 慢速網路拉不完 100MB 時，部分下載的平均值仍是有效測量。
cf_download() {
    local bytes="$1" maxtime="${2:-60}" speed
    speed=$(curl -fsS -o /dev/null --max-time "$maxtime" -w '%{speed_download}' \
        "${CF_SPEED_HOST}/__down?bytes=${bytes}" 2>/dev/null) || true
    [ -z "$speed" ] && speed="0"
    awk -v b="$speed" 'BEGIN{printf "%.2f", b * 8 / 1000000}'
}

# Cloudflare 上傳測速：POST 20MB，回傳 Mbps（超時同樣取部分平均值）
cf_upload() {
    local payload="${TMP_DIR}/upload.bin" speed
    head -c 20971520 /dev/zero > "$payload"
    speed=$(curl -fsS -o /dev/null --max-time 60 -w '%{speed_upload}' \
        -H 'Content-Type: application/octet-stream' \
        --data-binary "@${payload}" \
        "${CF_SPEED_HOST}/__up" 2>/dev/null) || true
    rm -f "$payload"
    [ -z "$speed" ] && speed="0"
    awk -v b="$speed" 'BEGIN{printf "%.2f", b * 8 / 1000000}'
}

install_ookla() {
    local url tgz
    url="${OOKLA_BASE_URL}/ookla-speedtest-${OOKLA_VERSION}-linux-$(uname -m).tgz"
    tgz="${TMP_DIR}/speedtest.tgz"

    info "Ookla Speedtest CLI ${OOKLA_VERSION}（官方發佈，約 1.1 MB）"
    warn "Ookla 為商業軟體，使用即代表你接受其 EULA 與 GDPR 條款。"
    confirm "確認下載並安裝？" || { info "已取消"; return 1; }

    safe_download "$url" "$tgz" || return 1
    mkdir -p "$OECE_BIN"
    tar -xzf "$tgz" -C "$TMP_DIR" speedtest
    mv "$TMP_DIR/speedtest" "$OECE_BIN/speedtest"
    chmod +x "$OECE_BIN/speedtest"
    ok "已安裝到 ${OECE_BIN}/speedtest"
    return 0
}

run_ookla() {
    local st="${OECE_BIN}/speedtest"
    if [ ! -x "$st" ]; then
        install_ookla || return 0
    fi
    info "開始 Ookla 深度測速（自動選擇最近節點，約 30 秒）..."
    "$st" --accept-license --accept-gdpr || warn "Ookla 測速未正常完成"
}

module_speedtest() {
    section "網路測速"
    printf ' 1) Cloudflare 標準測速%s（純 curl · 推薦）%s\n' "$C_DIM" "$C_RESET"
    printf ' 2) Ookla Speedtest 深度測速%s（需下載官方 CLI）%s\n' "$C_DIM" "$C_RESET"
    printf ' 0) 返回\n\n'
    printf '請選擇 [1]: '
    local choice
    read -r choice || choice="0"
    [ -z "$choice" ] && choice="1"

    case "$choice" in
        1)
            printf '\n'
            info "測試延遲（Cloudflare 邊緣節點 × 5 次）..."
            local lat jitter lat_out
            lat_out=$(cf_latency)
            if [ "$lat_out" = "fail" ]; then
                err "無法連通 speed.cloudflare.com，測速中止。"
                disclaimer
                return 0
            fi
            lat=$(printf '%s' "$lat_out" | awk '{print $1}')
            jitter=$(printf '%s' "$lat_out" | awk '{print $2}')

            # Cloudflare __down 端點對過大 bytes 回 403（實測 100MB 被拒），
            # 用 50MB × 2 取最大值，緩解 TCP 慢啟動導致的低估
            info "測試下載（10 MB 熱身 + 50 MB × 2 正式）..."
            cf_download 10485760 15 >/dev/null
            local down down2
            down=$(cf_download 52428800)
            down2=$(cf_download 52428800)
            down=$(awk -v a="$down" -v b="$down2" 'BEGIN{printf "%.2f", (a > b ? a : b)}')

            info "測試上傳（20 MB）..."
            local up
            up=$(cf_upload)

            [ "$down" = "0.00" ] && down="${C_RED}測試失敗${C_RESET}" || down="${C_GREEN}${down} Mbps${C_RESET}"
            [ "$up"   = "0.00" ] && up="${C_RED}測試失敗${C_RESET}"   || up="${C_GREEN}${up} Mbps${C_RESET}"

            printf '\n'
            kv "延遲"   "${lat} ms（到 Cloudflare 最近邊緣）"
            kv "抖動"   "${jitter} ms"
            kv "下載"   "$down"
            kv "上傳"   "$up"
            printf '\n'
            info "說明：Cloudflare 邊緣就近接入，此結果反映 VPS 的國際出口帶寬上限；"
            info "到特定地區的實際體驗請結合「回程路由檢測」判斷。"
            ;;
        2)
            printf '\n'
            run_ookla
            ;;
        *)
            return 0
            ;;
    esac
    disclaimer
}

#=======================================================================
# 模塊 3 · 回程路由檢測
#=======================================================================
ensure_nexttrace() {
    local nt="${OECE_BIN}/nexttrace"
    if [ -x "$nt" ]; then
        printf '%s' "$nt"
        return 0
    fi

    local url="" sha=""
    case "$ARCH" in
        amd64) url="${NEXTTRACE_BASE_URL}/nexttrace_linux_amd64"; sha="$NEXTTRACE_SHA256_AMD64" ;;
        arm64) url="${NEXTTRACE_BASE_URL}/nexttrace_linux_arm64"; sha="$NEXTTRACE_SHA256_ARM64" ;;
    esac

    {
        info "回程路由檢測首選開源工具 NextTrace ${NEXTTRACE_VERSION}（能標註 AS 路徑與線路類型）"
        info "下載後將做 SHA256 完整性校驗（哈希釘死在腳本內）"
    } >&2
    if ! confirm "下載 NextTrace（約 10 MB）？（拒絕則降級使用 traceroute）" >&2; then
        return 1
    fi

    local tmp_bin="${TMP_DIR}/nexttrace"
    safe_download "$url" "$tmp_bin" >&2 || return 1
    verify_sha256 "$tmp_bin" "$sha" >&2 || return 1

    mkdir -p "$OECE_BIN"
    mv "$tmp_bin" "$nt"
    chmod +x "$nt"
    ok "NextTrace 就緒: ${nt}" >&2
    printf '%s' "$nt"
    return 0
}

# 降級鏈：traceroute → mtr
fallback_trace() {
    local ip="$1"
    if command -v traceroute >/dev/null 2>&1; then
        traceroute -n -q 1 -w 2 -m 30 "$ip" || warn "traceroute 未正常完成"
        return 0
    fi
    if command -v mtr >/dev/null 2>&1; then
        mtr -rn -c 3 "$ip" || warn "mtr 未正常完成"
        return 0
    fi
    warn "系統缺少 traceroute / mtr"
    if confirm "安裝 traceroute？"; then
        pkg_install traceroute
        traceroute -n -q 1 -w 2 -m 30 "$ip" || warn "traceroute 未正常完成"
    else
        err "無可用路由探測工具，跳過 ${ip}"
    fi
}

run_route_trace() {
    local -a nodes=("$@")
    local nt=""
    nt=$(ensure_nexttrace) || nt=""

    if [ -z "$nt" ]; then
        warn "使用系統 traceroute 降級模式（僅顯示 IP 跳點，無線路標註）"
    fi

    local entry name ip
    for entry in "${nodes[@]}"; do
        name="${entry%%|*}"
        ip="${entry##*|}"
        printf '\n%s%s▶ %s（%s）%s\n' "$C_BOLD" "$C_BLUE" "$name" "$ip" "$C_RESET"
        divider
        if [ -n "$nt" ]; then
            "$nt" -q 1 "$ip" || warn "NextTrace 探測 ${name} 未正常完成"
        else
            fallback_trace "$ip"
        fi
    done

    printf '\n'
    info "線路速查：CN2 GIA(59.43.*且少跳) > CN2 GT(59.43.*) ≈ 聯通9929(AS9929) ≈ 移動CMIN2(AS58807)"
    info "         > 電信163(202.97.*) ≈ 聯通4837(AS4837) ≈ 移動CMI(AS58453)"
}

module_route() {
    section "回程路由檢測（三網公開節點）"
    printf ' 1) 快速模式%s（上海 電信/聯通/移動，3 節點）%s\n' "$C_DIM" "$C_RESET"
    printf ' 2) 完整模式%s（北上廣 × 三網，9 節點）%s\n' "$C_DIM" "$C_RESET"
    printf ' 0) 返回\n\n'
    printf '請選擇 [1]: '
    local choice
    read -r choice || choice="0"
    [ -z "$choice" ] && choice="1"

    case "$choice" in
        1) run_route_trace "${ROUTE_NODES_QUICK[@]}" ;;
        2) run_route_trace "${ROUTE_NODES_FULL[@]}" ;;
        *) return 0 ;;
    esac
    disclaimer
}

#=======================================================================
# 模塊 4 · 環境一鍵安裝
#=======================================================================
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        ok "Docker 已安裝：$(docker --version 2>/dev/null || echo '版本未知')"
        if docker compose version >/dev/null 2>&1; then
            ok "Docker Compose 已就緒：$(docker compose version --short 2>/dev/null || echo '?')"
        else
            warn "未檢出 docker compose 插件"
            if confirm "安裝 docker-compose-plugin？"; then
                pkg_install docker-compose-plugin && ok "Compose 插件安裝完成"
            fi
        fi
        return 0
    fi

    local script="${TMP_DIR}/get-docker.sh"
    info "將使用 Docker 官方安裝腳本 https://get.docker.com"
    safe_download "https://get.docker.com" "$script" || return 1
    local size
    size=$(wc -c < "$script")
    info "腳本已下載到臨時目錄（${size} bytes），可自行審查：${script}"
    confirm_danger "即將以 root 執行 Docker 官方安裝腳本，會添加軟體源並安裝軟體包。" || { info "已取消"; return 1; }

    sh "$script" || { err "Docker 安裝腳本執行失敗"; return 1; }

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now docker >/dev/null 2>&1 || warn "無法通過 systemctl 啟動 docker，請手動檢查"
    fi

    if docker version >/dev/null 2>&1; then
        ok "Docker 安裝並啟動成功：$(docker --version)"
    else
        warn "Docker 已安裝但守護進程未就緒，可稍後執行 systemctl start docker"
    fi
}

install_common_tools() {
    local tools=(git vim htop unzip wget tar)
    info "常用工具包：${tools[*]}"
    confirm "確認安裝？" || { info "已取消"; return 0; }
    pkg_install "${tools[@]}"
    ok "常用工具安裝完成"
}

module_env_install() {
    section "環境一鍵安裝"
    printf ' 1) Docker + Docker Compose%s（官方腳本 get.docker.com）%s\n' "$C_DIM" "$C_RESET"
    printf ' 2) 常用工具包%s（git / vim / htop / unzip / wget / tar）%s\n' "$C_DIM" "$C_RESET"
    printf ' 0) 返回\n\n'
    printf '請選擇: '
    local choice
    read -r choice || choice="0"

    case "$choice" in
        1) printf '\n'; install_docker ;;
        2) printf '\n'; install_common_tools ;;
        *) return 0 ;;
    esac
    disclaimer
}

#=======================================================================
# 模塊 5 · 部署 Demo
#=======================================================================
deploy_demo() {
    if ! command -v docker >/dev/null 2>&1 || ! docker version >/dev/null 2>&1; then
        warn "需要 Docker 運行環境，請先在「環境一鍵安裝」中安裝 Docker。"
        return 0
    fi

    if docker ps -a --format '{{.Names}}' | grep -qx "$DEMO_CONTAINER"; then
        warn "Demo 容器已存在。"
        if confirm "移除舊容器並重新部署？"; then
            docker rm -f "$DEMO_CONTAINER" >/dev/null
        else
            info "已取消"
            return 0
        fi
    fi

    local port
    printf '請輸入對外端口 [%s]: ' "$DEMO_PORT_DEFAULT"
    read -r port || port=""
    [ -z "$port" ] && port="$DEMO_PORT_DEFAULT"
    case "$port" in
        ''|*[!0-9]*)
            err "端口必須是數字"
            return 1
            ;;
    esac
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        err "端口範圍 1-65535"
        return 1
    fi
    if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$"; then
        err "端口 ${port} 已被佔用，請換一個。"
        return 1
    fi

    local ipv4 hostname_str now
    ipv4=$(get_public_ip 4)
    [ -z "$ipv4" ] && ipv4="<你的伺服器IP>"
    hostname_str=$(hostname 2>/dev/null || uname -n)
    now=$(date '+%Y-%m-%d %H:%M:%S %Z')

    mkdir -p "$OECE_DEMO_DIR"
    cat > "${OECE_DEMO_DIR}/index.html" <<EOF
<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>oece-x.sh · VPS Demo</title>
<style>
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
       background:#0d0d1a;color:#e8e8f0;font-family:system-ui,-apple-system,sans-serif}
  .card{text-align:center;padding:48px 40px;border:1px solid #2a2a44;border-radius:16px;
        background:#14142a;box-shadow:0 0 60px rgba(124,77,255,.15)}
  h1{margin:0 0 8px;font-size:2rem;color:#7c4dff}
  .ok{font-size:3rem;margin:16px 0}
  p{margin:6px 0;color:#9a9ab8;font-size:.95rem}
  code{color:#e8e8f0;background:#1e1e38;padding:2px 8px;border-radius:6px}
  a{color:#7c4dff;text-decoration:none}
</style>
</head>
<body>
<div class="card">
  <div class="ok">✅</div>
  <h1>VPS 部署驗證成功</h1>
  <p>主機名 <code>${hostname_str}</code></p>
  <p>公網 IP <code>${ipv4}</code></p>
  <p>部署時間 <code>${now}</code></p>
  <p style="margin-top:20px">Powered by <a href="https://github.com/web3-ai-game/oece-x-sh">oece-x.sh</a> · <a href="https://oece-x.com">oece-x.com</a></p>
</div>
</body>
</html>
EOF

    info "拉取 nginx:alpine 並啟動容器（端口 ${port}）..."
    if ! docker run -d --name "$DEMO_CONTAINER" \
        -p "${port}:80" \
        -v "${OECE_DEMO_DIR}:/usr/share/nginx/html:ro" \
        --restart unless-stopped \
        nginx:alpine >/dev/null; then
        err "容器啟動失敗，請檢查 docker 日誌。"
        return 1
    fi

    sleep 2
    local http_code
    http_code=$(curl -s -o /dev/null --max-time 8 -w '%{http_code}' "http://127.0.0.1:${port}/") || http_code="000"
    if [ "$http_code" = "200" ]; then
        ok "Demo 部署成功並通過自檢（HTTP 200）"
        printf '\n'
        kv "本機訪問" "http://127.0.0.1:${port}"
        kv "公網訪問" "http://${ipv4}:${port}"
        printf '\n'
        info "若公網無法訪問，請檢查雲廠商安全組 / 防火牆是否放行 ${port} 端口。"
    else
        warn "容器已啟動但自檢異常（HTTP ${http_code}），請檢查 docker logs ${DEMO_CONTAINER}"
    fi
}

remove_demo() {
    if ! command -v docker >/dev/null 2>&1; then
        warn "未安裝 Docker，無 Demo 可移除。"
        return 0
    fi
    if ! docker ps -a --format '{{.Names}}' | grep -qx "$DEMO_CONTAINER"; then
        info "Demo 容器不存在。"
        return 0
    fi
    confirm_danger "即將移除 Demo 容器 ${DEMO_CONTAINER}。" || { info "已取消"; return 0; }
    docker rm -f "$DEMO_CONTAINER" >/dev/null
    ok "Demo 容器已移除"
}

module_demo() {
    section "部署 Demo（nginx 驗證頁）"
    printf ' 1) 部署 Demo\n'
    printf ' 2) 移除 Demo\n'
    printf ' 0) 返回\n\n'
    printf '請選擇: '
    local choice
    read -r choice || choice="0"

    case "$choice" in
        1) printf '\n'; deploy_demo ;;
        2) printf '\n'; remove_demo ;;
        *) return 0 ;;
    esac
    disclaimer
}


#=======================================================================
# 模塊 6 · Sub2API 傻瓜式部署
#=======================================================================
# 無域名默認 IP:端口；sslip.io 零申請偽域名；DuckDNS 半自動免費子域。
# 不在生產機覆蓋 /opt/sub2api（本項目 api.oece-x.com 已佔用）。

s2a_dir() {
    printf '%s' "${SUB2API_DIR:-$SUB2API_DIR_DEFAULT}"
}

s2a_compose() {
    # 統一 compose 入口：優先 docker compose 插件
    if docker compose version >/dev/null 2>&1; then
        docker compose -p "$SUB2API_PROJECT" -f "$(s2a_dir)/docker-compose.yml" "$@"
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose -p "$SUB2API_PROJECT" -f "$(s2a_dir)/docker-compose.yml" "$@"
    else
        err "未找到 docker compose / docker-compose"
        return 1
    fi
}

s2a_require_docker() {
    if ! command -v docker >/dev/null 2>&1 || ! docker version >/dev/null 2>&1; then
        warn "需要 Docker 運行環境。"
        if confirm "現在安裝 Docker + Compose？"; then
            install_docker || return 1
        else
            info "請先在「環境一鍵安裝」中安裝 Docker。"
            return 1
        fi
    fi
    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        warn "未檢出 Compose。"
        if confirm "安裝 docker-compose-plugin？"; then
            pkg_install docker-compose-plugin || return 1
        else
            return 1
        fi
    fi
    return 0
}

s2a_port_in_use() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$" && return 0
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$" && return 0
    fi
    return 1
}

s2a_mem_mb() {
    awk '/^MemTotal:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || printf '0'
}

# 按記憶體分檔：輸出 shared_buffers|effective_cache|max_open|max_idle|redis_pool|redis_min_idle|max_conn
s2a_mem_profile() {
    local mb
    mb=$(s2a_mem_mb)
    if [ "$mb" -lt 1800 ] 2>/dev/null; then
        printf '128MB|512MB|32|16|128|8|100'
    elif [ "$mb" -lt 3800 ] 2>/dev/null; then
        printf '256MB|1GB|64|32|256|16|200'
    elif [ "$mb" -lt 7800 ] 2>/dev/null; then
        printf '512MB|2GB|128|64|1024|64|512'
    else
        printf '1GB|4GB|256|128|4096|256|1024'
    fi
}

s2a_env_set() {
    local file="$1" key="$2" val="$3"
    if grep -qE "^${key}=" "$file" 2>/dev/null; then
        # 用 awk 覆寫，避免 sed 特殊字元問題
        local tmp
        tmp=$(mktemp)
        awk -v k="$key" -v v="$val" 'BEGIN{FS=OFS="="} $1==k{$0=k"="v} {print}' "$file" > "$tmp"
        mv "$tmp" "$file"
    else
        printf '%s=%s\n' "$key" "$val" >> "$file"
    fi
}

s2a_gen_secret() {
    openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

s2a_gen_password() {
    # URL/終端友好密碼（無易混淆字元）
    openssl rand -base64 18 2>/dev/null | tr -d '/+=' | head -c 20
}

s2a_sslip_host() {
    local ip="$1"
    # 157.230.249.136 → 157-230-249-136.sslip.io
    printf '%s.sslip.io' "$(printf '%s' "$ip" | tr '.' '-')"
}

s2a_is_installed() {
    [ -f "$(s2a_dir)/docker-compose.yml" ] && [ -f "$(s2a_dir)/.env" ]
}

s2a_patch_compose_names() {
    local f="$1"
    # 避免與官方默認 container_name（sub2api*）及本機 api.oece-x.com 實例衝突
    sed -i \
        -e 's/container_name:[[:space:]]*sub2api-postgres/container_name: oece-sub2api-postgres/' \
        -e 's/container_name:[[:space:]]*sub2api-redis/container_name: oece-sub2api-redis/' \
        -e 's/container_name:[[:space:]]*sub2api$/container_name: oece-sub2api/' \
        -e 's/container_name:[[:space:]]*sub2api[[:space:]]*$/container_name: oece-sub2api/' \
        "$f"
    # 網路名隔離
    sed -i 's/sub2api-network/oece-sub2api-network/g' "$f"
}

s2a_detect_foreign_instance() {
    # 提示本機可能已有非本腳本管理的 Sub2API
    local found=0
    if [ -d /opt/sub2api ] && [ "$(s2a_dir)" != "/opt/sub2api" ]; then
        warn "偵測到 /opt/sub2api（可能是獨立部署，如 api.oece-x.com）。"
        found=1
    fi
    if command -v docker >/dev/null 2>&1; then
        if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx 'sub2api'; then
            warn "偵測到容器名 sub2api（非本腳本的 oece-sub2api 前綴）。"
            found=1
        fi
    fi
    if [ "$found" -eq 1 ]; then
        info "本腳本安裝到 $(s2a_dir)，容器前綴 oece-sub2api，默認不會覆蓋上述實例。"
        info "請務必選用空閒端口（若 8080 已被佔用會自動提示）。"
        printf '\n'
    fi
}

s2a_read_env() {
    local key="$1" file
    file="$(s2a_dir)/.env"
    [ -f "$file" ] || return 0
    awk -F= -v k="$key" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$file"
}

s2a_print_access() {
    local port bind ipv4 sslip
    port=$(s2a_read_env SERVER_PORT)
    [ -z "$port" ] && port="$SUB2API_PORT_DEFAULT"
    bind=$(s2a_read_env BIND_HOST)
    [ -z "$bind" ] && bind="0.0.0.0"
    ipv4=$(get_public_ip 4)
    [ -z "$ipv4" ] && ipv4="<公網IP>"

    section "訪問地址"
    kv "綁定" "${bind}:${port}"
    kv "本機" "http://127.0.0.1:${port}"
    if [ "$bind" = "127.0.0.1" ]; then
        warn "目前僅本機可訪問。若需公網，請到子選單改綁 0.0.0.0，或自建反代。"
    else
        kv "公網 IP" "http://${ipv4}:${port}"
        if [[ "$ipv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            sslip=$(s2a_sslip_host "$ipv4")
            kv "sslip.io" "http://${sslip}:${port}"
            kv "nip.io" "http://${ipv4}.nip.io:${port}"
            info "sslip.io / nip.io 為零註冊偽域名（IP 寫進主機名），無需申請。"
        fi
    fi
    if [ -f "$SUB2API_DUCKDNS_FILE" ]; then
        # shellcheck disable=SC1090
        . "$SUB2API_DUCKDNS_FILE" 2>/dev/null || true
        if [ -n "${DUCKDNS_DOMAIN:-}" ]; then
            kv "DuckDNS" "http://${DUCKDNS_DOMAIN}.duckdns.org:${port}"
        fi
    fi
    printf '\n'
    if [ -f "$SUB2API_CRED_FILE" ]; then
        info "管理員帳密見：${SUB2API_CRED_FILE}"
        # 僅展示郵箱，密碼不在狀態裡重複刷屏（安裝時已打印）
        local email
        email=$(awk -F= '/^ADMIN_EMAIL=/{print $2; exit}' "$SUB2API_CRED_FILE" 2>/dev/null || true)
        [ -n "$email" ] && kv "管理員郵箱" "$email"
    fi
    info "若公網打不開：檢查雲廠商安全組 / ufw 是否放行 TCP ${port}。"
}

s2a_write_credentials() {
    local email="$1" pass="$2" port="$3"
    mkdir -p "$OECE_HOME"
    umask 077
    cat > "$SUB2API_CRED_FILE" <<EOF
# oece-x.sh Sub2API credentials — $(date -Iseconds 2>/dev/null || date)
# 請勿截圖發佈到公開頻道
INSTALL_DIR=$(s2a_dir)
ADMIN_EMAIL=${email}
ADMIN_PASSWORD=${pass}
SERVER_PORT=${port}
EOF
    chmod 600 "$SUB2API_CRED_FILE"
}

s2a_install() {
    section "Sub2API 一鍵安裝"
    s2a_require_docker || return 0
    s2a_detect_foreign_instance

    if s2a_is_installed; then
        warn "已存在安裝目錄：$(s2a_dir)"
        if ! confirm "重新生成配置並重裝容器？（數據目錄可選擇保留）"; then
            info "已取消"
            return 0
        fi
        if confirm "停止並移除現有 oece-sub2api 容器？"; then
            s2a_compose down 2>/dev/null || true
        fi
    fi

    local mem_mb profile
    mem_mb=$(s2a_mem_mb)
    profile=$(s2a_mem_profile)
    info "偵測記憶體約 ${mem_mb} MB，將套用對應資源檔以適配小 VPS。"
    if [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 1500 ]; then
        warn "記憶體 < 1.5GB，Sub2API（含 Postgres+Redis）可能吃緊，建議 ≥2GB。"
        confirm "仍要繼續？" || { info "已取消"; return 0; }
    fi

    local port
    printf '請輸入對外端口 [%s]: ' "$SUB2API_PORT_DEFAULT"
    read -r port || port=""
    [ -z "$port" ] && port="$SUB2API_PORT_DEFAULT"
    case "$port" in
        ''|*[!0-9]*) err "端口必須是數字"; return 1 ;;
    esac
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        err "端口範圍 1-65535"
        return 1
    fi
    if s2a_port_in_use "$port"; then
        err "端口 ${port} 已被佔用。若本機已有 api 反代/Sub2API，請換端口（如 18080）。"
        return 1
    fi

    local email pass
    printf '管理員郵箱 [%s]: ' "admin@localhost"
    read -r email || email=""
    [ -z "$email" ] && email="admin@localhost"
    pass=$(s2a_gen_password)
    [ -z "$pass" ] && pass=$(s2a_gen_secret | head -c 16)

    local dir
    dir=$(s2a_dir)
    mkdir -p "$dir" "$dir/data" "$dir/postgres_data" "$dir/redis_data"

    info "下載官方 docker-compose 與 .env 模板..."
    safe_download "$SUB2API_COMPOSE_URL" "${dir}/docker-compose.yml" || return 1
    safe_download "$SUB2API_ENV_EXAMPLE_URL" "${dir}/.env.example" || return 1
    s2a_patch_compose_names "${dir}/docker-compose.yml"

    cp "${dir}/.env.example" "${dir}/.env"
    chmod 600 "${dir}/.env"

    local jwt totp pgpass
    jwt=$(s2a_gen_secret)
    totp=$(s2a_gen_secret)
    pgpass=$(s2a_gen_secret)

    local sb ecache mop mid rpool rmin pmax
    IFS='|' read -r sb ecache mop mid rpool rmin pmax <<< "$profile"

    s2a_env_set "${dir}/.env" "BIND_HOST" "0.0.0.0"
    s2a_env_set "${dir}/.env" "SERVER_PORT" "$port"
    s2a_env_set "${dir}/.env" "ADMIN_EMAIL" "$email"
    s2a_env_set "${dir}/.env" "ADMIN_PASSWORD" "$pass"
    s2a_env_set "${dir}/.env" "JWT_SECRET" "$jwt"
    s2a_env_set "${dir}/.env" "TOTP_ENCRYPTION_KEY" "$totp"
    s2a_env_set "${dir}/.env" "POSTGRES_PASSWORD" "$pgpass"
    s2a_env_set "${dir}/.env" "POSTGRES_SHARED_BUFFERS" "$sb"
    s2a_env_set "${dir}/.env" "POSTGRES_EFFECTIVE_CACHE_SIZE" "$ecache"
    s2a_env_set "${dir}/.env" "POSTGRES_MAX_CONNECTIONS" "$pmax"
    s2a_env_set "${dir}/.env" "DATABASE_MAX_OPEN_CONNS" "$mop"
    s2a_env_set "${dir}/.env" "DATABASE_MAX_IDLE_CONNS" "$mid"
    s2a_env_set "${dir}/.env" "REDIS_POOL_SIZE" "$rpool"
    s2a_env_set "${dir}/.env" "REDIS_MIN_IDLE_CONNS" "$rmin"
    s2a_env_set "${dir}/.env" "TZ" "Asia/Shanghai"

    s2a_write_credentials "$email" "$pass" "$port"

    info "拉取鏡像並啟動（首次可能需數分鐘）..."
    if ! ( cd "$dir" && s2a_compose pull ); then
        err "鏡像拉取失敗，請檢查網路（需能訪問 Docker Hub / ghcr 鏡像源）。"
        return 1
    fi
    if ! ( cd "$dir" && s2a_compose up -d ); then
        err "啟動失敗，請執行：cd ${dir} && docker compose -p ${SUB2API_PROJECT} logs"
        return 1
    fi

    info "等待健康檢查（最長約 120 秒）..."
    local http_code=000
    for _ in $(seq 1 40); do
        http_code=$(curl -s -o /dev/null --max-time 3 -w '%{http_code}' "http://127.0.0.1:${port}/health" 2>/dev/null) || http_code="000"
        if [ "$http_code" = "200" ]; then
            break
        fi
        # 首頁 200/302 也算起來了
        http_code=$(curl -s -o /dev/null --max-time 3 -w '%{http_code}' "http://127.0.0.1:${port}/" 2>/dev/null) || http_code="000"
        case "$http_code" in
            200|301|302|303|307|308) break ;;
        esac
        sleep 3
    done

    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ] \
        || [ "$http_code" = "303" ] || [ "$http_code" = "307" ] || [ "$http_code" = "308" ]; then
        ok "Sub2API 已啟動（HTTP ${http_code}）"
    else
        warn "容器已啟動但健康檢查超時（HTTP ${http_code}）。可稍後在「狀態/日誌」查看。"
        warn "常見原因：鏡像拉取慢、磁碟慢、記憶體不足。"
    fi

    printf '\n'
    ok "安裝完成"
    kv "安裝目錄" "$dir"
    kv "管理員郵箱" "$email"
    kv "管理員密碼" "$pass"
    kv "憑證檔案" "$SUB2API_CRED_FILE"
    printf '\n'
    s2a_print_access
    warn "請立即保存管理員密碼；完整密鑰在 ${dir}/.env（chmod 600）。"
    info "上游項目：https://github.com/Wei-Shaw/sub2api"
}

s2a_status() {
    section "Sub2API 狀態"
    if ! s2a_is_installed; then
        warn "尚未通過本腳本安裝（目錄 $(s2a_dir) 不完整）。"
        s2a_detect_foreign_instance
        return 0
    fi
    s2a_require_docker || return 0
    s2a_compose ps 2>/dev/null || docker ps -a --filter "name=oece-sub2api" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    printf '\n'
    s2a_print_access
}

s2a_logs() {
    section "Sub2API 日誌"
    s2a_is_installed || { warn "未安裝"; return 0; }
    s2a_require_docker || return 0
    info "顯示最近 80 行（Ctrl+C 不影響服務）..."
    s2a_compose logs --tail=80 sub2api 2>/dev/null || s2a_compose logs --tail=80
}

s2a_update() {
    section "更新 Sub2API 鏡像"
    s2a_is_installed || { warn "未安裝"; return 0; }
    s2a_require_docker || return 0
    confirm "拉取 latest 並重啟容器？" || { info "已取消"; return 0; }
    s2a_compose pull && s2a_compose up -d
    ok "更新流程已執行"
    s2a_print_access
}

s2a_rebind() {
    section "修改綁定 / 端口"
    s2a_is_installed || { warn "未安裝"; return 0; }
    s2a_require_docker || return 0

    local cur_bind cur_port new_bind new_port
    cur_bind=$(s2a_read_env BIND_HOST)
    cur_port=$(s2a_read_env SERVER_PORT)
    [ -z "$cur_bind" ] && cur_bind="0.0.0.0"
    [ -z "$cur_port" ] && cur_port="$SUB2API_PORT_DEFAULT"
    info "當前：${cur_bind}:${cur_port}"
    printf ' 1) 公網可訪 0.0.0.0（無域名直連）\n'
    printf ' 2) 僅本機 127.0.0.1（配合 nginx/Caddy 反代）\n'
    printf ' 3) 只改端口\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    new_bind="$cur_bind"
    new_port="$cur_port"
    case "$c" in
        1) new_bind="0.0.0.0" ;;
        2) new_bind="127.0.0.1" ;;
        3) : ;;
        *) return 0 ;;
    esac
    printf '端口 [%s]: ' "$cur_port"
    read -r new_port || new_port=""
    [ -z "$new_port" ] && new_port="$cur_port"
    case "$new_port" in
        ''|*[!0-9]*) err "端口無效"; return 1 ;;
    esac
    if [ "$new_port" != "$cur_port" ] && s2a_port_in_use "$new_port"; then
        err "端口 ${new_port} 已被佔用"
        return 1
    fi
    s2a_env_set "$(s2a_dir)/.env" "BIND_HOST" "$new_bind"
    s2a_env_set "$(s2a_dir)/.env" "SERVER_PORT" "$new_port"
    if [ -f "$SUB2API_CRED_FILE" ]; then
        s2a_env_set "$SUB2API_CRED_FILE" "SERVER_PORT" "$new_port" 2>/dev/null || true
    fi
    info "重啟容器使配置生效..."
    s2a_compose up -d
    ok "已更新為 ${new_bind}:${new_port}"
    s2a_print_access
}

s2a_duckdns_setup() {
    section "DuckDNS 免費子域名"
    info "DuckDNS 提供免費 *.duckdns.org 子域（需免費帳號，非全自動搶註）。"
    info "步驟：瀏覽器打開 https://www.duckdns.org → 登入 → 建立 subdomain → 複製 token"
    printf '\n'
    local domain token ip
    printf '子域名（不含 .duckdns.org）: '
    read -r domain || domain=""
    domain=$(printf '%s' "$domain" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    if [ -z "$domain" ]; then
        err "子域名無效"
        return 1
    fi
    printf 'DuckDNS token: '
    read -r token || token=""
    if [ -z "$token" ]; then
        err "token 不能為空"
        return 1
    fi
    ip=$(get_public_ip 4)
    if [ -z "$ip" ]; then
        err "無法取得公網 IP"
        return 1
    fi
    info "更新 ${domain}.duckdns.org → ${ip} ..."
    local resp
    resp=$(curl -fsS --max-time 15 \
        "https://www.duckdns.org/update?domains=${domain}&token=${token}&ip=${ip}" 2>/dev/null) || resp="fail"
    if [ "$resp" = "OK" ]; then
        ok "DuckDNS 更新成功"
    else
        err "DuckDNS 更新失敗（回應: ${resp}）。請檢查 token / 子域名是否正確。"
        return 1
    fi

    mkdir -p "$OECE_HOME"
    umask 077
    cat > "$SUB2API_DUCKDNS_FILE" <<EOF
# managed by oece-x.sh
DUCKDNS_DOMAIN=${domain}
DUCKDNS_TOKEN=${token}
EOF
    chmod 600 "$SUB2API_DUCKDNS_FILE"

    # 可選：systemd timer 或 cron 保活動態 IP
    if confirm "安裝每 5 分鐘自動更新 IP 的 cron？（適合動態公網 IP）"; then
        local cron_line
        cron_line="*/5 * * * * root curl -fsS \"https://www.duckdns.org/update?domains=${domain}&token=${token}&ip=\" >/dev/null 2>&1"
        if [ -d /etc/cron.d ]; then
            printf '%s\n' "$cron_line" > /etc/cron.d/oece-duckdns
            chmod 644 /etc/cron.d/oece-duckdns
            ok "已寫入 /etc/cron.d/oece-duckdns"
        else
            warn "無 /etc/cron.d，請手動添加 cron：${cron_line}"
        fi
    fi

    local port
    port=$(s2a_read_env SERVER_PORT)
    [ -z "$port" ] && port="$SUB2API_PORT_DEFAULT"
    kv "訪問" "http://${domain}.duckdns.org:${port}"
    info "DNS 全球生效通常 < 1 分鐘。HTTPS 請自行用 Caddy/certbot（本版不做一鍵簽章）。"
}

s2a_access_menu() {
    section "訪問方式（無域名友好）"
    if s2a_is_installed; then
        s2a_print_access
    else
        warn "尚未安裝 Sub2API；仍可先配置 DuckDNS 或查看偽域名說明。"
        local ipv4
        ipv4=$(get_public_ip 4)
        if [[ "${ipv4}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            kv "sslip.io 示例" "http://$(s2a_sslip_host "$ipv4"):8080"
        fi
    fi
    printf '\n'
    printf ' 1) 重新顯示 IP / sslip.io / nip.io 地址\n'
    printf ' 2) 配置 DuckDNS 免費子域名（需 token）\n'
    printf ' 3) 自有域名指引（不改本機 nginx）\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1) s2a_print_access ;;
        2) s2a_duckdns_setup ;;
        3)
            section "自有域名指引"
            local ip port
            ip=$(get_public_ip 4)
            port=$(s2a_read_env SERVER_PORT)
            [ -z "$port" ] && port="$SUB2API_PORT_DEFAULT"
            info "1. 在域名 DNS 添加 A 記錄指向 ${ip:-\<公網IP\>}"
            info "2. 建議用 Caddy / nginx 反代到 127.0.0.1:${port}，並將 BIND 改為 127.0.0.1"
            printf '\n示例 Caddyfile：\n'
            cat <<EOF
api.example.com {
    reverse_proxy 127.0.0.1:${port}
}
EOF
            printf '\n示例 nginx：\n'
            cat <<EOF
server {
    listen 443 ssl http2;
    server_name api.example.com;
    # ssl_certificate ...;
    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
            info "本腳本不會自動修改系統 nginx，避免誤傷其他站點。"
            ;;
        *) return 0 ;;
    esac
}

s2a_uninstall() {
    section "卸載 Sub2API（僅本腳本實例）"
    if ! s2a_is_installed && ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q '^oece-sub2api'; then
        info "未發現 oece-sub2api 實例。"
        return 0
    fi
    info "將操作："
    printf '  · compose project %s\n' "$SUB2API_PROJECT"
    printf '  · 目錄 %s\n' "$(s2a_dir)"
    printf '  %s不會動 /opt/sub2api 或容器名 sub2api（其他實例）%s\n\n' "$C_DIM" "$C_RESET"
    confirm_danger "確認卸載本腳本部署的 Sub2API？" || { info "已取消"; return 0; }

    if s2a_is_installed; then
        s2a_compose down 2>/dev/null || true
    fi
    docker rm -f oece-sub2api oece-sub2api-postgres oece-sub2api-redis 2>/dev/null || true

    if confirm "同時刪除數據目錄 $(s2a_dir)？（含數據庫，不可恢復）"; then
        rm -rf "$(s2a_dir)"
        ok "已刪除 $(s2a_dir)"
    else
        ok "容器已停，數據目錄保留"
    fi
    if [ -f "$SUB2API_CRED_FILE" ] && confirm "刪除憑證檔 ${SUB2API_CRED_FILE}？"; then
        rm -f "$SUB2API_CRED_FILE"
    fi
    ok "卸載流程結束"
}

module_sub2api() {
    section "部署 Sub2API（AI API 中轉 · 無域名友好）"
    info "上游開源：Wei-Shaw/sub2api · Docker Compose 一鍵封裝"
    info "安裝路徑默認 ${SUB2API_DIR_DEFAULT}（隔離前綴 oece-sub2api）"
    printf '\n'
    printf ' 1) 一鍵安裝 / 重裝\n'
    printf ' 2) 訪問方式（IP / sslip.io / DuckDNS）\n'
    printf ' 3) 狀態 / 帳號與地址\n'
    printf ' 4) 日誌\n'
    printf ' 5) 更新鏡像\n'
    printf ' 6) 修改綁定與端口\n'
    printf ' 7) 卸載本腳本實例\n'
    printf ' 0) 返回\n\n'
    printf '請選擇: '
    local choice
    read -r choice || choice="0"
    case "$choice" in
        1) printf '\n'; s2a_install ;;
        2) printf '\n'; s2a_access_menu ;;
        3) printf '\n'; s2a_status ;;
        4) printf '\n'; s2a_logs ;;
        5) printf '\n'; s2a_update ;;
        6) printf '\n'; s2a_rebind ;;
        7) printf '\n'; s2a_uninstall ;;
        *) return 0 ;;
    esac
    disclaimer
}

#=======================================================================
# 維護：更新檢查 / 卸載
#=======================================================================
check_update() {
    section "檢查更新"
    info "當前版本: v${SCRIPT_VERSION}"
    info "查詢遠端最新版本..."

    local remote_script="${TMP_DIR}/remote.sh" remote_ver=""
    if ! curl "${CURL_OPTS[@]}" --max-time 15 -o "$remote_script" "$SCRIPT_RAW_URL" 2>/dev/null; then
        err "無法獲取遠端版本（倉庫未發佈或網路異常）。"
        return 0
    fi
    remote_ver=$(awk -F'"' '/^SCRIPT_VERSION=/{print $2; exit}' "$remote_script")
    if [ -z "$remote_ver" ]; then
        err "遠端腳本格式異常，跳過更新。"
        return 0
    fi
    info "遠端版本: v${remote_ver}"

    if [ "$remote_ver" = "$SCRIPT_VERSION" ]; then
        ok "已是最新版本。"
        return 0
    fi
    local newest
    newest=$(printf '%s\n%s\n' "$SCRIPT_VERSION" "$remote_ver" | sort -V | tail -1)
    if [ "$newest" = "$SCRIPT_VERSION" ]; then
        warn "本地版本高於遠端（開發版？），跳過更新。"
        return 0
    fi

    if ! bash -n "$remote_script" 2>/dev/null; then
        err "遠端腳本語法校驗失敗，拒絕更新。"
        return 0
    fi

    local self="${BASH_SOURCE[0]:-$0}"
    if [ ! -f "$self" ] || [ ! -w "$self" ]; then
        warn "當前以管道/唯讀方式運行，無法原地更新。"
        info "請重新執行一鍵命令即可獲得新版："
        printf '  %sbash <(curl -sSL %s)%s\n' "$C_CYAN" "$SCRIPT_RAW_URL" "$C_RESET"
        return 0
    fi

    confirm "更新 v${SCRIPT_VERSION} → v${remote_ver}？（舊版將備份為 ${self}.bak）" || { info "已取消"; return 0; }
    cp "$self" "${self}.bak"
    cat "$remote_script" > "$self"
    chmod +x "$self"
    ok "更新完成，請重新運行腳本。"
    exit 0
}

uninstall_all() {
    section "卸載"
    info "將移除以下內容："
    printf '  · %s（NextTrace / Ookla CLI / Demo 頁面等下載物）\n' "$OECE_HOME"
    if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$DEMO_CONTAINER"; then
        printf '  · Demo 容器 %s\n' "$DEMO_CONTAINER"
    fi
    printf '  %s（不會動 Docker、系統包、Sub2API 業務實例；卸 Sub2API 請用選單 6→7）%s\n\n' "$C_DIM" "$C_RESET"

    confirm_danger "確認卸載 oece-x.sh 相關檔案？" || { info "已取消"; return 0; }

    if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$DEMO_CONTAINER"; then
        docker rm -f "$DEMO_CONTAINER" >/dev/null 2>&1 || true
        ok "Demo 容器已移除"
    fi
    rm -rf "$OECE_HOME"
    ok "已刪除 ${OECE_HOME}"

    local self="${BASH_SOURCE[0]:-$0}"
    if [ -f "$self" ] && [ -w "$self" ]; then
        if confirm "同時刪除腳本本體 ${self}？"; then
            rm -f "$self"
            ok "腳本已刪除，感謝使用。"
        fi
    fi
    info "卸載完成，再見。"
    exit 0
}

#=======================================================================
# 主選單
#=======================================================================
print_banner() {
    printf '%s%s' "$C_MAGENTA" "$C_BOLD"
    cat <<'BANNER'
   ____  ______ ____ ______      __  __
  / __ \|  ____/ ___|  ____|     \ \/ /
 | |  | | |__ | |   | |__   _____ \  /
 | |  | |  __|| |   |  __| |_____|/  \
 | |__| | |___| |___| |____      /  /\ \
  \____/|______\____|______|    /__/  \_\
BANNER
    printf '%s' "$C_RESET"
    printf '%s  oece-x.sh v%s · VPS 體檢 · 部署測試 · Sub2API%s\n' "$C_DIM" "$SCRIPT_VERSION" "$C_RESET"
    printf '%s  YouTube @oece-x · oece-x.com%s\n' "$C_DIM" "$C_RESET"
}

main_menu() {
    while true; do
        printf '\n'
        divider
        printf ' %s主選單%s\n' "$C_BOLD" "$C_RESET"
        divider
        printf ' 1) 系統體檢      %s CPU / 記憶體 / 虛擬化 / BBR / IP 資訊%s\n' "$C_DIM" "$C_RESET"
        printf ' 2) 網路測速      %s Cloudflare 標準 + Ookla 深度（可選）%s\n' "$C_DIM" "$C_RESET"
        printf ' 3) 回程路由檢測  %s 三網回程線路（NextTrace 標註 AS）%s\n' "$C_DIM" "$C_RESET"
        printf ' 4) 環境一鍵安裝  %s Docker / 常用工具%s\n' "$C_DIM" "$C_RESET"
        printf ' 5) 部署 Demo     %s 一鍵拉起 nginx 驗證頁%s\n' "$C_DIM" "$C_RESET"
        printf ' 6) 部署 Sub2API  %s AI API 中轉 · 無域名友好%s\n' "$C_DIM" "$C_RESET"
        divider
        printf ' 7) 檢查更新\n'
        printf ' 8) 卸載\n'
        printf ' 0) 退出\n'
        divider
        printf '請輸入選項: '

        local choice
        read -r choice || { printf '\n'; break; }
        case "$choice" in
            1) module_sysinfo;     pause ;;
            2) module_speedtest;   pause ;;
            3) module_route;       pause ;;
            4) module_env_install; pause ;;
            5) module_demo;        pause ;;
            6) module_sub2api;     pause ;;
            7) check_update;       pause ;;
            8) uninstall_all ;;
            0) info "再見。"; break ;;
            *) warn "無效選項：${choice}" ;;
        esac
    done
}

usage() {
    cat <<EOF
oece-x.sh v${SCRIPT_VERSION} — VPS 體檢與一鍵部署工具（含 Sub2API）

用法:
  bash oece-x.sh            進入互動選單
  bash oece-x.sh --version  顯示版本
  bash oece-x.sh --help     顯示本說明

一鍵執行:
  bash <(curl -sSL ${SCRIPT_RAW_URL})

本工具僅供測試，結果僅供參考；不含任何繞過網路封鎖之功能。
EOF
}

main() {
    case "${1:-}" in
        --version|-v) printf 'oece-x.sh v%s\n' "$SCRIPT_VERSION"; exit 0 ;;
        --help|-h)    usage; exit 0 ;;
        "")           : ;;
        *)            usage; exit 1 ;;
    esac

    require_root
    detect_os
    detect_arch
    ensure_deps

    print_banner
    main_menu
}

main "$@"
