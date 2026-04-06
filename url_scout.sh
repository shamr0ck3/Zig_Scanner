#!/bin/bash
# url_scout.sh v2.2 - JDT-Mobile Hardened
# Part of Zig_Scanner Suite | shamr0ck3

domain=$1
[[ -z $domain ]] && { echo -e "\e[1;31m[!] Usage: $0 <domain>\e[0m"; exit 1; }
domain=$(echo "$domain" | sed -E "s|^https?://||" | cut -d/ -f1)

DIR="recon_${domain}"
mkdir -p "$DIR"  # Selamat walaupun probe.sh belum run

WAYBACK="$DIR/wayback_urls.txt"
JUICY="$DIR/juicy_urls.txt"
SENSITIVE="$DIR/sensitive_params.txt"

echo -e "\e[1;34m[*] Digging Wayback Machine for: $domain...\e[0m"

# ──────────────────────────────────────────
# FIX 1: HTTPS + timeout + error handling untuk CDX API
# ──────────────────────────────────────────
RAW_JSON=$(curl -s -L \
    --max-time 30 \
    --connect-timeout 10 \
    -b "${COOKIE_STRING:-}" \
    "https://web.archive.org/cdx/search/cdx?url=*.${domain}/*&output=json&fl=original&collapse=urlkey&limit=5000")

# ──────────────────────────────────────────
# FIX 2: Validate JSON sebelum pipe ke jq
# ──────────────────────────────────────────
if [[ -z "$RAW_JSON" ]] || ! echo "$RAW_JSON" | jq -e . > /dev/null 2>&1; then
    echo -e "\e[1;31m[!] CDX API returned no data or invalid JSON for: $domain\e[0m"
    echo -e "\e[1;33m[?] Domain mungkin di-exclude dari Wayback, atau tiada rekod.\e[0m"
    exit 1
fi

# FIX 3: jq dengan error guard — skip baris "original" (header) dengan .[1:][]
echo "$RAW_JSON" \
    | jq -r 'if length > 1 then .[1:][] | .[0] else empty end' 2>/dev/null \
    > "$WAYBACK"

count=$(wc -l < "$WAYBACK")

if [[ "$count" -eq 0 ]]; then
    echo -e "\e[1;33m[!] Wayback ada rekod tapi tiada URL berjaya diekstrak.\e[0m"
    exit 1
fi

echo -e "\e[1;32m[+] Found $count URLs! Saved to $WAYBACK\e[0m"

# ──────────────────────────────────────────
# Filter juicy endpoints
# ──────────────────────────────────────────
echo -e "\e[1;33m[*] Filtering juicy endpoints...\e[0m"

grep -E "\.js$|\.json$|\.php$|\.aspx$|\.config$|\.bak$|\.env$|\.xml$|api" \
    "$WAYBACK" \
    | grep -vE "jquery|bootstrap|analytics|wp-includes|gtag" \
    > "$JUICY"

juicy_count=$(wc -l < "$JUICY")
echo -e "\e[1;32m[+] $juicy_count juicy endpoints filtered → $JUICY\e[0m"

# ──────────────────────────────────────────
# Pro-tip: Hunt sensitive URL params
# ──────────────────────────────────────────
echo -e "\e[1;31m[*] Hunting sensitive URL parameters...\e[0m"

grep -iE "user=|pass=|pwd=|token=|apikey=|api_key=|secret=|admin=|auth=|login=|redirect=|url=|next=" \
    "$WAYBACK" \
    > "$SENSITIVE"

sensitive_count=$(wc -l < "$SENSITIVE")

if [[ "$sensitive_count" -gt 0 ]]; then
    echo -e "\e[1;31m[!] $sensitive_count sensitive parameter URLs found → $SENSITIVE\e[0m"
else
    echo -e "\e[1;30m[-] No sensitive params found in URL patterns.\e[0m"
fi

# ──────────────────────────────────────────
# Summary
# ──────────────────────────────────────────
echo ""
echo -e "\e[1;34m╔══ url_scout.sh Summary ══════════════╗\e[0m"
echo -e "\e[1;34m║\e[0m Total URLs     : \e[1;32m$count\e[0m"
echo -e "\e[1;34m║\e[0m Juicy endpoints: \e[1;33m$juicy_count\e[0m"
echo -e "\e[1;34m║\e[0m Sensitive params: \e[1;31m$sensitive_count\e[0m"
echo -e "\e[1;34m╚══════════════════════════════════════╝\e[0m"
