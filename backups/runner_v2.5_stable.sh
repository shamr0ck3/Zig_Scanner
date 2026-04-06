#!/usr/bin/env bash
# runner.sh — The Pipeline Connector (Fixed for double scheme)

TARGET_DOMAIN=$1
if [[ -z "$TARGET_DOMAIN" ]]; then
    echo "Usage: ./runner.sh <domain>"
    exit 1
fi

# 1. Run the Scout (Subprobe) - Using HEAD requests for speed
echo -e "\e[1;34m[*] Starting Scout Phase (HEAD requests)...\e[0m"
bash probe.sh "$TARGET_DOMAIN" -v -s -c 10 -f 200,301

LIVE_FILE="./recon_${TARGET_DOMAIN}/live.txt"

# 2. Check if we found anything
if [[ ! -f "$LIVE_FILE" ]] || [[ ! -s "$LIVE_FILE" ]]; then
    echo -e "\e[1;31m[!] No live targets found in $LIVE_FILE\e[0m"
    exit 1
fi

# 3. Feed to Recon Advisor (without double scheme)
echo -e "\e[1;32m[*] Feeding live targets to Recon Advisor...\e[0m"

while read -r line; do
    # Extract just the URL (remove the |200 status part)
    url=$(echo "$line" | cut -d'|' -f1)
    
    # Remove scheme (http:// or https://) because recon_advisor.sh will re-detect
    # This prevents double scheme like https://https://example.com
    clean_url=$(echo "$url" | sed -E 's|^https?://||')
    
    echo -e "\n\e[1;35m>>> ANALYZING: $clean_url <<<\e[0m"
    
    # Feed: URL (without scheme) + n (skip test sites) + n (skip fuzzer)
    echo -e "$clean_url\nn\nn" | bash recon_advisor.sh
    
done < "$LIVE_FILE"

./url_scout.sh "$1"
echo -e "\n\e[1;32m[✓] All targets processed.\e[0m"
