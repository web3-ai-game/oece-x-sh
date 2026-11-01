#!/usr/bin/env bash
#=======================================================================
#  oece-x.sh — 3 分鐘 VPS 體檢與基準工具箱
#  oece-x.sh — 3-minute VPS audit and benchmark toolkit
#
#  先看這台機器值不值得用。加固在姊妹專案，本檔不下載它。
#  Inspect first. Hardening lives in the sister repo. This file does not fetch it.
#
#  Project : https://github.com/web3-ai-game/oece-x-sh
#  Sister  : https://github.com/web3-ai-game/oece-x-blue-sh
#  License : MIT
#
#  不含代理或繞過網路封鎖的功能。沒有遙測，沒有隱藏選單。
#=======================================================================

SCRIPT_VERSION="2.0.0"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/web3-ai-game/oece-x-sh/main/oece-x.sh"
BLUE_REPO_URL="https://github.com/web3-ai-game/oece-x-blue-sh"
BLUE_RAW_URL="https://raw.githubusercontent.com/web3-ai-game/oece-x-blue-sh/main/oece-x-blue.sh"

set -Eeuo pipefail

TMP_DIR=""
OS_PRETTY=""
ARCH=""
UI_LANG="zh-Hant"
AUDIT_JSON=0
OECE_LANG_FILE="/etc/oece-x/lang"
CURL_OPTS=(-fsSL --retry 2 --retry-delay 1)

C_RESET=""
C_BOLD=""
C_DIM=""
C_RED=""
C_GREEN=""
C_YELLOW=""
C_BLUE=""
C_CYAN=""

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

#-----------------------------------------------------------------------
# 語言
#   優先序：--lang / OECE_LANG > /etc/oece-x/lang > LANG。
#   zh_CN、zh_SG 與任何 zh* 一律落到繁體。en* 落到 English。
#-----------------------------------------------------------------------
normalize_lang() {
    local raw="$1" low
    low="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    case "$low" in
        en|en-*|english) printf 'en' ;;
        zh-hant|zh_hant|zh-tw|zh_tw|zh-hk|zh_hk|zh-mo|zh_mo|zh|zh-*|zh_*|chinese|traditional)
            printf 'zh-Hant' ;;
        *) printf '' ;;
    esac
}

detect_lang_auto() {
    local src="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" hit
    hit="$(normalize_lang "$src")"
    if [ -n "$hit" ]; then
        printf '%s' "$hit"
        return 0
    fi
    printf 'zh-Hant'
}

resolve_lang() {
    local hit=""
    if [ -n "${OECE_LANG:-}" ]; then
        hit="$(normalize_lang "$OECE_LANG")"
        if [ -n "$hit" ]; then
            printf '%s' "$hit"
            return 0
        fi
    fi
    if [ -r "$OECE_LANG_FILE" ]; then
        hit="$(normalize_lang "$(head -1 "$OECE_LANG_FILE" 2>/dev/null || true)")"
        if [ -n "$hit" ]; then
            printf '%s' "$hit"
            return 0
        fi
    fi
    detect_lang_auto
}

persist_lang() {
    local lang="$1" dir
    [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ] || return 0
    dir="$(dirname "$OECE_LANG_FILE")"
    mkdir -p "$dir" 2>/dev/null || return 0
    printf '%s\n' "$lang" > "$OECE_LANG_FILE" 2>/dev/null || return 0
    chmod 644 "$OECE_LANG_FILE" 2>/dev/null || true
}

prompt_lang_if_needed() {
    local reply=""
    [ -t 0 ] && [ -t 1 ] || return 0
    [ -n "${OECE_LANG:-}" ] && return 0
    [ -s "$OECE_LANG_FILE" ] && return 0
    printf '\n語言 / Language\n'
    printf '  1) 繁體中文（預設 / default）\n'
    printf '  2) English\n'
    printf '10 秒未輸入則使用繁體中文。請選擇 [1]: '
    if read -r -t 10 reply; then
        :
    else
        printf '\n'
        reply=""
    fi
    case "$reply" in
        2|en|EN|english|English) UI_LANG="en" ;;
        *) UI_LANG="zh-Hant" ;;
    esac
    persist_lang "$UI_LANG"
}

apply_lang_arg() {
    local hit
    hit="$(normalize_lang "$1")"
    if [ -z "$hit" ]; then
        printf 'unknown language: %s (use zh-Hant or en)\n' "$1" >&2
        exit 1
    fi
    UI_LANG="$hit"
    OECE_LANG="$hit"
    export OECE_LANG
}

