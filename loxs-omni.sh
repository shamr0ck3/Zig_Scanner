#!/bin/bash
# LOXS-Omni v6.0 - Integrated JDT-Mobile Security Suite
# Tool    : LOXS-Omni (Master Controller)
# Version : 6.0
# Author  : shamr0ck3 / LOXS

# ── Colors ────────────────────────────────────────────────────────
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
BLU='\033[1;34m'; CYN='\033[1;36m'; MAG='\033[1;35m'; RST='\033[0m'
DIM='\033[2m'; BOLD='\033[1m'

# ── Base directory (always relative to script location) ───────────
BASE="$(cd "$(dirname "$0")" && pwd)"

# ── Helper ────────────────────────────────────────────────────────
log()  { echo -e "  ${CYN}[*]${RST} $*"; }
ok()   { echo -e "  ${GRN}[✓]${RST} $*"; }
warn() { echo -e "  ${YLW}[!]${RST} $*"; }
err()  { echo -e "  ${RED}[✗]${RST} $*"; }

prompt_target() {
    local target=""
    while [[ -z "$target" ]]; do
        echo -ne "\n  ${CYN}Enter target (e.g. scanme.nmap.org or 127.0.0.1:65412):${RST} "
        read -r target
    done
    echo "$target"
}

# ── Banner ────────────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${CYN}"
    echo "  ██╗      ██████╗ ██╗  ██╗███████╗"
    echo "  ██║     ██╔═══██╗╚██╗██╔╝██╔════╝"
    echo "  ██║     ██║   ██║ ╚███╔╝ ███████╗"
    echo "  ██║     ██║   ██║ ██╔██╗ ╚════██║"
    echo "  ███████╗╚██████╔╝██╔╝ ██╗███████║"
    echo "  ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝"
    echo -e "${RST}"
    echo -e "  ${DIM}LOXS-Omni v6.0 | shamr0ck3 | JDT-Mobile${RST}"
    echo -e "  ${DIM}─────────────────────────────────────────${RST}"

    # Service status
    local pdf_status="${RED}OFFLINE${RST}"
    local cron_status="${RED}OFFLINE${RST}"
    pgrep -f "pdf_scan.py" > /dev/null && pdf_status="${GRN}RUNNING${RST}"
    pgrep crond > /dev/null && cron_status="${GRN}ACTIVE${RST}"

    echo -e "  PDF Engine : $pdf_status"
    echo -e "  Cron Shield: $cron_status"
    echo ""
}

# ── Menu ──────────────────────────────────────────────────────────
show_menu() {
    echo -e "  ${CYN}╔══ MISSION PROFILE ══════════════════╗${RST}"
    echo -e "  ${CYN}║${RST}  1) LEGACY RECON     (intelijen v3.sh.bak)"
    echo -e "  ${CYN}║${RST}  2) MODERN FUZZ      (intelijen v3.sh)"
    echo -e "  ${CYN}║${RST}  3) FULL PIPELINE    (runner.sh → probe → recon → fuzz)"
    echo -e "  ${CYN}║${RST}  4) RECON ADVISOR    (recon_advisor → intelijen)"
    echo -e "  ${CYN}║${RST}  5) PDF SCANNER      (pdf_scan.py)"
    echo -e "  ${CYN}║${RST}  6) STOP PDF ENGINE"
    echo -e "  ${CYN}║${RST}  Q) EXIT"
    echo -e "  ${CYN}╚═════════════════════════════════════╝${RST}"
    echo -ne "\n  ${CYN}LOXS@JDT-Mobile${RST} ❯ "
}

# ── Cleanup on exit ───────────────────────────────────────────────
cleanup() {
    echo -e "\n${YLW}  [*] Cleaning up background tasks...${RST}"
    pkill -f "pdf_scan.py" 2>/dev/null
    pkill -f "wegrab.py" 2>/dev/null
    echo -e "${RED}  Session Terminated.${RST}\n"
    exit 0
}
trap cleanup INT TERM

