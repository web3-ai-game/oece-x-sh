#!/usr/bin/env bash
#=======================================================================
#  oece-x.sh — VPS 體檢與運維精選工具箱
#
#  幫你在 3 分鐘內判斷一台 VPS 到底能不能用、值不值。
#  體檢 · 跑分 · 解鎖檢測 · BBR · SSH 加固 · Docker · 反代 · Top3 · 酷炫終端
#
#  Project : https://github.com/web3-ai-game/oece-x-sh
#  Channel : YouTube @oece-x · https://oece-x.com
#  License : MIT
#
#  本工具不含任何繞過網路封鎖之功能，僅供 VPS 測試與學習用途。
#=======================================================================

SCRIPT_VERSION="1.3.1"
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
    # 恢復游標（動畫可能隱藏）
    printf '\033[?25h' 2>/dev/null || true
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
    section "基礎工具一鍵裝"
    info "將安裝：curl wget vim htop git unzip tar fail2ban（已有則跳過）"
    confirm "確認安裝？" || { info "已取消"; return 0; }
    case "$PKG_MGR" in
        apt)
            pkg_install curl wget vim htop git unzip tar ca-certificates fail2ban
            ;;
        dnf|yum)
            pkg_install curl wget vim htop git unzip tar ca-certificates fail2ban || \
                pkg_install curl wget vim htop git unzip tar ca-certificates
            ;;
    esac
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files fail2ban.service >/dev/null 2>&1; then
        systemctl enable --now fail2ban 2>/dev/null || true
        ok "fail2ban 已嘗試啟用"
    fi
    ok "基礎工具安裝完成"
    for c in curl wget vim htop git fail2ban-client; do
        if command -v "$c" >/dev/null 2>&1 || command -v "${c%-client}" >/dev/null 2>&1; then
            printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$c"
        else
            printf '  %s·%s %s（未檢出命令，可能包名不同）\n' "$C_DIM" "$C_RESET" "$c"
        fi
    done
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
# UI · 酷炫開場動畫 + 選單樣式
#=======================================================================
anim_enabled() {
    [ -t 1 ] || return 1
    [ -z "${OECE_NO_ANIM:-}" ] || return 1
    [ -z "${OECE_FAST:-}" ] || return 1
    return 0
}

anim_sleep() {
    # $1 seconds (float ok if sleep supports)
    sleep "$1" 2>/dev/null || sleep 0
}

intro_animation() {
    anim_enabled || return 0

    printf '\033[?25l'
    printf '\033[2J\033[H'

    # 經典 Linux 工具風：大號 FIGlet 塊字 + 彩虹色波（類 hydra/lolcat 開場）
    # 6 行 × OECE-X
    local -a L=(
        '  ██████╗ ███████╗ ██████╗███████╗    ██╗  ██╗'
        ' ██╔═══██╗██╔════╝██╔════╝██╔════╝    ╚██╗██╔╝'
        ' ██║   ██║█████╗  ██║     █████╗█████╗ ╚███╔╝ '
        ' ██║   ██║██╔══╝  ██║     ██╔══╝╚════╝ ██╔██╗ '
        ' ╚██████╔╝███████╗╚██████╗███████╗    ██╔╝ ██╗'
        '  ╚═════╝ ╚══════╝ ╚═════╝╚══════╝    ╚═╝  ╚═╝'
    )
    # 256 色彩虹波：每幀色相偏移
    local frame row col ch code phase
    local rows=${#L[@]}
    local max_frames=18
    for ((frame=0; frame<max_frames; frame++)); do
        printf '\033[H'
        printf '\n'
        for ((row=0; row<rows; row++)); do
            printf '  '
            local line="${L[$row]}"
            local len=${#line}
            for ((col=0; col<len; col++)); do
                ch="${line:$col:1}"
                if [ "$ch" = ' ' ]; then
                    printf ' '
                else
                    # 色相 196→201 紫紅 + 39→45 青 循環
                    phase=$(( (col * 3 + frame * 7 + row * 2) % 30 ))
                    if [ "$phase" -lt 10 ]; then
                        code=$((196 + phase % 6))
                    elif [ "$phase" -lt 20 ]; then
                        code=$((39 + (phase - 10) % 6))
                    else
                        code=$((129 + (phase - 20) % 6))
                    fi
                    # 無 256 色終端時退回固定亮色
                    if [ -n "${C_CYAN}" ]; then
                        printf '\033[1;38;5;%sm%s' "$code" "$ch"
                    else
                        printf '%s' "$ch"
                    fi
                fi
            done
            printf '%s\n' "$C_RESET"
        done
        # 底部掃描蛇條（經典進度）
        local snake_pos=$(( frame % 28 ))
        local bar="" i
        for ((i=0; i<28; i++)); do
            if [ "$i" -ge "$snake_pos" ] && [ "$i" -lt $((snake_pos + 5)) ]; then
                bar+="█"
            else
                bar+="░"
            fi
        done
        printf '\n  %s[%s]%s %sloading modules…%s\n' "$C_CYAN" "$bar" "$C_RESET" "$C_DIM" "$C_RESET"
        anim_sleep 0.045
    done

    printf '\033[2J\033[H'
    # 定格最終 Logo（高對比青/洋紅）
    printf '\n'
    for ((row=0; row<rows; row++)); do
        if [ $((row % 2)) -eq 0 ]; then
            printf '  %s%s%s\n' "$C_CYAN" "$C_BOLD" "${L[$row]}"
        else
            printf '  %s%s%s\n' "$C_MAGENTA" "$C_BOLD" "${L[$row]}"
        fi
        printf '%s' "$C_RESET"
    done
    printf '\n'
    printf '  %s╔══════════════════════════════════════════════╗%s\n' "$C_DIM" "$C_RESET"
    printf '  %s║%s  oece-x.sh  v%s  ·  VPS 運維精選            %s║%s\n' \
        "$C_DIM" "$C_GREEN" "$SCRIPT_VERSION" "$C_DIM" "$C_RESET"
    printf '  %s║%s  YouTube @oece-x  ·  oece-x.com/x           %s║%s\n' \
        "$C_DIM" "$C_DIM" "$C_DIM" "$C_RESET"
    printf '  %s╚══════════════════════════════════════════════╝%s\n' "$C_DIM" "$C_RESET"
    anim_sleep 0.35
    printf '\033[?25h'
}

menu_group() {
    # 分組標題：單列清單，不用雙欄
    printf '%s%s── %s ──%s\n' "$C_DIM" "$C_BOLD" "$*" "$C_RESET"
}

menu_item() {
    # 單列垂直：  N)  標題 ★
    #             說明（dim，可選）
    # menu_item NUM "label" ["hint"] [star=1]
    local num="$1" label="$2" hint="${3:-}" star="${4:-}"
    local star_s=""
    [ "$star" = "1" ] && star_s=" ${C_YELLOW}★${C_RESET}"
    printf ' %s%2s)%s  %s%s%s%s\n' \
        "$C_CYAN" "$num" "$C_RESET" "$C_BOLD" "$label" "$C_RESET" "$star_s"
    if [ -n "$hint" ]; then
        printf '       %s%s%s\n' "$C_DIM" "$hint" "$C_RESET"
    fi
}

#=======================================================================
# 系統運維：更新 / 清理 / BBR / Swap / 時區DNS
#=======================================================================
module_sys_update() {
    section "系統更新"
    case "$PKG_MGR" in
        apt)
            info "將執行：apt-get update && apt-get upgrade -y"
            confirm "繼續？" || { info "已取消"; return 0; }
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
            ok "系統更新完成"
            ;;
        dnf)
            confirm "執行 dnf upgrade -y？" || { info "已取消"; return 0; }
            dnf upgrade -y
            ok "系統更新完成"
            ;;
        yum)
            confirm "執行 yum update -y？" || { info "已取消"; return 0; }
            yum update -y
            ok "系統更新完成"
            ;;
        *) err "未知包管理器"; return 1 ;;
    esac
}