t() {
    local key="$1"
    if [ "${UI_LANG:-zh-Hant}" = "en" ]; then
        case "$key" in
            info.tag) printf '[info]' ;;
            ok.tag) printf '[ok]' ;;
            warn.tag) printf '[warn]' ;;
            err.tag) printf '[error]' ;;
            pause) printf 'Press Enter to return...' ;;
            confirm.ask) printf '  Proceed? [y/N] ' ;;
            confirm.yes) printf '  Type yes to confirm (anything else cancels): ' ;;
            err.need_root) printf 'Live checks need Linux root. Try: bash oece-x.sh --demo' ;;
            err.linux_only) printf 'Live checks need Linux. macOS can run --demo.' ;;
            menu.ask) printf 'Choice: ' ;;
            menu.exit) printf 'Goodbye. Read the report before you harden.' ;;
            menu.invalid) printf 'Unknown choice: %%s' ;;
            banner.tagline) printf 'inspect · benchmark · baseline' ;;
            group.look) printf 'Look' ;;
            group.measure) printf 'Measure' ;;
            group.next) printf 'Next' ;;
            menu.1) printf 'System snapshot' ;;
            menu.1h) printf 'CPU, memory, disk, BBR, public address' ;;
            menu.2) printf 'Network speed' ;;
            menu.2h) printf 'Cloudflare handshake, optional Ookla' ;;
            menu.3) printf 'Return path' ;;
            menu.3h) printf 'Trace public DNS targets, export Markdown' ;;
            menu.4) printf 'Security baseline' ;;
            menu.4h) printf 'SSH, firewall, fail2ban, updates, Docker socket' ;;
            menu.5) printf 'Local benchmark' ;;
            menu.5h) printf 'CPU, sequential disk, memory copy' ;;
            menu.6) printf 'BBR' ;;
            menu.6h) printf 'Show status, or enable fq + bbr' ;;
            menu.7) printf 'Docker status' ;;
            menu.7h) printf 'Read-only version, containers, images' ;;
            menu.8) printf 'Sister blue-team panel' ;;
            menu.8h) printf 'Print the GitHub URL. Do not download.' ;;
            menu.9) printf 'Check for updates' ;;
            menu.9h) printf 'Compare SCRIPT_VERSION. Do not overwrite.' ;;
            menu.0) printf 'Exit' ;;
            *) printf '%s' "$key" ;;
        esac
        return 0
    fi
    case "$key" in
        info.tag) printf '[資訊]' ;;
        ok.tag) printf '[完成]' ;;
        warn.tag) printf '[注意]' ;;
        err.tag) printf '[錯誤]' ;;
        pause) printf '按 Enter 返回...' ;;
        confirm.ask) printf '  繼續？[y/N] ' ;;
        confirm.yes) printf '  輸入 yes 確認（其他任何輸入都取消）: ' ;;
        err.need_root) printf '正式體檢需要 Linux root。可改跑：bash oece-x.sh --demo' ;;
        err.linux_only) printf '正式體檢只在 Linux。macOS 請用 --demo。' ;;
        menu.ask) printf '請選擇: ' ;;
        menu.exit) printf '再見。先讀報告，再決定要不要加固。' ;;
        menu.invalid) printf '未知選項：%%s' ;;
        banner.tagline) printf '體檢 · 基準 · 安全基線' ;;
        group.look) printf '觀察' ;;
        group.measure) printf '測量' ;;
        group.next) printf '下一步' ;;
        menu.1) printf '系統體檢' ;;
        menu.1h) printf 'CPU、記憶體、磁碟、BBR、公網位址' ;;
        menu.2) printf '網路測速' ;;
        menu.2h) printf 'Cloudflare 握手，可選 Ookla' ;;
        menu.3) printf '回程追蹤' ;;
        menu.3h) printf '追蹤公開 DNS，可匯出 Markdown' ;;
        menu.4) printf '安全基線' ;;
        menu.4h) printf 'SSH、防火牆、fail2ban、更新、Docker socket' ;;
        menu.5) printf '本機基準' ;;
        menu.5h) printf 'CPU、順序磁碟、記憶體複製' ;;
        menu.6) printf 'BBR' ;;
        menu.6h) printf '查看狀態，或啟用 fq + bbr' ;;
        menu.7) printf 'Docker 狀態' ;;
        menu.7h) printf '只讀版本、容器、鏡像' ;;
        menu.8) printf '姊妹藍隊面板' ;;
        menu.8h) printf '只印 GitHub URL，不下載' ;;
        menu.9) printf '檢查更新' ;;
        menu.9h) printf '只比 SCRIPT_VERSION，不覆蓋本機檔' ;;
        menu.0) printf '離開' ;;
        *) printf '%s' "$key" ;;
    esac
}

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_CYAN=$'\033[0;36m'
fi

info()  { printf '%s%s%s %s\n' "$C_CYAN"   "$(t info.tag)" "$C_RESET" "$*"; }
ok()    { printf '%s%s%s %s\n' "$C_GREEN"  "$(t ok.tag)"   "$C_RESET" "$*"; }
warn()  { printf '%s%s%s %s\n' "$C_YELLOW" "$(t warn.tag)" "$C_RESET" "$*"; }
err()   { printf '%s%s%s %s\n' "$C_RED"    "$(t err.tag)"  "$C_RESET" "$*" >&2; }

divider() {
    printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────" "$C_RESET"
}

section() {
    printf '\n%s%s◆ %s%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_RESET"
    divider
}

display_width() {
    local s="$1" total ascii nonascii
    total=$(printf '%s' "$s" | wc -c)
    ascii=$(printf '%s' "$s" | tr -cd '\1-\177' | wc -c)
    nonascii=$(( total - ascii ))
    printf '%d' $(( ascii + nonascii * 2 / 3 ))
}

pad_to() {
    local s="$1" target="$2" w pad
    w=$(display_width "$s")
    pad=$(( target - w ))
    [ "$pad" -lt 1 ] && pad=1
    printf '%s%*s' "$s" "$pad" ""
}

kv() {
    local key="$1" val="$2" w pad
    w=$(display_width "$key")
    pad=$(( 16 - w ))
    [ "$pad" -lt 1 ] && pad=1
    printf ' %s%s%s%*s%s\n' "$C_CYAN" "$key" "$C_RESET" "$pad" "" "$val"
}

box_top() {
    printf '%s%s╔══════════════════════════════════════════════════════════════╗%s\n' "$C_BOLD" "$C_BLUE" "$C_RESET"
}

box_mid() {
    printf '%s%s║%s%s║%s\n' "$C_BOLD" "$C_BLUE" "$(pad_to "  $1" 62)" "$C_BOLD" "$C_RESET"
}

box_bot() {
    printf '%s%s╚══════════════════════════════════════════════════════════════╝%s\n' "$C_BOLD" "$C_BLUE" "$C_RESET"
}

