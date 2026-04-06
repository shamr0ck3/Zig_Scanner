#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════╗
# ║   SUBPROBE v2.1 — Subdomain Enum + HTTP Probe Pipeline       ║
# ║   Flow: Enum → Resolve → HTTP Probe → Live Filter            ║
# ║   by shamr0ck3 | Termux Ready | Optimized & Hardened         ║
# ╚═══════════════════════════════════════════════════════════════╝

# ── Cleanup Trap ──────────────────────────────────────────────────
trap 'rm -f /tmp/subprobe_* ./subprobe_*.tmp; exit' INT TERM EXIT

# ── Colors ────────────────────────────────────────────────────────
RST="\e[0m"; BOLD="\e[1m"; DIM="\e[2m"; CYAN="\e[1;36m"; GREEN="\e[1;32m"
YELLOW="\e[1;33m"; RED="\e[1;31m"; MAGENTA="\e[1;35m"; BLUE="\e[1;34m"

# ── Status code color map ─────────────────────────────────────────
status_color() {
    case "$1" in
        2*) echo -e "${GREEN}$1${RST}" ;;
        301|302|303|307|308) echo -e "${CYAN}$1${RST}" ;;
        3*) echo -e "${BLUE}$1${RST}" ;;
        403|401) echo -e "${YELLOW}$1${RST}" ;;
        4*) echo -e "${DIM}$1${RST}" ;;
        5*) echo -e "${RED}$1${RST}" ;;
        *)  echo -e "${DIM}???${RST}" ;;
    esac
}

banner() {
    echo -e "${CYAN}██╗      ██████╗ ██╗  ██╗███████╗${RST}"
    echo -e "${CYAN}██║     ██╔═══██╗╚██╗██╔╝██╔════╝${RST}"
    echo -e "${CYAN}██║     ██║   ██║ ╚███╔╝ ███████╗${RST}"
    echo -e "${CYAN}██║     ██║   ██║ ██╔██╗ ╚════██║${RST}"
    echo -e "${CYAN}███████╗╚██████╔╝██╔╝ ██╗███████║${RST}"
    echo -e "${CYAN}╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝${RST}"
    echo -e "${MAGENTA}  Optimized Subdomain Discovery & Probing v2.1${RST}\n"
}

usage() {
    echo -e "${CYAN}Usage:${RST}  $0 ${YELLOW}<domain>${RST} ${DIM}[options]${RST}"
    echo -e "\n${CYAN}Options:${RST}"
    echo -e "  ${GREEN}-o <dir>${RST}    Output directory"
    echo -e "  ${GREEN}-t <sec>${RST}    HTTP timeout (default: auto)"
    echo -e "  ${GREEN}-c <n>${RST}      Concurrency/Threads (default: auto)"
    echo -e "  ${GREEN}-f <codes>${RST}  Filter codes (default: 200,301,302,403)"
    echo -e "  ${GREEN}-C <file>${RST}   Cookie file (default: cookie_nmap.txt)"
    echo -e "  ${GREEN}-v${RST}          VPN mode (Conservative settings)"
    echo -e "  ${GREEN}-s${RST}          Skip enum, use existing subs.txt"
    echo -e "  ${GREEN}-q${RST}          Quiet mode"
    exit 0
}

log()  { [[ $QUIET -eq 0 ]] && echo -e "  ${CYAN}[*]${RST} $*"; }
ok()   { echo -e "  ${GREEN}[✓]${RST} $*"; }
warn() { [[ $QUIET -eq 0 ]] && echo -e "  ${YELLOW}[!]${RST} $*"; }
err()  { echo -e "  ${RED}[✗]${RST} $*"; }
dim()  { [[ $QUIET -eq 0 ]] && echo -e "  ${DIM}    $*${RST}"; }

# ── Cookie Loader ─────────────────────────────────────────────────
load_cookie() {
    local cookie_file="${1:-cookie_nmap.txt}"
    if [[ -f "$cookie_file" ]]; then
        COOKIE_STRING=$(tr -d '\n\r' < "$cookie_file")
        ok "Cookie loaded from ${CYAN}$cookie_file${RST} → ${DIM}${COOKIE_STRING:0:50}...${RST}"
    else
        warn "Cookie file '$cookie_file' not found — proceeding without cookie"
        COOKIE_STRING=""
    fi
    export COOKIE_STRING
}

