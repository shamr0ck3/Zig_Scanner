#!/bin/bash
# js_scanner.sh v2.2 - JDT-Mobile Hardened
# Part of Zig_Scanner Suite | shamr0ck3

domain=$1
[[ -z $domain ]] && { echo -e "\e[1;31m[!] Usage: $0 <domain>\e[0m"; exit 1; }
domain=$(echo "$domain" | sed -E "s|^https?://||" | cut -d/ -f1)

DIR="recon_${domain}"
LEAK_FILE="$DIR/js_leaks.txt"
JS_LIST="$DIR/juicy_urls.txt"

[[ ! -f "$JS_LIST" ]] && { echo -e "\e[1;31m[!] $JS_LIST not found. Run url_scout.sh first.\e[0m"; exit 1; }

echo -e "\e[1;34m[*] Deep Scanning JS for: $domain...\e[0m"
echo "--- JS SCAN REPORT FOR $domain ---" > "$LEAK_FILE"
echo "Scanned: $(date)" >> "$LEAK_FILE"
echo "" >> "$LEAK_FILE"

# ──────────────────────────────────────────
# FIX 3: Filter noise libraries dulu sebelum loop
# ──────────────────────────────────────────
FILTERED_JS=$(grep -i "\.js" "$JS_LIST" \
    | grep -vE "jquery|bootstrap|analytics|wp-includes|gtag|font-awesome|lodash|moment\.js|react\.min|vue\.min|polyfill")

TOTAL=$(echo "$FILTERED_JS" | grep -c ".")
COUNT=0
FOUND_COUNT=0

echo -e "\e[1;33m[*] $TOTAL JS files queued (noise filtered)\e[0m\n"

# ──────────────────────────────────────────
# FIX 1: while read -r — lebih stabil dari for loop
# ──────────────────────────────────────────
echo "$FILTERED_JS" | while read -r url; do
    [[ -z "$url" ]] && continue
    COUNT=$((COUNT + 1))
    BASENAME=$(basename "$url" | cut -c1-40)  # truncate nama panjang

    echo -ne "\e[1;30m  [${COUNT}/${TOTAL}] Analyzing: ${BASENAME}\e[0m\r"

    # ──────────────────────────────────────
    # FIX 2: Timeout — tak tersangkut pada dead JS
    # ──────────────────────────────────────
    content=$(curl -s -L \
        --max-time 10 \
        --connect-timeout 5 \
        -b "${COOKIE_STRING:-}" \
        --user-agent "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36" \
        "$url" 2>/dev/null)

    [[ -z "$content" ]] && continue

    # ──────────────────────────────────────
    # Regex hunt — dengan context lines (-B1 -A1)
    # ──────────────────────────────────────
    found=$(echo "$content" | grep -Ei \
        --color=never \
        -B1 -A1 \
        "api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|\
bearer\s+[a-z0-9]{20,}|password\s*[:=]|passwd\s*[:=]|\
gist\.github\.com|/([a-zA-Z0-9_-]{3,}/){2,}|\
https?://[a-z0-9.-]+\.(internal|local|corp|dev|staging|test)" \
        | sort -u)  # sort -u buang duplicate lines

    if [[ -n "$found" ]]; then
        FOUND_COUNT=$((FOUND_COUNT + 1))
        echo -e "\n\e[1;32m[!] HIT [${COUNT}/${TOTAL}]: $(basename "$url")\e[0m"
        {
            echo "SOURCE: $url"
            echo "======================================"
            echo "$found" | sed 's/^[[:space:]]*//'
            echo -e "======================================\n"
        } >> "$LEAK_FILE"
    fi
done

echo -e "\n\e[1;32m[✓] Scan complete! $FOUND_COUNT/$TOTAL files had findings.\e[0m"
echo -e "\e[1;33m[→] Check: $LEAK_FILE\e[0m"