module_sys_clean() {
    section "系統清理"
    printf ' 1) 包管理器緩存清理\n'
    printf ' 2) journal 日誌（保留 3 天）\n'
    printf ' 3) 臨時目錄 /tmp 內 7 天前檔案（謹慎）\n'
    printf ' 4) 全部執行（1+2）\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1|4)
            case "$PKG_MGR" in
                apt) apt-get autoremove -y 2>/dev/null || true; apt-get clean 2>/dev/null || true; ok "apt 清理完成" ;;
                dnf) dnf clean all 2>/dev/null || true; ok "dnf 清理完成" ;;
                yum) yum clean all 2>/dev/null || true; ok "yum 清理完成" ;;
            esac
            ;;&
        2|4)
            if command -v journalctl >/dev/null 2>&1; then
                journalctl --vacuum-time=3d 2>/dev/null || true
                ok "journal 已限制保留 3 天"
            else
                warn "無 journalctl"
            fi
            ;;&
        3)
            confirm_danger "將刪除 /tmp 下 7 天未訪問的普通檔案（不跟目錄）" || { info "已取消"; return 0; }
            find /tmp -mindepth 1 -mtime +7 -type f -delete 2>/dev/null || true
            ok "/tmp 舊檔清理完成"
            ;;
        0) return 0 ;;
        *) warn "無效選項" ;;
    esac
}

module_bbr() {
    section "BBR / TCP 擁塞控制"
    local cc qdisc
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '?')
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo '?')
    kv "當前擁塞控制" "$cc"
    kv "默認隊列" "$qdisc"
    # 是否可用 bbr
    if [ -r /proc/sys/net/ipv4/tcp_available_congestion_control ]; then
        kv "可用算法" "$(cat /proc/sys/net/ipv4/tcp_available_congestion_control)"
    fi
    printf '\n'
    printf ' 1) 啟用 BBR（fq + bbr，寫入 sysctl.d）★\n'
    printf ' 2) 僅查看狀態\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1)
            if ! grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
                err "內核未提供 bbr（需較新內核）。可用算法見上。"
                return 0
            fi
            confirm "寫入 /etc/sysctl.d/99-oece-bbr.conf 並立即生效？" || { info "已取消"; return 0; }
            cat > /etc/sysctl.d/99-oece-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
            sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-oece-bbr.conf >/dev/null 2>&1 || true
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true
            ok "BBR 已嘗試啟用：$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
            kv "隊列" "$(sysctl -n net.core.default_qdisc 2>/dev/null)"
            ;;
        2) : ;;
        *) return 0 ;;
    esac
}

module_swap() {
    section "Swap 虛擬記憶體"
    free -h 2>/dev/null || true
    swapon --show 2>/dev/null || true
    printf '\n'
    printf ' 1) 建立 / 調整 swap 檔（默認 1G / 2G）\n'
    printf ' 2) 關閉並刪除 /swapfile（若存在）\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1)
            local size_gb=1
            printf '大小 GB [1]: '
            read -r size_gb || size_gb=1
            [ -z "$size_gb" ] && size_gb=1
            case "$size_gb" in *[!0-9]*|"") err "請輸入正整數 GB"; return 1 ;; esac
            confirm "建立 ${size_gb}G swap 於 /swapfile？" || { info "已取消"; return 0; }
            if swapon --show 2>/dev/null | grep -q '/swapfile'; then
                swapoff /swapfile 2>/dev/null || true
            fi
            rm -f /swapfile
            # fallocate 或 dd
            if fallocate -l "${size_gb}G" /swapfile 2>/dev/null; then
                :
            else
                dd if=/dev/zero of=/swapfile bs=1M count=$((size_gb * 1024)) status=progress
            fi
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            if ! grep -q '^/swapfile' /etc/fstab 2>/dev/null; then
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
            fi
            ok "Swap 已啟用"
            free -h
            ;;
        2)
            confirm_danger "關閉並刪除 /swapfile" || { info "已取消"; return 0; }
            swapoff /swapfile 2>/dev/null || true
            rm -f /swapfile
            if [ -f /etc/fstab ]; then
                sed -i '\#^/swapfile#d' /etc/fstab
            fi
            ok "已移除 /swapfile"
            ;;
        *) return 0 ;;
    esac
}

