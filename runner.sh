#!/usr/bin/env bash
BASE="$(cd "$(dirname "$0")" && pwd)"
# runner.sh — The Pipeline Connector v2.1
# by shamr0ck3 | Termux Ready

# ── Colors ────────────────────────────────────────────────────────
RST="\e[0m"; GREEN="\e[1;32m"; YELLOW="\e[1;33m"
RED="\e[1;31m"; CYAN="\e[1;36m"; MAGENTA="\e[1;35m"; BLUE="\e[1;34m"

log()  { echo -e "  ${CYAN}[*]${RST} $*"; }
ok()   { echo -e "  ${GREEN}[✓]${RST} $*"; }
warn() { echo -e "  ${YELLOW}[!]${RST} $*"; }
err()  { echo -e "  ${RED}[✗]${RST} $*"; }

# ── Domain check FIRST ────────────────────────────────────────────
TARGET_DOMAIN="$1"

if [[ -z "$TARGET_DOMAIN" ]]; then
    echo -e "Usage: ./runner.sh <domain>"
    exit 1
fi

# ── Dependency check ──────────────────────────────────────────────
for script in probe.sh recon_advisor.sh url_scout.sh js_scanner.sh; do
    if [[ ! -f "$script" ]]; then
        err "Missing required script: ${YELLOW}$script${RST}"
        exit 1
    fi
done

# ── Load cookie ───────────────────────────────────────────────────
COOKIE_STRING=""
if [[ -f "cookie_nmap.txt" ]]; then
    COOKIE_STRING=$(tr -d '\n\r' < cookie_nmap.txt)
    ok "Cookie loaded: ${DIM}${COOKIE_STRING:0:60}...${RST}"
else
    warn "cookie_nmap.txt not found — continuing without cookie"
fi
export COOKIE_STRING

# ── Phase 1: Scout (Subprobe) ─────────────────────────────────────
# Skip probe.sh untuk localhost/IP — terus buat live.txt
if echo "$TARGET_DOMAIN" | grep -qE "^(127\.|192\.|10\.|localhost)"; then
    warn "Local/IP target detected — skipping probe.sh"
    mkdir -p "recon_${TARGET_DOMAIN}"
    echo "http://${TARGET_DOMAIN}" > "recon_${TARGET_DOMAIN}/live.txt"
    ok "live.txt created: http://${TARGET_DOMAIN}"
else
    log "Starting Scout Phase..."
    COOKIE_STRING="$COOKIE_STRING" bash probe.sh "$TARGET_DOMAIN" -v -c 10 -f 200,301
fi

LIVE_FILE="./recon_${TARGET_DOMAIN}/live.txt"

# ── Phase 2: Validate live targets ───────────────────────────────
if [[ ! -f "$LIVE_FILE" ]] || [[ ! -s "$LIVE_FILE" ]]; then
    err "No live targets found in $LIVE_FILE"
    exit 1
fi

ok "Live targets found: $(wc -l < "$LIVE_FILE")"

# ── Phase 3: Recon Advisor ────────────────────────────────────────
log "Feeding live targets to Recon Advisor..."

while read -r line; do
    # Extract URL (strip |statuscode part)
    url=$(echo "$line" | cut -d'|' -f1)

    echo -e "\n${MAGENTA}>>> ANALYZING: $url <<<${RST}"

    # Non-interactive mode with -d flag
    COOKIE_STRING="$COOKIE_STRING" bash recon_advisor.sh -d "$url" || \
        warn "recon_advisor.sh failed for: $url"

    # Fix 3 — export ZIG_TARGET for intelijen_v3.sh
    export ZIG_TARGET="$url"

done < "$LIVE_FILE"

# ── Phase 3b: Launch intelijen_v3.sh ─────────────────────────────
if [[ -f "$BASE/intelijen_v3.sh" ]] && [[ -n "$ZIG_TARGET" ]]; then
    log "Handing off to intelijen_v3.sh → $ZIG_TARGET"
    export ZIG_TARGET
    export ZIG_DELAY="${ZIG_DELAY:-1}"
    COOKIE_STRING="$COOKIE_STRING" bash "$(cd "$(dirname "$0")" && pwd)/intelijen_v3.sh"
fi

# ── Phase 4: URL Scout ────────────────────────────────────────────
log "Running URL Scout..."
COOKIE_STRING="$COOKIE_STRING" bash url_scout.sh "$TARGET_DOMAIN" || \
    warn "url_scout.sh encountered an error"

# ── Phase 5: JS Scanner ───────────────────────────────────────────
log "Running JS Scanner..."
COOKIE_STRING="$COOKIE_STRING" bash js_scanner.sh "$TARGET_DOMAIN" || \
    warn "js_scanner.sh encountered an error"

echo -e "\n${GREEN}[✓] All targets processed. Recon complete for: ${CYAN}$TARGET_DOMAIN${RST}"