menu_group() {
    printf '%s%s── %s ──%s\n' "$C_DIM" "$C_BOLD" "$*" "$C_RESET"
}

menu_item() {
    local num="$1" label="$2" hint="${3:-}" star="${4:-}" star_s=""
    [ "$star" = "1" ] && star_s=" ${C_YELLOW}★${C_RESET}"
    printf ' %s%2s)%s  %s%s%s%s\n' \
        "$C_CYAN" "$num" "$C_RESET" "$C_BOLD" "$label" "$C_RESET" "$star_s"
    if [ -n "$hint" ]; then
        printf '       %s%s%s\n' "$C_DIM" "$hint" "$C_RESET"
    fi
}

pause() {
    [ -t 0 ] && [ -t 1 ] || return 0
    printf '%s' "$(t pause)"
    read -r _ || true
    printf '\n'
}

confirm() {
    local reply=""
    [ -t 0 ] && [ -t 1 ] || return 1
    printf '%s' "$(t confirm.ask)"
    read -r reply || reply=""
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

confirm_danger() {
    local reply=""
    warn "$1"
    [ -t 0 ] && [ -t 1 ] || { err "非互動環境拒絕變更。"; return 1; }
    printf '%s' "$(t confirm.yes)"
    read -r reply || reply=""
    [ "$reply" = "yes" ]
}

is_linux() {
    [ "$(uname -s 2>/dev/null || echo unknown)" = "Linux" ]
}

is_root() {
    [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]
}

can_run_live() {
    is_linux && is_root
}

require_live() {
    if ! is_linux; then
        err "$(t err.linux_only)"
        return 1
    fi
    if ! is_root; then
        err "$(t err.need_root)"
        return 1
    fi
    detect_os
}

detect_os() {
    OS_PRETTY="$(uname -s) $(uname -r)"
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_PRETTY="${PRETTY_NAME:-$OS_PRETTY}"
    fi
    ARCH="$(uname -m)"
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/ }"
    s="${s//$'\r'/ }"
    printf '%s' "$s"
}

#-----------------------------------------------------------------------
# --demo · 免 root 沙盒。主機固定為 DO SGP1。
#   初篩 57/100、18/32 與姊妹面板同一口徑。本檔不下載姊妹腳本。
#-----------------------------------------------------------------------
demo_box() {
    local title
    if [ "$UI_LANG" = "en" ]; then
        title="OECE-X · DO SGP1 audit          DigitalOcean · Singapore"
    else
        title="OECE-X · DO SGP1 全景體檢       DigitalOcean · Singapore"
    fi
    box_top
    box_mid "$title"
    box_bot
}

demo_report_text() {
    demo_box
    if [ "$UI_LANG" = "en" ]; then
        printf '%sread-only sandbox%s  same 57 / 75 / 83 contract as oece-x-blue.sh\n' "$C_DIM" "$C_RESET"
        divider
        section "System & Hardware"
        kv "Host" "DO SGP1 (DigitalOcean · Singapore)"
        kv "vCPU" "DO-Regular Intel 2 vCPU @ 2000 MHz"
        kv "Memory" "812 MB / 2048 MB"
        kv "Swap" "0 MB"
        kv "Disk (/)" "11G / 48G (23%)"
        kv "Virt" "kvm"
        kv "Kernel" "6.8.0-demo"
        kv "BBR" "on  (fq + bbr)"
        section "Disk & CPU micro-benchmark"
        kv "Disk 4K read" "41 MB/s"
        kv "Disk 4K write" "38 MB/s"
        kv "Disk seq read" "286 MB/s"
        kv "Disk seq write" "241 MB/s"
        kv "CPU sha256" "1.84 s / 64 MiB single core"
        section "Network & return path"
        kv "CF handshake" "p50 18 ms   p95 27 ms   n=5"
        kv "Public DNS" "198.51.100.1   4 hops"
        kv "CF edge" "203.0.113.10   6 hops"
        kv "Doc hop" "192.0.2.1   unroutable sample"
        info "Addresses are RFC 5737 documentation ranges, not live hosts."
        section "Docker & runtime"
        kv "Engine" "24.0.9"
        kv "Containers" "2 running / 3 total"
        kv "docker.sock" "mode 660  root:docker  local only"
        section "Security baseline hand-off"
        kv "Initial" "57/100  Weak  18/32 checks"
        kv "Next" "oece-x-blue.sh  →  75 / 83"
        printf '  %s\n' "$BLUE_REPO_URL"
        return 0
    fi
    printf '%s只讀沙盒%s  與 oece-x-blue.sh 共用 57 / 75 / 83 口徑\n' "$C_DIM" "$C_RESET"
    divider
    section "系統與硬體"
    kv "主機" "DO SGP1 (DigitalOcean · Singapore)"
    kv "vCPU" "DO-Regular Intel 2 vCPU @ 2000 MHz"
    kv "記憶體" "812 MB / 2048 MB"
    kv "Swap" "0 MB"
    kv "磁碟 (/)" "11G / 48G（已用 23%）"
    kv "虛擬化" "kvm"
    kv "內核" "6.8.0-demo"
    kv "BBR" "已啟用（fq + bbr）"
    section "磁碟與 CPU 微基準"
    kv "磁碟 4K 讀" "41 MB/s"
    kv "磁碟 4K 寫" "38 MB/s"
    kv "磁碟順序讀" "286 MB/s"
    kv "磁碟順序寫" "241 MB/s"
    kv "CPU sha256" "1.84 秒 / 64 MiB 單核"
    section "網路與回程"
    kv "CF 握手" "p50 18 ms   p95 27 ms   n=5"
    kv "公開 DNS" "198.51.100.1   4 跳"
    kv "CF 邊緣" "203.0.113.10   6 跳"
    kv "文件位址" "192.0.2.1   樣例，不可路由"
    info "位址均為 RFC 5737 文件段，不是真實主機。"
    section "Docker 與執行環境"
    kv "引擎" "24.0.9"
    kv "容器" "2 運行 / 共 3"
    kv "docker.sock" "mode 660  root:docker  只聽本機"
    section "安全基線移交"
    kv "初篩" "57/100  偏弱  18/32 項"
    kv "下一步" "oece-x-blue.sh  →  75 / 83"
    printf '  %s\n' "$BLUE_REPO_URL"
}