module_tz_dns() {
    section "時區 / DNS"
    printf ' 1) 設定時區（timedatectl）\n'
    printf ' 2) 優化 DNS（寫入 systemd-resolved 或 /etc/resolv.conf 提示）\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1)
            if command -v timedatectl >/dev/null 2>&1; then
                kv "當前" "$(timedatectl show -p Timezone --value 2>/dev/null || timedatectl | awk '/Time zone/{print $3}')"
                printf '輸入時區（如 Asia/Shanghai）: '
                local tz
                read -r tz || tz=""
                [ -z "$tz" ] && { info "已取消"; return 0; }
                if timedatectl set-timezone "$tz"; then
                    ok "時區已設為 $tz"
                else
                    err "設定失敗"
                fi
            else
                warn "無 timedatectl，請手動 ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"
            fi
            ;;
        2)
            info "推薦公共 DNS：1.1.1.1 / 8.8.8.8 / 223.5.5.5（阿里）"
            printf ' 1) Cloudflare 1.1.1.1 + 1.0.0.1\n'
            printf ' 2) Google 8.8.8.8 + 8.8.4.4\n'
            printf ' 3) 阿里 223.5.5.5 + 223.6.6.6\n'
            printf ' 0) 取消\n請選擇: '
            local d dns1 dns2
            read -r d || d="0"
            case "$d" in
                1) dns1=1.1.1.1; dns2=1.0.0.1 ;;
                2) dns1=8.8.8.8; dns2=8.8.4.4 ;;
                3) dns1=223.5.5.5; dns2=223.6.6.6 ;;
                *) return 0 ;;
            esac
            confirm "寫入 DNS ${dns1} ${dns2}？（可能被 cloud-init 覆蓋）" || return 0
            if [ -d /etc/systemd/resolved.conf.d ]; then
                mkdir -p /etc/systemd/resolved.conf.d
                cat > /etc/systemd/resolved.conf.d/99-oece-dns.conf <<EOF
[Resolve]
DNS=${dns1} ${dns2}
FallbackDNS=1.1.1.1
EOF
                systemctl restart systemd-resolved 2>/dev/null || true
                ok "已寫入 systemd-resolved drop-in"
            else
                cp -a /etc/resolv.conf "/etc/resolv.conf.bak.$(date +%s)" 2>/dev/null || true
                cat > /etc/resolv.conf <<EOF
nameserver ${dns1}
nameserver ${dns2}
EOF
                ok "已寫入 /etc/resolv.conf（已備份）"
            fi
            ;;
        *) return 0 ;;
    esac
}


#=======================================================================
# 全網 Top3 漢化 VPS 腳本入口（第三方 · 僅作啟動器）
# GitHub stars 約：LinuxMirrors > 融合怪 ecs > kejilion（2026 量級）
#=======================================================================
# 合規：我們不內嵌其源碼；下載後 bash -n 再執行；用戶二次確認。
# 第三方腳本可能含我們刻意不做的功能（如 WARP），請自行甄別。

run_remote_script() {
    local name="$1" url="$2" extra_args="${3:-}"
    local dest safe_name
    safe_name=$(printf '%s' "$name" | tr -cd 'a-zA-Z0-9._-')
    dest="${TMP_DIR}/ext-${safe_name}.sh"

    section "啟動第三方腳本：${name}"
    info "來源（HTTPS）: ${url}"
    warn "此為外部開源項目，行為由其作者負責；本工具僅作便捷入口。"
    warn "執行後將進入對方交互界面；退出後返回 oece-x 選單。"
    confirm_danger "確認下載並執行「${name}」？" || { info "已取消"; return 0; }

    safe_download "$url" "$dest" || return 1
    if ! bash -n "$dest" 2>/dev/null; then
        err "遠端腳本語法校驗失敗，拒絕執行。"
        rm -f "$dest"
        return 1
    fi
    chmod +x "$dest"
    info "語法校驗通過，開始執行…"
    printf '\n'
    # 對方腳本可能自帶 set -e；用獨立 bash 進程隔離
    # shellcheck disable=SC2086
    if [ -n "$extra_args" ]; then
        bash "$dest" $extra_args || warn "「${name}」退出碼非 0（可能是用戶取消）"
    else
        bash "$dest" || warn "「${name}」退出碼非 0（可能是用戶取消）"
    fi
    printf '\n'
    ok "已返回 oece-x.sh"
}

module_script_hub() {
    section "精選腳本入口 · 漢化 / 審計 / 測評"
    info "下載後 bash -n 校驗 + 二次確認；第三方行為自負。不含 WARP/代理功能入口。"
    printf '
'
    printf ' %s── 漢化全能 / 換源 ──%s
' "$C_DIM" "$C_RESET"
    printf ' 1) LinuxMirrors 換源 ★
'
    printf ' 2) 融合怪 ecs 測評 ★
'
    printf ' 3) kejilion 工具箱（繁中）
'
    printf ' %s── 差異化審計 / 跑分 ──%s
' "$C_DIM" "$C_RESET"
    printf ' 4) vernu/vps-audit 安全審計 ★  %s無依賴 · SSH/防火牆/内核%s
' "$C_DIM" "$C_RESET"
    printf ' 5) nench 經典 VPS 測評 ★       %sCPU/磁碟/網路 bench 系%s
' "$C_DIM" "$C_RESET"
    printf ' 6) 僅顯示官方一鍵命令
'
    printf ' 0) 返回

請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1) run_remote_script "LinuxMirrors" "https://linuxmirrors.cn/main.sh" ;;
        2) run_remote_script "融合怪-ecs" "https://raw.githubusercontent.com/spiritLHLS/ecs/main/ecs.sh" ;;
        3) run_remote_script "kejilion-tw" "https://raw.githubusercontent.com/kejilion/sh/main/tw/kejilion.sh" ;;
        4) run_remote_script "vps-audit" "https://raw.githubusercontent.com/vernu/vps-audit/main/vps-audit.sh" ;;
        5) run_remote_script "nench" "https://raw.githubusercontent.com/n-st/nench/master/nench.sh" ;;
        6)
            section "官方一鍵命令（複製即用）"
            printf '
%s# LinuxMirrors%s
' "$C_GREEN" "$C_RESET"
            printf 'bash <(curl -sSL https://linuxmirrors.cn/main.sh)
'
            printf '
%s# 融合怪 ecs%s
' "$C_GREEN" "$C_RESET"
            printf 'curl -L https://raw.githubusercontent.com/spiritLHLS/ecs/main/ecs.sh -o ecs.sh && bash ecs.sh
'
            printf '
%s# kejilion 繁中%s
' "$C_GREEN" "$C_RESET"
            printf 'bash <(curl -sL kejilion.sh) tw
'
            printf '
%s# vps-audit 安全審計%s
' "$C_GREEN" "$C_RESET"
            printf 'bash <(curl -fsSL https://raw.githubusercontent.com/vernu/vps-audit/main/vps-audit.sh)
'
            printf '
