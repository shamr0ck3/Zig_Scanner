import requests
import sys
import time
import re

def check_honeypot(target):
    print(f"    [*] Analyzing {target} for deception signatures...")
    indicators = 0
    headers_to_check = ['X-Honeypot', 'X-Fake-Header', 'Server']
    
    try:
        # 1. Timing Analysis (Honeypots often have artificial delays)
        start_time = time.time()
        response = requests.get(target, timeout=10, headers={'User-Agent': 'Mozilla/5.0'})
        end_time = time.time()
        latency = end_time - start_time

        # 2. Server Header Inspection
        server_header = response.headers.get('Server', '').lower()
        suspicious_servers = ['cowrie', 'honey', 'dionaea', 'glastopf']
        if any(s in server_header for s in suspicious_servers):
            print("    [!] Found suspicious Server header signature.")
            indicators += 2

        # 3. Payload "Emulation" Check
        # We send a common exploit string; real WAFs block it, 
        # but some honeypots "accept" it to log the attacker.
        bogus_payload = target + "/?exec=/bin/bash"
        bogus_res = requests.get(bogus_payload, timeout=5)
        if bogus_res.status_code == 200 and "root:" in bogus_res.text:
            print("    [!] Target emulated a successful exploit (Classic Honeypot!)")
            indicators += 5

        # 4. TCP Fingerprint Consistency
        if latency < 0.001: # Too fast to be a real human-facing server
            indicators += 1

        if indicators >= 3:
            print(f"    [!] Honeypot detected: YES (Score: {indicators}/10)")
        else:
            print(f"    [✓] Honeypot detected: NO (Score: {indicators}/10)")

    except Exception as e:
        print(f"    [!] Connection Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        check_honeypot(sys.argv[1])
    else:
        print("Usage: python3 honeydetect.py <url>")