demo_emit_json() {
    cat <<EOF
{
  "tool": "oece-x.sh",
  "version": "${SCRIPT_VERSION}",
  "mode": "demo",
  "host": "DO SGP1",
  "region": "DigitalOcean · Singapore",
  "specs": {
    "vcpu": "DO-Regular Intel 2 vCPU @ 2000 MHz",
    "cpu_cores": 2,
    "memory_mb": 2048,
    "memory_used_mb": 812,
    "swap_mb": 0,
    "disk": "11G / 48G (23%)",
    "virt": "kvm",
    "kernel": "6.8.0-demo"
  },
  "benchmark": {
    "disk_4k_read_mb_s": 41,
    "disk_4k_write_mb_s": 38,
    "disk_seq_read_mb_s": 286,
    "disk_seq_write_mb_s": 241,
    "cpu_sha256_64mib_s": 1.84
  },
  "network": {
    "handshake_p50_ms": 18,
    "handshake_p95_ms": 27,
    "handshake_samples": 5,
    "hops": [
      {"name": "documentation", "ip": "192.0.2.1", "hops": null},
      {"name": "public-dns", "ip": "198.51.100.1", "hops": 4},
      {"name": "cloudflare-edge", "ip": "203.0.113.10", "hops": 6}
    ]
  },
  "bbr": {"enabled": true, "qdisc": "fq", "congestion": "bbr"},
  "docker": {
    "engine": "24.0.9",
    "running": 2,
    "total": 3,
    "socket_mode": "660",
    "socket_scope": "local"
  },
  "security_handoff": {
    "initial_score": 57,
    "grade": "weak",
    "passed": 18,
    "checks": 32,
    "target_score": 83,
    "ladder": [57, 75, 83],
    "sister_repo": "oece-x-blue-sh",
    "sister_url": "${BLUE_REPO_URL}"
  }
}
EOF
}

module_demo() {
    local choice=""
    if [ "$AUDIT_JSON" -eq 1 ]; then
        demo_emit_json
        return 0
    fi
    if [ -t 0 ] && [ -t 1 ]; then
        while true; do
            printf '\n'
            demo_report_text
            divider
            menu_group "$(t group.look)"
            if [ "$UI_LANG" = "en" ]; then
                menu_item 1 "Print the report" "hardware, bench, route, hand-off" 1
                menu_item 2 "Print JSON" "same contract as --demo --audit --json"
                menu_item 3 "Sister panel URL" "print only, do not download" 1
                menu_item 0 "Leave the sandbox"
            else
                menu_item 1 "再印一次報告" "硬體、基準、回程、移交" 1
                menu_item 2 "印出 JSON" "與 --demo --audit --json 同一契約"
                menu_item 3 "姊妹面板 URL" "只印網址，不下載" 1
                menu_item 0 "離開沙盒"
            fi
            divider
            printf '%s' "$(t menu.ask)"
            if ! read -r choice; then
                printf '\n'
                break
            fi
            case "$choice" in
                1) ;;
                2) demo_emit_json ;;
                3) module_sister ;;
                0) break ;;
                *) warn "$(printf "$(t menu.invalid)" "$choice")" ;;
            esac
        done
        return 0
    fi
    demo_report_text
}

offer_demo_instead() {
    local reply=""
    warn "$(t err.need_root)"
    info "DO SGP1 (DigitalOcean · Singapore)"
    info "https://guard-demo.oece-x.com"
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        info "bash oece-x.sh --demo"
        return 0
    fi
    if [ "$UI_LANG" = "en" ]; then
        printf 'Enter the read-only sandbox? [Y/n] '
    else
        printf '進入只讀沙盒？[Y/n] '
    fi
    read -r reply || reply=""
    case "$reply" in
        n|N|no|NO) info "已取消。"; return 0 ;;
        *) module_demo ;;
    esac
}

#-----------------------------------------------------------------------
# 只讀體檢
#-----------------------------------------------------------------------
get_public_ip() {
    local url ip
    case "$1" in
        4) url="https://api.ipify.org" ;;
        6) url="https://api6.ipify.org" ;;
        *) return 1 ;;
    esac
    ip="$(curl "${CURL_OPTS[@]}" --max-time 6 "$url" 2>/dev/null || true)"
    case "$ip" in
        *[!0-9a-fA-F:.]*) printf '' ;;
        *) printf '%s' "$ip" ;;
    esac
}

sshd_fact() {
    local key="$1" val=""
    if command -v sshd >/dev/null 2>&1; then
        val="$(sshd -T 2>/dev/null | awk -v k="$key" '$1==k {print $2; exit}')"
    fi
    if [ -z "$val" ]; then
        printf 'unknown'
    else
        printf '%s' "$val"
    fi
}