%s# nench 測評%s
' "$C_GREEN" "$C_RESET"
            printf 'curl -s wget.racing/nench.sh | bash
'
            printf '# 或: bash <(curl -s https://raw.githubusercontent.com/n-st/nench/master/nench.sh)
'
            printf '
  https://github.com/SuperManito/LinuxMirrors
'
            printf '  https://github.com/spiritLHLS/ecs
'
            printf '  https://github.com/kejilion/sh
'
            printf '  https://github.com/vernu/vps-audit
'
            printf '  https://github.com/n-st/nench
'
            ;;
        *) return 0 ;;
    esac
}

#=======================================================================
# Docker 精簡管理
#=======================================================================
uninstall_docker() {
    section "卸載 Docker"
    if ! command -v docker >/dev/null 2>&1; then
        info "未安裝 Docker"
        return 0
    fi
    warn "將停止容器並卸載 Docker 引擎（默認不刪 /var/lib/docker 數據）。"
    confirm_danger "確認卸載 Docker？" || { info "已取消"; return 0; }
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop docker docker.socket containerd 2>/dev/null || true
    fi
    case "$PKG_MGR" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq \
                docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq 2>/dev/null || true
            ;;
        dnf)
            dnf remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
            ;;
        yum)
            yum remove -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
            ;;
    esac
    if confirm "同時刪除 /var/lib/docker 與 /var/lib/containerd？（不可恢復）"; then
        rm -rf /var/lib/docker /var/lib/containerd
        ok "數據目錄已刪"
    fi
    ok "Docker 卸載流程結束"
}

module_docker_hub() {
    section "Docker 環境"
    printf ' 1) 安裝 / 檢測 Docker + Compose ★\n'
    printf ' 2) 全域狀態（版本 · 容器 · 鏡像數）\n'
    printf ' 3) 卸載 Docker\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1) install_docker ;;
        2)
            if ! command -v docker >/dev/null 2>&1; then
                warn "未安裝 Docker"; return 0
            fi
            docker version 2>/dev/null | head -20 || true
            docker compose version 2>/dev/null || true
            printf '\n'
            kv "容器" "$(docker ps -aq 2>/dev/null | wc -l) 個（運行 $(docker ps -q 2>/dev/null | wc -l)）"
            kv "鏡像" "$(docker images -q 2>/dev/null | wc -l) 個"
            kv "磁碟" "$(docker system df 2>/dev/null | head -5 | tr '\n' ' ')"
            ;;
        3) uninstall_docker ;;
        *) return 0 ;;
    esac
}

module_docker_ps() {
    section "容器管理"
    if ! command -v docker >/dev/null 2>&1; then
        warn "請先安裝 Docker（選單 13）"
        return 0
    fi
    docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || docker ps -a
    printf '\n'
    printf ' 1) 啟動  2) 停止  3) 重啟  4) 日誌  5) 刪除容器\n'
    printf ' 0) 返回\n\n請選擇: '
    local c name
    read -r c || c="0"
    case "$c" in
        1|2|3|4|5)
            printf '容器名或 ID: '
            read -r name || name=""
            [ -z "$name" ] && { warn "空"; return 0; }
            ;;
        *) return 0 ;;
    esac
    case "$c" in
        1) docker start "$name" && ok "已啟動 $name" ;;
        2) docker stop "$name" && ok "已停止 $name" ;;
        3) docker restart "$name" && ok "已重啟 $name" ;;
        4) docker logs --tail 100 "$name" ;;
        5)
            confirm_danger "刪除容器 $name（不刪卷）" || return 0
            docker rm -f "$name" && ok "已刪除"
            ;;
    esac
}

module_docker_prune() {
    section "Docker 清理"
    if ! command -v docker >/dev/null 2>&1; then
        warn "未安裝 Docker"; return 0
    fi
    docker system df 2>/dev/null || true
    printf '\n'
    confirm_danger "執行 docker system prune -af（刪未用容器/網路/鏡像，保留卷）？" || { info "已取消"; return 0; }
    docker system prune -af
    ok "清理完成"
    docker system df 2>/dev/null || true
}


#=======================================================================
# 性能跑分（CPU / 磁碟）— 輕量、無第三方付費
#=======================================================================
module_bench() {
    section "性能跑分"
    printf ' 1) CPU 整數運算（純 bash/awk，約 10–30 秒）
'
    printf ' 2) 磁碟順序寫讀（dd 1G，佔用根分區空間）
'
    printf ' 3) 記憶體帶寬粗測（dd to /dev/shm 或 tmpfs）
'
    printf ' 4) 全部（1+2+3）
'
    printf ' 5) nench 經典深度測評 ★  %s第三方 · CPU/IO/網路%s
' "$C_DIM" "$C_RESET"
    printf ' 0) 返回

請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1) bench_cpu ;;
        2) bench_disk ;;
        3) bench_mem ;;
        4) bench_cpu; bench_disk; bench_mem ;;
        5) run_remote_script "nench" "https://raw.githubusercontent.com/n-st/nench/master/nench.sh" ;;
        0) return 0 ;;
        *) warn "無效選項"; return 0 ;;
    esac
    disclaimer
}

bench_mem() {
    info "記憶體寫入粗測（512MB，受 tmpfs 與超售影響）..."
    local target="${TMP_DIR}/mem-bench.bin" wr
    if [ -d /dev/shm ] && [ -w /dev/shm ]; then
        target="/dev/shm/oece-mem-bench.bin"
    fi
    wr=$(dd if=/dev/zero of="$target" bs=1M count=512 conv=fdatasync 2>&1 | awk -F', ' 'END{print $NF}')
    rm -f "$target"
    kv "512MB 寫入" "$wr"
    kv "MemTotal" "$(awk '/^MemTotal:/{printf "%d MB", $2/1024}' /proc/meminfo)"
    kv "MemAvailable" "$(awk '/^MemAvailable:/{printf "%d MB", $2/1024}' /proc/meminfo)"
}