# ── Network Auto-tune ─────────────────────────────────────────────
autotune() {
    local ping_host="8.8.8.8"
    local avg_ms
    avg_ms=$(ping -c 3 -W 2 "$ping_host" 2>/dev/null | awk -F'/' 'END {print $5}' | cut -d. -f1)

    if [[ -z "$avg_ms" ]]; then
        echo "10 8"
        return
    fi
    if   (( avg_ms < 50 ));  then echo "5 30"
    elif (( avg_ms < 100 )); then echo "8 20"
    else                          echo "12 10"; fi
}

clean_subs() {
    sed 's/\*\.//g' | tr '[:upper:]' '[:lower:]' | \
    grep -E "^([a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$"
}

# ── Enumeration Sources ───────────────────────────────────────────
fetch_crtsh() {
    dim "Source: crt.sh"
    curl -sL --max-time $((TIMEOUT+5)) \
        "https://crt.sh/?q=%25.$1&output=json" \
        | jq -r '.[].name_value' 2>/dev/null | clean_subs
}

fetch_otx() {
    dim "Source: AlienVault OTX"
    curl -sL --max-time $((TIMEOUT+5)) \
        "https://otx.alienvault.com/api/v1/indicators/domain/$1/passive_dns" \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null | clean_subs
}

fetch_hackertarget() {
    dim "Source: HackerTarget"
    curl -sL --max-time $((TIMEOUT+5)) \
        "https://api.hackertarget.com/hostsearch/?q=$1" \
        | cut -d',' -f1 2>/dev/null | clean_subs
}

# ── Core Phases ───────────────────────────────────────────────────
run_enum() {
    local domain="$1" outfile="$2"
    local tmp; tmp=$(mktemp /tmp/subprobe_enum_XXXX.tmp)
    log "Phase 1: Enumeration"

    fetch_crtsh "$domain" >> "$tmp"
    fetch_otx "$domain" >> "$tmp"
    fetch_hackertarget "$domain" >> "$tmp"

    # FIX: pipe comment was eating the redirect — moved to proper line
    sort -u "$tmp" | grep "\.${domain}$" | grep -v "^${domain}$" > "$outfile"
    rm -f "$tmp"
    ok "Found $(wc -l < "$outfile") unique subdomains."
}

run_resolve() {
    local subfile="$1" outfile="$2"
    log "Phase 2: DNS Resolution"
    > "$outfile"

    while read -r sub; do
        if command -v host >/dev/null; then
            host "$sub" >/dev/null 2>&1 && echo "$sub" >> "$outfile" && \
                [[ $QUIET -eq 0 ]] && echo -e "  ${GREEN}✓${RST} $sub" &
        else
            dig +short "$sub" 2>/dev/null | grep -qE '^[0-9]' && \
                echo "$sub" >> "$outfile" && \
                [[ $QUIET -eq 0 ]] && echo -e "  ${GREEN}✓${RST} $sub" &
        fi

        # Parallel throttle for DNS
        [[ $(jobs -r | wc -l) -gt 20 ]] && wait -n 2>/dev/null || true
    done < "$subfile"
    wait
    ok "Resolved $(wc -l < "$outfile") hosts."
}

# ── Banner Grabbing ────────────────────────────────────────────────
grab_banner() {
    local host="$1"
    local port="$2"
    local banner=""

    case $port in
        22)
            banner=$(timeout 3 nc -vn "$host" 22 2>&1 | grep -E "^SSH" | head -1)
            ;;
        80|443)
            banner=$(curl -I -s --max-time 3 \
                ${COOKIE_STRING:+-b "$COOKIE_STRING"} \
                "http://$host" 2>/dev/null | grep -i "^Server:" | cut -d" " -f2-)
            ;;
        21)
            banner=$(timeout 3 nc -vn "$host" 21 2>&1 | head -1)
            ;;
        *)
            banner="unknown"
            ;;
    esac
    echo "$banner"
}