collect_snapshot() {
    local cpu_model cpu_cores cpu_freq mem_total mem_avail mem_used swap_total
    local disk_line disk_total disk_used disk_pct virt kernel uptime_str cc qdisc
    local ipv4 ipv6

    cpu_model="$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
    [ -n "$cpu_model" ] || cpu_model="$(lscpu 2>/dev/null | awk -F': +' '/Model name/{print $2; exit}' || true)"
    [ -n "$cpu_model" ] || cpu_model="unknown"
    cpu_cores="$(nproc 2>/dev/null || echo '?')"
    cpu_freq="$(awk -F': ' '/cpu MHz/{printf "%.0f MHz", $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
    [ -n "$cpu_freq" ] || cpu_freq="unknown"

    mem_total="$(awk '/^MemTotal:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo '?')"
    mem_avail="$(awk '/^MemAvailable:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || true)"
    if [ -n "$mem_avail" ] && [ "$mem_total" != "?" ]; then
        mem_used=$(( mem_total - mem_avail ))
    else
        mem_used="?"
    fi
    swap_total="$(awk '/^SwapTotal:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo '?')"

    disk_line="$(df -h / 2>/dev/null | awk 'NR==2{print $2" "$3" "$5}')"
    disk_total="$(printf '%s' "$disk_line" | awk '{print $1}')"
    disk_used="$(printf '%s' "$disk_line" | awk '{print $2}')"
    disk_pct="$(printf '%s' "$disk_line" | awk '{print $3}')"
    [ -n "$disk_total" ] || disk_total="?"
    [ -n "$disk_used" ] || disk_used="?"
    [ -n "$disk_pct" ] || disk_pct="?"

    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt="$(systemd-detect-virt 2>/dev/null || echo none)"
    elif [ -f /.dockerenv ]; then
        virt="docker"
    else
        virt="unknown"
    fi

    kernel="$(uname -r)"
    uptime_str="$(uptime -p 2>/dev/null | sed 's/^up //' || true)"
    [ -n "$uptime_str" ] || uptime_str="$(awk '{printf "%.1f h", $1/3600}' /proc/uptime 2>/dev/null || echo '?')"
    cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
    ipv4="$(get_public_ip 4)"
    ipv6="$(get_public_ip 6)"
    [ -n "$ipv4" ] || ipv4="unknown"
    [ -n "$ipv6" ] || ipv6="none"

    SNAP_CPU_MODEL="$cpu_model"
    SNAP_CPU_CORES="$cpu_cores"
    SNAP_CPU_FREQ="$cpu_freq"
    SNAP_MEM_TOTAL="$mem_total"
    SNAP_MEM_USED="$mem_used"
    SNAP_SWAP="$swap_total"
    SNAP_DISK_TOTAL="$disk_total"
    SNAP_DISK_USED="$disk_used"
    SNAP_DISK_PCT="$disk_pct"
    SNAP_VIRT="$virt"
    SNAP_KERNEL="$kernel"
    SNAP_UPTIME="$uptime_str"
    SNAP_CC="$cc"
    SNAP_QDISC="$qdisc"
    SNAP_IPV4="$ipv4"
    SNAP_IPV6="$ipv6"
    SNAP_SSH_PORT="$(sshd_fact port)"
    SNAP_ROOT_LOGIN="$(sshd_fact permitrootlogin)"
    SNAP_PASS_AUTH="$(sshd_fact passwordauthentication)"
}

print_snapshot() {
    kv "系統" "$OS_PRETTY"
    kv "內核" "$SNAP_KERNEL"
    kv "架構" "$ARCH"
    kv "虛擬化" "$SNAP_VIRT"
    kv "運行時長" "$SNAP_UPTIME"
    divider
    kv "CPU" "${SNAP_CPU_MODEL}"
    kv "CPU 核數" "${SNAP_CPU_CORES} @ ${SNAP_CPU_FREQ}"
    kv "記憶體" "${SNAP_MEM_USED} MB / ${SNAP_MEM_TOTAL} MB"
    kv "Swap" "${SNAP_SWAP} MB"
    kv "磁碟 (/)" "${SNAP_DISK_USED} / ${SNAP_DISK_TOTAL} (${SNAP_DISK_PCT})"
    divider
    kv "TCP 擁塞" "$SNAP_CC"
    kv "隊列算法" "$SNAP_QDISC"
    kv "IPv4" "$SNAP_IPV4"
    kv "IPv6" "$SNAP_IPV6"
}

baseline_flag() {
    local name="$1" ok_when="$2" actual="$3"
    if [ "$actual" = "$ok_when" ]; then
        ok "${name}: ${actual}"
    else
        warn "${name}: ${actual}"
    fi
}

have_unit_or_bin() {
    local bin="$1" unit="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        printf 'present'
        return 0
    fi
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
        if systemctl list-unit-files "${unit}" 2>/dev/null | grep -q "$unit"; then
            printf 'present'
            return 0
        fi
    fi
    printf 'absent'
}

firewall_state() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | head -1 | grep -qi 'active'; then
            printf 'ufw active'
            return 0
        fi
        printf 'ufw inactive'
        return 0
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state >/dev/null 2>&1; then
            printf 'firewalld running'
            return 0
        fi
        printf 'firewalld stopped'
        return 0
    fi
    printf 'unknown'
}

docker_socket_state() {
    if [ ! -S /var/run/docker.sock ]; then
        printf 'no socket'
        return 0
    fi
    local mode
    mode="$(stat -c '%a' /var/run/docker.sock 2>/dev/null || stat -f '%OLp' /var/run/docker.sock 2>/dev/null || echo '?')"
    printf 'socket mode %s' "$mode"
}

module_sysinfo() {
    require_live || return 1
    section "$(t menu.1)"
    collect_snapshot
    print_snapshot
}