bench_cpu() {
    info "CPU 跑分：計算 1..N 質數篩（單線程，可對比同架構機器）..."
    local start end elapsed score n=200000
    start=$(date +%s%N 2>/dev/null || date +%s)
    # awk 埃氏篩
    score=$(awk -v n="$n" 'BEGIN{
        for(i=2;i<=n;i++) a[i]=1
        for(i=2;i*i<=n;i++) if(a[i]) for(j=i*i;j<=n;j+=i) a[j]=0
        c=0; for(i=2;i<=n;i++) if(a[i]) c++
        print c
    }')
    end=$(date +%s%N 2>/dev/null || date +%s)
    if [ "${#start}" -gt 10 ]; then
        elapsed=$(awk -v s="$start" -v e="$end" 'BEGIN{printf "%.3f", (e-s)/1e9}')
    else
        elapsed=$(( end - start ))
    fi
    kv "篩選上限" "$n"
    kv "質數個數" "$score"
    kv "耗時" "${elapsed} s"
    kv "CPU" "$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null || echo '?')"
    info "耗時越短越好；僅供同架構相對比較，非 Geekbench 分數。"
}

bench_disk() {
    local tmpf="${TMP_DIR}/oece-disk-bench.bin"
    info "磁碟寫入測試：dd 1G 到 ${tmpf} ..."
    local wr rd
    wr=$(dd if=/dev/zero of="$tmpf" bs=1M count=1024 conv=fdatasync 2>&1 | awk -F', ' 'END{print $NF}')
    info "磁碟讀取測試..."
    rd=$(dd if="$tmpf" of=/dev/null bs=1M 2>&1 | awk -F', ' 'END{print $NF}')
    rm -f "$tmpf"
    kv "寫入" "$wr"
    kv "讀取" "$rd"
    info "結果受緩存與虛擬化影響；生產磁碟建議再用 fio 精測。"
}

#=======================================================================
# 流媒體 / AI 可達性 · IP 質量（僅檢測，不含任何代理）
#=======================================================================
http_probe() {
    # 輸出: code|time_total
    local url="$1"
    curl -sS -o /dev/null --max-time 12 -w '%{http_code}|%{time_total}' \
        -A "Mozilla/5.0 (oece-x.sh probe)" \
        -L --connect-timeout 8 "$url" 2>/dev/null || printf '000|0'
}

module_unlock() {
    section "解鎖 / 可達性 · IP 質量檢測"
    info "僅做 HTTPS 探測，不安裝代理、不修改路由（合規檢測）。"
    local ipv4
    ipv4=$(get_public_ip 4)
    [ -z "$ipv4" ] && ipv4="未知"
    kv "公網 IPv4" "$ipv4"
    printf '\n'

    info "探測中…"
    local r code t
    # 基礎出網
    r=$(http_probe "https://www.cloudflare.com/cdn-cgi/trace")
    code="${r%%|*}"; t="${r##*|}"
    kv "Cloudflare" "HTTP ${code} · ${t}s"

    r=$(http_probe "https://www.google.com/generate_204")
    code="${r%%|*}"; t="${r##*|}"
    kv "Google 204" "HTTP ${code} · ${t}s"

    r=$(http_probe "https://www.netflix.com/title/80018499")
    code="${r%%|*}"; t="${r##*|}"
    case "$code" in
        200|301|302) kv "Netflix" "${C_GREEN}可達 (${code})${C_RESET} · ${t}s" ;;
        403|404)     kv "Netflix" "${C_YELLOW}受限/區分 (${code})${C_RESET} · ${t}s" ;;
        000)         kv "Netflix" "${C_RED}超時/不可達${C_RESET}" ;;
        *)           kv "Netflix" "HTTP ${code} · ${t}s" ;;
    esac

    r=$(http_probe "https://www.disneyplus.com/")
    code="${r%%|*}"; t="${r##*|}"
    case "$code" in
        200|301|302) kv "Disney+" "${C_GREEN}可達 (${code})${C_RESET} · ${t}s" ;;
        403)         kv "Disney+" "${C_YELLOW}可能封鎖 (${code})${C_RESET}" ;;
        000)         kv "Disney+" "${C_RED}超時/不可達${C_RESET}" ;;
        *)           kv "Disney+" "HTTP ${code} · ${t}s" ;;
    esac

    # ChatGPT / OpenAI — 檢測 1020 / 403 等（不開 WARP）
    r=$(http_probe "https://chat.openai.com/")
    code="${r%%|*}"; t="${r##*|}"
    case "$code" in
        200|301|302|307|308) kv "ChatGPT Web" "${C_GREEN}可達 (${code})${C_RESET} · ${t}s" ;;
        403) kv "ChatGPT Web" "${C_YELLOW}403 拒絕（地區/風控）${C_RESET}" ;;
        000) kv "ChatGPT Web" "${C_RED}不可達${C_RESET}" ;;
        *)   kv "ChatGPT Web" "HTTP ${code} · ${t}s" ;;
    esac

    r=$(http_probe "https://api.openai.com/v1/models")
    code="${r%%|*}"; t="${r##*|}"
    case "$code" in
        401) kv "OpenAI API" "${C_GREEN}端點可達 (401 需 Key，屬正常)${C_RESET}" ;;
        200) kv "OpenAI API" "${C_GREEN}可達 (${code})${C_RESET}" ;;
        403) kv "OpenAI API" "${C_RED}403 拒絕（常見 CF 1020/地區 ban）${C_RESET}" ;;
        000) kv "OpenAI API" "${C_RED}不可達${C_RESET}" ;;
        *)   kv "OpenAI API" "HTTP ${code} · ${t}s" ;;
    esac

    printf '\n'
    info "IP 質量補充（公開 API，失敗可忽略）…"
    local ipapi
    ipapi=$(curl -fsS --max-time 10 "https://ipinfo.io/${ipv4}/json" 2>/dev/null) || ipapi=""
    if [ -n "$ipapi" ]; then
        local org city country
        org=$(printf '%s' "$ipapi" | sed -n 's/.*"org": *"\([^"]*\)".*/\1/p' | head -1)
        city=$(printf '%s' "$ipapi" | sed -n 's/.*"city": *"\([^"]*\)".*/\1/p' | head -1)
        country=$(printf '%s' "$ipapi" | sed -n 's/.*"country": *"\([^"]*\)".*/\1/p' | head -1)
        kv "ASN/ISP" "${org:-?}"
        kv "位置" "${country:-?} · ${city:-?}"
    fi
    # 常見 DNS 污染粗檢：解析官方域名
    if command -v getent >/dev/null 2>&1; then
        local gip
        gip=$(getent ahostsv4 chat.openai.com 2>/dev/null | awk '{print $1; exit}')
        [ -n "$gip" ] && kv "chat.openai.com →" "$gip"
    fi
    printf '\n'
    warn "檢測≠解鎖保證；播放權與帳號地區另算。本工具不提供 WARP/代理繞過。"
    disclaimer
}