# ── Main loop ─────────────────────────────────────────────────────
while true; do
    show_banner
    show_menu
    read -r choice

    case $choice in

        # ── 1) Legacy Recon ───────────────────────────────────────
        1)
            if [[ ! -f "$BASE/intelijen_legacy.sh" ]]; then
                err "intelijen_legacy.sh not found."
                sleep 2; continue
            fi
            echo -e "\n${GRN}  [+] Launching Legacy Recon...${RST}"
            bash "$BASE/intelijen_legacy.sh"
            echo -ne "\n  ${DIM}Press Enter to return...${RST}"; read -r
            ;;

        # ── 2) Modern Fuzz ────────────────────────────────────────
        2)
            if [[ ! -f "$BASE/intelijen_v3.sh" ]]; then
                err "intelijen_v3.sh not found."
                sleep 2; continue
            fi
            echo -e "\n${GRN}  [+] Launching Modern Fuzzer...${RST}"
            bash "$BASE/intelijen_v3.sh"
            echo -ne "\n  ${DIM}Press Enter to return...${RST}"; read -r
            ;;

        # ── 3) Full Pipeline ──────────────────────────────────────
        3)
            if [[ ! -f "$BASE/runner.sh" ]]; then
                err "runner.sh not found."
                sleep 2; continue
            fi
            target=$(prompt_target)
            echo -e "\n${GRN}  [+] Launching Full Pipeline for: ${CYN}$target${RST}"
            COOKIE_STRING="$(tr -d '\n\r' < "$BASE/cookie_nmap.txt" 2>/dev/null)" \
                bash "$BASE/runner.sh" "$target"
            echo -ne "\n  ${DIM}Press Enter to return...${RST}"; read -r
            ;;

        # ── 4) Recon Advisor → intelijen_v3.sh ───────────────────
        4)
            if [[ ! -f "$BASE/recon_advisor.sh" ]]; then
                err "recon_advisor.sh not found."
                sleep 2; continue
            fi
            target=$(prompt_target)

            # Strip scheme for recon_advisor -d flag
            clean_target=$(echo "$target" | sed -E 's|^https?://||')

            echo -e "\n${GRN}  [+] Running Recon Advisor for: ${CYN}$target${RST}"
            COOKIE_STRING="$(tr -d '\n\r' < "$BASE/cookie_nmap.txt" 2>/dev/null)" \
                bash "$BASE/recon_advisor.sh" -d "$target"

            # Auto-launch intelijen_v3.sh with exported vars
            if [[ -f "$BASE/intelijen_v3.sh" ]]; then
                echo -e "\n${GRN}  [+] Handing off to intelijen_v3.sh...${RST}"
                sleep 1
                export ZIG_TARGET="http://$clean_target"
                export ZIG_DELAY="${ZIG_DELAY:-1}"
                bash "$BASE/intelijen_v3.sh"
            fi
            echo -ne "\n  ${DIM}Press Enter to return...${RST}"; read -r
            ;;

        # ── 5) PDF Scanner ────────────────────────────────────────
        5)
            if [[ ! -f "$BASE/pdf_scan.py" ]]; then
                err "pdf_scan.py not found."
                sleep 2; continue
            fi
            if pgrep -f "pdf_scan.py" > /dev/null; then
                ok "PDF Engine already running."
            else
                log "Starting PDF Engine..."
                python3 "$BASE/pdf_scan.py" > /dev/null 2>&1 &
                sleep 2
                ok "PDF Engine started on http://127.0.0.1:5000"
            fi
            termux-open-url http://127.0.0.1:5000 2>/dev/null || \
                log "Open browser → http://127.0.0.1:5000"
            echo -ne "\n  ${DIM}Press Enter to return...${RST}"; read -r
            ;;

        # ── 6) Stop PDF Engine ────────────────────────────────────
        6)
            if pkill -f "pdf_scan.py" 2>/dev/null; then
                ok "PDF Engine stopped."
            else
                warn "PDF Engine was not running."
            fi
            sleep 1
            ;;

        # ── Q) Exit ───────────────────────────────────────────────
        [Qq])
            cleanup
            ;;

        *)
            warn "Invalid choice. Try again."
            sleep 1
            ;;
    esac
done