module_baseline() {
    local fail2ban upgrades fw docker_sock
    require_live || return 1
    section "$(t menu.4)"
    collect_snapshot
    kv "SSH 端口" "$SNAP_SSH_PORT"
    baseline_flag "PermitRootLogin" "prohibit-password" "$SNAP_ROOT_LOGIN"
    baseline_flag "PasswordAuthentication" "no" "$SNAP_PASS_AUTH"
    fail2ban="$(have_unit_or_bin fail2ban-client fail2ban.service)"
    upgrades="$(have_unit_or_bin unattended-upgrade unattended-upgrades.service)"
    fw="$(firewall_state)"
    docker_sock="$(docker_socket_state)"
    kv "fail2ban" "$fail2ban"
    kv "自動安全更新" "$upgrades"
    kv "防火牆" "$fw"
    kv "Docker socket" "$docker_sock"
    section "移交"
    info "初篩到此。32 項評分與可回滾加固在姊妹面板。本腳本不下載它。"
    printf '  Initial Baseline → sister oece-x-blue.sh  (57 → 75 → 83)\n'
    printf '  %s\n' "$BLUE_REPO_URL"
}

emit_audit_json() {
    collect_snapshot
    printf '{\n'
    printf '  "tool": "oece-x.sh",\n'
    printf '  "version": "%s",\n' "$SCRIPT_VERSION"
    printf '  "mode": "audit",\n'
    printf '  "os": "%s",\n' "$(json_escape "$OS_PRETTY")"
    printf '  "kernel": "%s",\n' "$(json_escape "$SNAP_KERNEL")"
    printf '  "arch": "%s",\n' "$(json_escape "$ARCH")"
    printf '  "virt": "%s",\n' "$(json_escape "$SNAP_VIRT")"
    printf '  "cpu": "%s",\n' "$(json_escape "$SNAP_CPU_MODEL")"
    printf '  "cpu_cores": "%s",\n' "$(json_escape "$SNAP_CPU_CORES")"
    printf '  "memory_mb": "%s",\n' "$(json_escape "$SNAP_MEM_TOTAL")"
    printf '  "memory_used_mb": "%s",\n' "$(json_escape "$SNAP_MEM_USED")"
    printf '  "disk": "%s",\n' "$(json_escape "${SNAP_DISK_USED}/${SNAP_DISK_TOTAL} ${SNAP_DISK_PCT}")"
    printf '  "tcp_congestion": "%s",\n' "$(json_escape "$SNAP_CC")"
    printf '  "qdisc": "%s",\n' "$(json_escape "$SNAP_QDISC")"
    printf '  "ipv4": "%s",\n' "$(json_escape "$SNAP_IPV4")"
    printf '  "ipv6": "%s",\n' "$(json_escape "$SNAP_IPV6")"
    printf '  "ssh_port": "%s",\n' "$(json_escape "$SNAP_SSH_PORT")"
    printf '  "permit_root_login": "%s",\n' "$(json_escape "$SNAP_ROOT_LOGIN")"
    printf '  "password_authentication": "%s",\n' "$(json_escape "$SNAP_PASS_AUTH")"
    printf '  "fail2ban": "%s",\n' "$(json_escape "$(have_unit_or_bin fail2ban-client fail2ban.service)")"
    printf '  "firewall": "%s",\n' "$(json_escape "$(firewall_state)")"
    printf '  "docker_socket": "%s"\n' "$(json_escape "$(docker_socket_state)")"
    printf '}\n'
}

module_audit() {
    require_live || return 1
    if [ "$AUDIT_JSON" -eq 1 ]; then
        emit_audit_json
        return 0
    fi
    module_sysinfo
    printf '\n'
    module_baseline
}

#-----------------------------------------------------------------------
# 測速與回程。第三方工具先展示 URL，再要求 yes。
#-----------------------------------------------------------------------
cf_latency() {
    local t sum=0 n=0 min=999999 max=0
    for _ in 1 2 3 4 5; do
        t="$(curl -o /dev/null -s -w '%{time_connect}' --max-time 8 https://www.cloudflare.com/cdn-cgi/trace || true)"
        case "$t" in
            ''|0|0.000) continue ;;
        esac
        n=$((n + 1))
        # shellcheck disable=SC2046
        t="$(awk -v x="$t" 'BEGIN{printf "%d", x*1000}')"
        sum=$((sum + t))
        [ "$t" -lt "$min" ] && min="$t"
        [ "$t" -gt "$max" ] && max="$t"
    done
    if [ "$n" -eq 0 ]; then
        warn "Cloudflare 握手沒有成功樣本。"
        return 1
    fi
    kv "樣本" "$n"
    kv "平均連線" "$((sum / n)) ms"
    kv "最小 / 最大" "${min} ms / ${max} ms"
}

module_speed() {
    local choice=""
    require_live || return 1
    section "$(t menu.2)"
    printf ' 1) Cloudflare 連線時間（5 次，只讀）\n'
    printf ' 2) Ookla 官方 CLI（會執行 https://install.speedtest.net/app/cli/install.sh，先確認）\n'
    printf ' 0) 返回\n'
    printf '%s' "$(t menu.ask)"
    read -r choice || return 0
    case "$choice" in
        1) cf_latency || true ;;
        2)
            confirm_danger "將下載並執行 Ookla 官方安裝器。來源：https://install.speedtest.net/app/cli/install.sh" || return 0
            curl "${CURL_OPTS[@]}" --max-time 30 https://install.speedtest.net/app/cli/install.sh | bash
            command -v speedtest >/dev/null 2>&1 && speedtest || warn "安裝後仍找不到 speedtest。"
            ;;
        0) return 0 ;;
        *) warn "$(printf "$(t menu.invalid)" "$choice")" ;;
    esac
}

route_targets() {
    # 公開 DNS，不是私人主機。
    printf '%s\n' \
        "192.0.2.1 documentation" \
        "1.1.1.1 Cloudflare" \
        "8.8.8.8 Google" \
        "223.5.5.5 AliDNS"
}