#=======================================================================
# SSH 安全加固（差異化 · 新手剛需）
#=======================================================================
sshd_config_set() {
    local key="$1" val="$2" conf="/etc/ssh/sshd_config"
    if [ ! -f "$conf" ]; then
        err "找不到 $conf"
        return 1
    fi
    # 註釋舊行並追加 drop-in 更安全
    mkdir -p /etc/ssh/sshd_config.d
    local drop="/etc/ssh/sshd_config.d/99-oece-harden.conf"
    if [ ! -f "$drop" ]; then
        printf '# managed by oece-x.sh\n' > "$drop"
    fi
    if grep -qE "^${key}\\b" "$drop" 2>/dev/null; then
        sed -i "s|^${key}.*|${key} ${val}|" "$drop"
    else
        printf '%s %s\n' "$key" "$val" >> "$drop"
    fi
}

sshd_test_reload() {
    if command -v sshd >/dev/null 2>&1; then
        sshd -t 2>/dev/null || { err "sshd -t 失敗，未 reload"; return 1; }
    fi
    if systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null; then
        ok "sshd 已 reload"
    else
        service ssh reload 2>/dev/null || service sshd reload 2>/dev/null || warn "請手動 reload ssh"
    fi
}

module_ssh_harden() {
    section "SSH 安全加固"
    info "對標新手開機清單：改端口 · 禁密碼 root · fail2ban · UFW"
    warn "改端口/防火牆前請確保有控制台（VNC/IPMI），避免把自己鎖在門外。"
    local cur_port
    cur_port=$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')
    [ -z "$cur_port" ] && cur_port=22
    kv "當前 SSH 端口" "$cur_port"
    kv "Root 登錄" "$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2; exit}')"
    kv "密碼認證" "$(sshd -T 2>/dev/null | awk '/^passwordauthentication /{print $2; exit}')"

    printf '\n'
    printf ' 1) 修改 SSH 端口\n'
    printf ' 2) 禁止 root 密碼登錄（保留密鑰）★\n'
    printf ' 3) 安裝並啟用 fail2ban（sshd）★\n'
    printf ' 4) UFW 一鍵：放行 SSH + 80/443，啟用防火牆\n'
    printf ' 5) 一鍵套用 2+3+4（端口保持 %s）★\n' "$cur_port"
    printf ' 6) 安全審計快照（只讀）\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1)
            printf '新端口 [1024-65535，當前 %s]: ' "$cur_port"
            local np
            read -r np || np=""
            [ -z "$np" ] && np="$cur_port"
            case "$np" in *[!0-9]*|"") err "無效端口"; return 1 ;; esac
            if [ "$np" -lt 1 ] || [ "$np" -gt 65535 ]; then err "範圍錯誤"; return 1; fi
            confirm_danger "將 SSH 端口改為 ${np}（請先在雲安全組放行）" || return 0
            sshd_config_set Port "$np"
            sshd_test_reload || return 1
            if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi active; then
                ufw allow "${np}/tcp" comment 'oece-ssh' 2>/dev/null || true
                ok "已嘗試 ufw allow ${np}/tcp"
            fi
            warn "請用新端口重連：ssh -p ${np} user@ip"
            ;;
        2)
            confirm_danger "將 PermitRootLogin prohibit-password 且 PasswordAuthentication no（需已配公鑰！）" || return 0
            sshd_config_set PermitRootLogin prohibit-password
            sshd_config_set PasswordAuthentication no
            sshd_config_set KbdInteractiveAuthentication no
            sshd_config_set ChallengeResponseAuthentication no
            sshd_test_reload
            ok "已禁密碼登錄（root 僅密鑰）"
            ;;
        3)
            if ! command -v fail2ban-client >/dev/null 2>&1; then
                info "安裝 fail2ban…"
                pkg_install fail2ban || { err "安裝失敗"; return 1; }
            fi
            mkdir -p /etc/fail2ban/jail.d
            cat > /etc/fail2ban/jail.d/sshd-oece.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
backend = auto
maxretry = 5
findtime = 10m
bantime = 1h
EOF
            # RHEL 日誌路徑
            if [ -f /var/log/secure ]; then
                sed -i 's|/var/log/auth.log|/var/log/secure|' /etc/fail2ban/jail.d/sshd-oece.local
            fi
            systemctl enable --now fail2ban 2>/dev/null || true
            systemctl restart fail2ban 2>/dev/null || true
            fail2ban-client status sshd 2>/dev/null || fail2ban-client status 2>/dev/null || true
            ok "fail2ban sshd 已配置"
            ;;
        4)
            if ! command -v ufw >/dev/null 2>&1; then
                confirm "安裝 ufw？" || return 0
                pkg_install ufw || { err "安裝失敗"; return 1; }
            fi
            confirm_danger "UFW 將 default deny incoming，放行 ${cur_port}/tcp 與 80,443" || return 0
            ufw --force reset >/dev/null 2>&1 || true
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow "${cur_port}/tcp" comment 'SSH'
            ufw allow 80/tcp comment 'HTTP'
            ufw allow 443/tcp comment 'HTTPS'
            ufw --force enable
            ufw status verbose || true
            ok "UFW 已啟用"
            warn "Docker 默認可能繞過 UFW（發布 0.0.0.0 端口時）；重要服務請綁 127.0.0.1 或配 ip-tables。"
            ;;
        5)
            confirm_danger "一鍵：禁 root 密碼 + fail2ban + UFW（SSH 端口保持 ${cur_port}）" || return 0
            sshd_config_set PermitRootLogin prohibit-password
            sshd_config_set PasswordAuthentication no
            sshd_test_reload || true
            # fail2ban
            command -v fail2ban-client >/dev/null 2>&1 || pkg_install fail2ban || true
            mkdir -p /etc/fail2ban/jail.d
            cat > /etc/fail2ban/jail.d/sshd-oece.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h