probe_url() {
    local url="$1" timeout="$2" filterfile="$3" livefile="$4"
    local code

    # FIX: cookie injected via COOKIE_STRING if set
    code=$(curl -I -s -o /dev/null --max-time "$timeout" --connect-timeout 5 \
        --path-as-is -w "%{http_code}" \
        ${COOKIE_STRING:+-b "$COOKIE_STRING"} \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$url" 2>/dev/null)

    if grep -qw "$code" "$filterfile" 2>/dev/null; then
        echo -e "  ${BOLD}${url#*//}${RST} → $(status_color "$code")"
        echo "$url|$code" >> "$livefile"
    fi
}

run_probe() {
    local resolved_file="$1" outfile="$2" timeout="$3" concurrency="$4" filter_codes="$5"
    log "Phase 3: HTTP Probing (Threads: $concurrency)"
    [[ -n "$COOKIE_STRING" ]] && dim "Using cookie: ${COOKIE_STRING:0:50}..."

    local f_tmp; f_tmp=$(mktemp /tmp/subprobe_filter_XXXX.tmp)
    echo "$filter_codes" | tr ',' '\n' > "$f_tmp"
    > "$outfile"

    while read -r sub; do
        for scheme in https http; do
            probe_url "$scheme://$sub" "$timeout" "$f_tmp" "$outfile" &

            while [[ $(jobs -r | wc -l) -ge $concurrency ]]; do
                sleep 0.1
                wait -n 2>/dev/null || wait
            done
        done
    done < "$resolved_file"
    wait
    rm -f "$f_tmp"
}

# ── Main ──────────────────────────────────────────────────────────
main() {
    COOKIE_STRING=""
    QUIET=0
    TIMEOUT=0

    banner
    [[ $# -eq 0 ]] && usage

    local domain="$1"; shift
    local outdir="" filter_codes="200,301,302,403"
    local skip_enum=0 vpn_mode=0
    local cookie_file="cookie_nmap.txt"
    local concurrency=0

    while getopts "o:t:c:f:C:vsqh" opt; do
        case $opt in
            o) outdir="$OPTARG" ;;
            t) TIMEOUT="$OPTARG" ;;
            c) concurrency="$OPTARG" ;;
            f) filter_codes="$OPTARG" ;;
            C) cookie_file="$OPTARG" ;;
            v) vpn_mode=1 ;;
            s) skip_enum=1 ;;
            q) QUIET=1 ;;
            *) usage ;;
        esac
    done

    # FIX: use explicit zero-check instead of :- since vars init to 0
    if [[ $vpn_mode -eq 1 ]]; then
        [[ $TIMEOUT -eq 0 ]]     && TIMEOUT=12
        [[ $concurrency -eq 0 ]] && concurrency=8
    else
        read -r auto_t auto_c < <(autotune)
        [[ $TIMEOUT -eq 0 ]]     && TIMEOUT=$auto_t
        [[ $concurrency -eq 0 ]] && concurrency=$auto_c  # FIX: was hardcoded 5
    fi
    export TIMEOUT

    outdir=${outdir:-"./recon_$domain"}
    mkdir -p "$outdir"

    # Load cookie
    load_cookie "$cookie_file"

    local subs_f="$outdir/subs.txt"
    local res_f="$outdir/resolved.txt"
    local live_f="$outdir/live.txt"

    [[ $skip_enum -eq 0 ]] && run_enum "$domain" "$subs_f"
    [[ -s "$subs_f" ]]     && run_resolve "$subs_f" "$res_f"
    [[ -s "$res_f" ]]      && run_probe "$res_f" "$live_f" "$TIMEOUT" "$concurrency" "$filter_codes"

    echo -e "\n${GREEN}${BOLD}Scan Finished.${RST} Results in ${CYAN}$outdir${RST}"
    [[ -s "$live_f" ]] && ok "Live hosts: $(wc -l < "$live_f")"
}

main "$@"