module_route() {
    local line name ip out=""
    require_live || return 1
    section "$(t menu.3)"
    info "只追蹤公開 DNS 與一個 RFC 5737 文件位址。文件位址預期不可達。"
    if ! command -v traceroute >/dev/null 2>&1; then
        warn "沒有 traceroute。安裝它之後再跑，或只看目標清單。"
    fi
    while IFS= read -r line; do
        ip="${line%% *}"
        name="${line#* }"
        printf '\n%s%s%s  %s\n' "$C_BOLD" "$name" "$C_RESET" "$ip"
        if command -v traceroute >/dev/null 2>&1; then
            traceroute -n -w 1 -m 8 "$ip" 2>/dev/null | head -12 || true
        fi
    done <<'EOF'
192.0.2.1 documentation
1.1.1.1 Cloudflare
8.8.8.8 Google
223.5.5.5 AliDNS
EOF
    if [ -t 0 ] && [ -t 1 ]; then
        printf '把這段說明寫進 ./oece-x-route.md？[y/N] '
        read -r out || out=""
        if [ "$out" = "y" ] || [ "$out" = "Y" ]; then
            {
                printf '# oece-x.sh route note\n\n'
                printf 'Generated by v%s. Targets are public DNS plus one RFC 5737 address.\n' "$SCRIPT_VERSION"
                route_targets
            } > ./oece-x-route.md
            ok "已寫入 ./oece-x-route.md"
        fi
    fi
}

#-----------------------------------------------------------------------
# 基準與少數會改系統的項目。變更都要 yes。
#-----------------------------------------------------------------------
module_bench() {
    local choice="" start end
    require_live || return 1
    section "$(t menu.5)"
    printf ' 1) CPU 整數迴圈（約數秒）\n'
    printf ' 2) 磁碟順序寫 256MB 後刪除\n'
    printf ' 3) /dev/shm 記憶體複製 128MB（沒有 tmpfs 則跳過）\n'
    printf ' 0) 返回\n'
    printf '%s' "$(t menu.ask)"
    read -r choice || return 0
    case "$choice" in
        1)
            start="$(date +%s)"
            awk 'BEGIN{for(i=0;i<1500000;i++) x+=i; print x}' >/dev/null
            end="$(date +%s)"
            kv "CPU 迴圈" "$((end - start)) s"
            ;;
        2)
            confirm_danger "將在 /tmp 寫入 256MB 後刪除。" || return 0
            start="$(date +%s)"
            dd if=/dev/zero of="${TMP_DIR}/bench.bin" bs=1M count=256 status=none
            rm -f "${TMP_DIR}/bench.bin"
            end="$(date +%s)"
            kv "磁碟 256MB" "$((end - start)) s"
            ;;
        3)
            if [ ! -d /dev/shm ] || [ ! -w /dev/shm ]; then
                warn "沒有可寫的 /dev/shm。"
                return 0
            fi
            start="$(date +%s)"
            dd if=/dev/zero of=/dev/shm/oece-bench.bin bs=1M count=128 status=none
            rm -f /dev/shm/oece-bench.bin
            end="$(date +%s)"
            kv "記憶體 128MB" "$((end - start)) s"
            ;;
        0) return 0 ;;
        *) warn "$(printf "$(t menu.invalid)" "$choice")" ;;
    esac
}

module_bbr() {
    local choice="" cc qdisc
    require_live || return 1
    section "$(t menu.6)"
    cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
    kv "擁塞控制" "$cc"
    kv "隊列" "$qdisc"
    printf ' 1) 只看狀態\n'
    printf ' 2) 啟用 fq + bbr（寫入 /etc/sysctl.d/99-oece-bbr.conf）\n'
    printf ' 0) 返回\n'
    printf '%s' "$(t menu.ask)"
    read -r choice || return 0
    case "$choice" in
        1|0) return 0 ;;
        2)
            confirm_danger "將寫入 sysctl.d 並立即套用 fq + bbr。" || return 0
            printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' \
                > /etc/sysctl.d/99-oece-bbr.conf
            sysctl --system >/dev/null
            ok "已套用。目前：$(sysctl -n net.ipv4.tcp_congestion_control)"
            ;;
        *) warn "$(printf "$(t menu.invalid)" "$choice")" ;;
    esac
}

module_docker() {
    require_live || return 1
    section "$(t menu.7)"
    if ! command -v docker >/dev/null 2>&1; then
        warn "沒有 docker 指令。"
        return 0
    fi
    docker version --format 'client {{.Client.Version}}' 2>/dev/null || warn "docker version 失敗"
    kv "容器" "$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')"
    kv "鏡像" "$(docker images -q 2>/dev/null | wc -l | tr -d ' ')"
    kv "socket" "$(docker_socket_state)"
    info "這裡不安裝、不刪除、不 prune。"
}

module_sister() {
    section "$(t menu.8)"
    info "姊妹專案負責評分、分級加固與自動還原。本腳本不下載、不執行它。"
    printf '  repo: %s\n' "$BLUE_REPO_URL"
    printf '  raw : %s\n' "$BLUE_RAW_URL"
    printf '  live: https://guard-demo.oece-x.com\n'
    printf '\n  git clone %s.git\n' "$BLUE_REPO_URL"
    printf '  sudo bash oece-x-blue.sh --audit\n'
}