EOF
            [ -f /var/log/secure ] && sed -i 's|/var/log/auth.log|/var/log/secure|' /etc/fail2ban/jail.d/sshd-oece.local
            systemctl enable --now fail2ban 2>/dev/null || true
            systemctl restart fail2ban 2>/dev/null || true
            # ufw
            command -v ufw >/dev/null 2>&1 || pkg_install ufw || true
            if command -v ufw >/dev/null 2>&1; then
                ufw default deny incoming
                ufw default allow outgoing
                ufw allow "${cur_port}/tcp" comment 'SSH'
                ufw allow 80/tcp
                ufw allow 443/tcp
                ufw --force enable
            fi
            ok "一鍵加固完成。請用密鑰驗證 SSH 仍可登錄。"
            ;;
        6)
            section "安全審計快照（只讀）"
            kv "SSH 端口" "$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
            kv "PermitRootLogin" "$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2; exit}')"
            kv "PasswordAuth" "$(sshd -T 2>/dev/null | awk '/^passwordauthentication /{print $2; exit}')"
            kv "PubkeyAuth" "$(sshd -T 2>/dev/null | awk '/^pubkeyauthentication /{print $2; exit}')"
            if command -v fail2ban-client >/dev/null 2>&1; then
                kv "fail2ban" "已安裝"
                fail2ban-client status sshd 2>/dev/null | head -8 || true
            else
                kv "fail2ban" "未安裝"
            fi
            if command -v ufw >/dev/null 2>&1; then
                kv "UFW" "$(ufw status 2>/dev/null | head -1)"
            else
                kv "UFW" "未安裝"
            fi
            # 監聽端口
            info "監聽中的 TCP 端口（前 15）:"
            if command -v ss >/dev/null 2>&1; then
                ss -ltnp 2>/dev/null | head -16
            fi
            # 空密碼/可登錄用戶粗檢
            info "UID=0 帳戶:"
            awk -F: '$3==0{print "  "$1}' /etc/passwd 2>/dev/null
            ;;
        7)
            run_remote_script "vps-audit" "https://raw.githubusercontent.com/vernu/vps-audit/main/vps-audit.sh"
            ;;
        *) return 0 ;;
    esac
}

#=======================================================================
# nginx 反代 + SSL 輔助
#=======================================================================
module_nginx_proxy() {
    section "一鍵 nginx 反向代理"
    info "將寫入獨立 conf，默認不覆蓋現有站點；套用前 nginx -t。"
    if ! command -v nginx >/dev/null 2>&1; then
        warn "未檢測到 nginx"
        confirm "使用包管理器安裝 nginx？" || return 0
        pkg_install nginx
        systemctl enable --now nginx 2>/dev/null || true
    fi

    local domain upstream confdir conf
    printf '域名（server_name，如 app.example.com）: '
    read -r domain || domain=""
    [ -z "$domain" ] && { err "域名不能為空"; return 1; }
    printf '上游（如 127.0.0.1:8080）: '
    read -r upstream || upstream=""
    [ -z "$upstream" ] && { err "上游不能為空"; return 1; }

    if [ -d /etc/nginx/sites-available ]; then
        confdir=/etc/nginx/sites-available
    elif [ -d /etc/nginx/conf.d ]; then
        confdir=/etc/nginx/conf.d
    else
        err "找不到 nginx conf 目錄"
        return 1
    fi

    conf="${confdir}/oece-proxy-${domain}.conf"
    # 安全：拒絕寫入已知生產站名除非用戶 force
    case "$domain" in
        oece-x.com|www.oece-x.com|api.oece-x.com)
            warn "偵測到本項目生產域名 ${domain}"
            confirm_danger "仍要為該域名生成 conf？（可能影響現網）" || return 0
            ;;
    esac

    cat > "$conf" <<EOF
# generated by oece-x.sh v${SCRIPT_VERSION}
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};

    location / {
        proxy_pass http://${upstream};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    ok "已寫入 $conf"

    if [ -d /etc/nginx/sites-enabled ]; then
        ln -sfn "$conf" "/etc/nginx/sites-enabled/oece-proxy-${domain}.conf"
    fi

    if nginx -t 2>&1; then
        systemctl reload nginx 2>/dev/null || nginx -s reload 2>/dev/null || true
        ok "nginx 配置測試通過並已 reload"
        kv "HTTP" "http://${domain}/ → ${upstream}"
        info "請先將域名 A 記錄指向本機公網 IP：$(get_public_ip 4)"
        info "HTTPS 請用選單 14（certbot）"
    else
        err "nginx -t 失敗，已保留 conf 請手動檢查：$conf"
    fi
}

module_ssl_helper() {
    section "SSL / Let's Encrypt 輔助"
    info "需要：域名已解析到本機 + 80 端口可從公網訪問。"
    if ! command -v certbot >/dev/null 2>&1; then
        confirm "安裝 certbot？" || return 0
        if [ "$PKG_MGR" = "apt" ]; then
            pkg_install certbot python3-certbot-nginx 2>/dev/null || pkg_install certbot
        else
            pkg_install certbot 2>/dev/null || warn "請手動安裝 certbot"
        fi
    fi
    if ! command -v certbot >/dev/null 2>&1; then
        err "certbot 不可用"
        return 1
    fi
    printf '域名: '
    local domain email
    read -r domain || domain=""
    [ -z "$domain" ] && return 0
    printf "郵箱（Let's Encrypt 通知）: "
    read -r email || email=""
    [ -z "$email" ] && email="admin@${domain}"

    printf ' 1) nginx 插件（推薦，已有反代 conf）\n'
    printf ' 2) standalone（需暫時停 80 端口服務）\n'
    printf ' 0) 取消\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1)
            confirm "對 ${domain} 執行 certbot --nginx？" || return 0
            certbot --nginx -d "$domain" --email "$email" --agree-tos --non-interactive --redirect || \
                certbot --nginx -d "$domain" --email "$email" --agree-tos --redirect
            ;;
        2)
            confirm_danger "standalone 模式可能短暫佔用 80 端口" || return 0
            certbot certonly --standalone -d "$domain" --email "$email" --agree-tos --non-interactive || \
                certbot certonly --standalone -d "$domain" --email "$email" --agree-tos
            info "證書通常在 /etc/letsencrypt/live/${domain}/ ，請自行掛到 nginx"
            ;;
        *) return 0 ;;
    esac
}

#=======================================================================
# 快捷命令 x
#=======================================================================
module_shortcut() {
    section "安裝快捷命令"
    info "將建立 /usr/local/bin/x → 重新下載並執行最新 oece-x.sh（或本地副本）"
    printf ' 1) 安裝 x（curl 線上最新）\n'
    printf ' 2) 安裝 x（固定本機腳本路徑）\n'
    printf ' 3) 移除 /usr/local/bin/x\n'
    printf ' 0) 返回\n\n請選擇: '
    local c
    read -r c || c="0"
    case "$c" in
        1)
            cat > /usr/local/bin/x <<'EOF'
