#!/usr/bin/env bash
#=======================================================================
#  oece-x.sh — VPS 體檢與一鍵部署測試工具
#
#  幫你在 3 分鐘內判斷一台 VPS 到底能不能用、值不值。
#  系統體檢 · 網路測速 · 回程路由 · 環境安裝 · 部署 Demo
#
#  Project : https://github.com/web3-ai-game/oece-x-sh
#  Channel : YouTube @oece-x · https://oece-x.com
#  License : MIT
#
#  本工具不含任何繞過網路封鎖之功能，僅供 VPS 測試與學習用途。
#=======================================================================

SCRIPT_VERSION="1.0.0"
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
    printf '  %s（不會動你的 Docker、系統包與任何業務數據）%s\n\n' "$C_DIM" "$C_RESET"

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
    printf '%s  oece-x.sh v%s · VPS 體檢與一鍵部署測試工具%s\n' "$C_DIM" "$SCRIPT_VERSION" "$C_RESET"
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
        divider
        printf ' 6) 檢查更新\n'
        printf ' 7) 卸載\n'
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
            6) check_update;       pause ;;
            7) uninstall_all ;;
            0) info "再見。"; break ;;
            *) warn "無效選項：${choice}" ;;
        esac
    done
}

usage() {
    cat <<EOF
oece-x.sh v${SCRIPT_VERSION} — VPS 體檢與一鍵部署測試工具

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