module_self_update() {
    local remote=""
    section "$(t menu.9)"
    kv "本機版本" "$SCRIPT_VERSION"
    kv "比對來源" "$SCRIPT_RAW_URL"
    if ! command -v curl >/dev/null 2>&1; then
        err "沒有 curl。"
        return 1
    fi
    remote="$(curl "${CURL_OPTS[@]}" --max-time 15 "$SCRIPT_RAW_URL" 2>/dev/null \
        | sed -n 's/^SCRIPT_VERSION="\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)".*/\1/p' \
        | head -1 || true)"
    if [ -z "$remote" ]; then
        err "讀不到遠端 SCRIPT_VERSION。本機檔案未改。"
        return 1
    fi
    kv "遠端版本" "$remote"
    if [ "$remote" = "$SCRIPT_VERSION" ]; then
        ok "已是遠端 main 上的同一版本。"
        return 0
    fi
    warn "版本不同。本工具不會自動覆蓋。請下載後自己核對再替換。"
    printf '  %s\n' "$SCRIPT_RAW_URL"
}

print_banner() {
    printf '\n'
    printf '%s%s' "$C_BLUE" "$C_BOLD"
    cat <<'BANNER'
  ___  ___ ___ ___   __  __
 / _ \| __/ __| __| \ \/ /
| (_) | _| (__| _|   >  <
 \___/|___\___|___| /_/\_\
BANNER
    printf '%s' "$C_RESET"
    printf '%s  oece-x.sh v%s · %s%s\n' "$C_DIM" "$SCRIPT_VERSION" "$(t banner.tagline)" "$C_RESET"
    printf '%s  sister · oece-x-blue.sh · %s%s\n' "$C_DIM" "$BLUE_REPO_URL" "$C_RESET"
}

main_menu() {
    local choice=""
    while true; do
        print_banner
        divider
        menu_group "$(t group.look)"
        menu_item 1 "$(t menu.1)" "$(t menu.1h)" 1
        menu_item 4 "$(t menu.4)" "$(t menu.4h)" 1
        menu_group "$(t group.measure)"
        menu_item 2 "$(t menu.2)" "$(t menu.2h)"
        menu_item 3 "$(t menu.3)" "$(t menu.3h)"
        menu_item 5 "$(t menu.5)" "$(t menu.5h)" 1
        menu_item 6 "$(t menu.6)" "$(t menu.6h)"
        menu_item 7 "$(t menu.7)" "$(t menu.7h)"
        menu_group "$(t group.next)"
        menu_item 8 "$(t menu.8)" "$(t menu.8h)" 1
        menu_item 9 "$(t menu.9)" "$(t menu.9h)"
        menu_item 0 "$(t menu.0)"
        divider
        printf '%s' "$(t menu.ask)"
        read -r choice || { printf '\n'; break; }
        case "$choice" in
            1) module_sysinfo || true; pause ;;
            2) module_speed || true; pause ;;
            3) module_route || true; pause ;;
            4) module_baseline || true; pause ;;
            5) module_bench || true; pause ;;
            6) module_bbr || true; pause ;;
            7) module_docker || true; pause ;;
            8) module_sister || true; pause ;;
            9) module_self_update || true; pause ;;
            0) info "$(t menu.exit)"; break ;;
            *) warn "$(printf "$(t menu.invalid)" "$choice")" ;;
        esac
    done
}

usage() {
    cat <<EOF
oece-x.sh v${SCRIPT_VERSION} — 3-minute VPS audit / 3 分鐘 VPS 體檢

用法 / Usage:
  bash oece-x.sh                      互動選單 / interactive menu
  bash oece-x.sh --audit              只讀體檢 / read-only audit
  bash oece-x.sh --audit --json       機器可讀 JSON / machine-readable JSON
  bash oece-x.sh --demo               免 root 沙盒 / rootless DO SGP1 sandbox
  bash oece-x.sh --demo --audit
  bash oece-x.sh --demo --audit --json
  bash oece-x.sh --lang zh-Hant       繁體中文
  bash oece-x.sh --lang en            English
  bash oece-x.sh --version
  bash oece-x.sh --help

語言 / Language:
  --lang 與 OECE_LANG 優先。其次讀 /etc/oece-x/lang。
  LANG=zh_CN 與其他 zh* 一律使用繁體。en* 使用 English。
  首次互動且沒有偏好檔時，會先詢問一次。

姊妹專案只給 URL，本腳本不下載：
  ${BLUE_REPO_URL}

沙盒與作品集：
  https://guard-demo.oece-x.com
  https://portfolio.oece-x.com
EOF
}

main() {
    local mode="" want_demo=0
    TMP_DIR="$(mktemp -d /tmp/oece-x.XXXXXX)"
    while [ $# -gt 0 ]; do
        case "$1" in
            --version|-v) printf 'oece-x.sh v%s\n' "$SCRIPT_VERSION"; exit 0 ;;
            --help|-h) usage; exit 0 ;;
            --lang)
                shift
                [ $# -gt 0 ] || { usage; exit 1; }
                apply_lang_arg "$1"
                ;;
            --lang=*) apply_lang_arg "${1#--lang=}" ;;
            --json) AUDIT_JSON=1 ;;
            --demo) want_demo=1 ;;
            --audit) mode="audit" ;;
            "") break ;;
            *) usage; exit 1 ;;
        esac
        shift
    done
    UI_LANG="$(resolve_lang)"

    if [ "$want_demo" -eq 1 ]; then
        if [ "$mode" = "audit" ]; then
            if [ "$AUDIT_JSON" -eq 1 ]; then
                demo_emit_json
            else
                demo_report_text
            fi
            exit 0
        fi
        module_demo
        exit 0
    fi

    if [ "$mode" = "audit" ]; then
        require_live || exit 1
        if [ "$AUDIT_JSON" -eq 1 ]; then
            emit_audit_json
        else
            module_audit
        fi
        exit 0
    fi

    if ! can_run_live; then
        offer_demo_instead
        exit 0
    fi
    detect_os
    prompt_lang_if_needed
    UI_LANG="$(resolve_lang)"
    main_menu
}

main "$@"