#!/usr/bin/env bash
exec bash <(curl -fsSL https://oece-x.com/x) "$@"
EOF
            chmod +x /usr/local/bin/x
            ok "已安裝：輸入 x 即可啟動（走 oece-x.com/x）"
            ;;
        2)
            local self
            self="$(readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null || realpath "${BASH_SOURCE[0]:-$0}" 2>/dev/null || echo "")"
            if [ -z "$self" ] || [ ! -f "$self" ]; then
                err "無法解析腳本路徑（管道執行時請選 1）"
                return 1
            fi
            cat > /usr/local/bin/x <<EOF
#!/usr/bin/env bash
exec bash $(printf '%q' "$self") "\$@"
EOF
            chmod +x /usr/local/bin/x
            ok "已安裝：x → $self"
            ;;
        3)
            rm -f /usr/local/bin/x
            ok "已移除"
            ;;
        *) return 0 ;;
    esac
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
        # 備用短域名
        if ! curl "${CURL_OPTS[@]}" --max-time 15 -o "$remote_script" "https://oece-x.com/x" 2>/dev/null; then
            err "無法獲取遠端版本（倉庫未發佈或網路異常）。"
            return 0
        fi
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
        info "請重新執行： bash <(curl -sL oece-x.com/x)"
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
    printf '  · %s（NextTrace / Ookla CLI / Demo 頁面等）\n' "$OECE_HOME"
    if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$DEMO_CONTAINER"; then
        printf '  · Demo 容器 %s\n' "$DEMO_CONTAINER"
    fi
    if [ -L /usr/local/bin/x ] || [ -f /usr/local/bin/x ]; then
        printf '  · 快捷命令 /usr/local/bin/x（可選）\n'
    fi
    printf '  %s（不會動 Docker 業務容器、nginx 站點、系統包）%s\n\n' "$C_DIM" "$C_RESET"

    confirm_danger "確認卸載 oece-x.sh 相關檔案？" || { info "已取消"; return 0; }

    if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$DEMO_CONTAINER"; then
        docker rm -f "$DEMO_CONTAINER" >/dev/null 2>&1 || true
        ok "Demo 容器已移除"
    fi
    rm -rf "$OECE_HOME"
    ok "已刪除 ${OECE_HOME}"

    if [ -e /usr/local/bin/x ] && confirm "同時移除快捷命令 /usr/local/bin/x？"; then
        rm -f /usr/local/bin/x
        ok "已移除 x"
    fi

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
print_banner_static() {
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
    printf '%s  oece-x.sh v%s · 體檢 · 加固 · 運維精選%s\n' "$C_DIM" "$SCRIPT_VERSION" "$C_RESET"
    printf '%s  YouTube @oece-x · oece-x.com · bash <(curl -sL oece-x.com/x)%s\n' "$C_DIM" "$C_RESET"
}

main_menu() {
    while true; do
        printf '
'
        print_banner_static
        divider
        menu_group "體檢與網路"
        menu_item 1 "系統體檢" "CPU/記憶體/虛擬化/BBR/IP" 1
        menu_item 2 "性能跑分" "CPU·磁碟·記憶體·nench" 1
        menu_item 3 "解鎖/IP 質量" "Netflix·ChatGPT 可達性" 1
        menu_item 4 "網路測速" "Cloudflare · Ookla"
        menu_item 5 "回程路由" "三網 NextTrace"
        menu_group "系統運維"
        menu_item 6 "系統更新" "apt/dnf/yum"
        menu_item 7 "系統清理" "緩存 · journal"
        menu_item 8 "BBR 加速" "開機第一件事" 1
        menu_item 9 "Swap" "小內存剛需" 1
        menu_item 10 "時區/DNS"
        menu_item 11 "基礎工具" "curl vim htop fail2ban"
        menu_item 12 "SSH 安全加固" "端口·fail2ban·UFW·vps-audit" 1
        menu_group "Docker"
        menu_item 13 "Docker 環境" "安裝/卸載/狀態" 1
        menu_item 14 "容器管理"
        menu_item 15 "鏡像清理" "prune"
        menu_group "站點輕量"
        menu_item 16 "nginx 反代" "域名 → 上游" 1
        menu_item 17 "SSL 證書" "certbot 輔助"
        menu_item 18 "部署 Demo" "驗證頁"
        menu_group "工具箱"
        menu_item 19 "精選腳本入口" "審計·nench·融合怪·換源" 1
        menu_item 20 "檢查更新"
        menu_item 21 "快捷命令 x"
        menu_item 22 "卸載"
        menu_item 0 "退出"
        divider
        printf '請輸入選項: '

        local choice
        read -r choice || { printf '
'; break; }
        case "$choice" in
            1)  module_sysinfo;      pause ;;
            2)  module_bench;        pause ;;
            3)  module_unlock;       pause ;;
            4)  module_speedtest;    pause ;;
            5)  module_route;        pause ;;
            6)  module_sys_update;   pause ;;
            7)  module_sys_clean;    pause ;;
            8)  module_bbr;          pause ;;
            9)  module_swap;         pause ;;
            10) module_tz_dns;       pause ;;
            11) install_common_tools; pause ;;
            12) module_ssh_harden;   pause ;;
            13) module_docker_hub;   pause ;;
            14) module_docker_ps;    pause ;;
            15) module_docker_prune; pause ;;
            16) module_nginx_proxy;  pause ;;
            17) module_ssl_helper;   pause ;;
            18) module_demo;         pause ;;
            19) module_script_hub;   pause ;;
            20) check_update;        pause ;;
            21) module_shortcut;     pause ;;
            22) uninstall_all ;;
            0)  info "再見。"; break ;;
            *)  warn "無效選項：${choice}" ;;
        esac
    done
}

usage() {
    cat <<EOF
oece-x.sh v${SCRIPT_VERSION} — VPS 體檢與運維精選工具箱

用法:
  bash oece-x.sh            進入互動選單（TTY 播放開場動畫）
  bash oece-x.sh --version  顯示版本
  bash oece-x.sh --help     顯示本說明
  OECE_NO_ANIM=1 bash oece-x.sh   跳過動畫
  OECE_FAST=1 bash oece-x.sh      同上

一鍵執行:
  bash <(curl -sL oece-x.com/x)

本工具僅供測試與合法運維；不含任何繞過網路封鎖之功能。
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

    intro_animation
    main_menu
}

main "$@"
