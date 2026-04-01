import sys, requests, time, re

BASELINE_CACHE = {}

def get_baseline(base_url, headers):
    if base_url not in BASELINE_CACHE:
        try:
            # Use dummy path to get true error page baseline
            r = requests.get(base_url + "?path=baseline_dummy_zig", headers=headers, timeout=10)
            BASELINE_CACHE[base_url] = len(r.text)
        except:
            BASELINE_CACHE[base_url] = -1
    return BASELINE_CACHE[base_url]

def check_vulnerability(url, attack_type, external_baseline=None):
    try:
        headers = {"User-Agent": "JDT-Mobile-Strategist/1.0"}
        base_url = url.split("?")[0]
        baseline = int(external_baseline) if external_baseline else get_baseline(base_url, headers)

        start = time.time()
        res = requests.get(url, headers=headers, timeout=10)
        duration = time.time() - start
        content = res.text
        content_lower = content.lower()
        size = len(content)
        size_diff = abs(size - baseline) if baseline > 0 else 0

        # Skip 500 error pages — file not found, not a vuln
        if res.status_code == 500:
            return f"Skip (HTTP 500 | FileNotFound)"

        if attack_type == "lfi":
            if re.search(r'root:x:\d+:\d+:', content):
                return "VULNERABLE (LFI: /etc/passwd leaked)"
            if re.search(r"\w+::\d+:\d+:", content) or "localhost" in content:
                return "VULNERABLE (LFI: Android /etc/passwd leaked)"
            if "[extensions]" in content_lower or "boot loader" in content_lower:
                return "VULNERABLE (LFI: Windows file leaked)"
            if res.status_code == 200 and size_diff > 200:
                return f"ANOMALY (LFI: size diff={size_diff}B vs baseline={baseline}B)"

        elif attack_type in ("sqli", "sqli_blind"):
            if duration > 4.5:
                return f"VULNERABLE (SQLi Time-Based: {duration:.2f}s delay)"
            if any(e in content_lower for e in [
                "sql syntax", "mysql_fetch", "ora-0", "pg_query",
                "sqlite_", "unclosed quotation", "you have an error in your sql"
            ]):
                return "VULNERABLE (SQLi Error-Based)"
            if res.status_code == 200 and size_diff > 200:
                return f"ANOMALY (SQLi: size diff={size_diff}B)"

        elif attack_type == "xss":
            if "<script>alert" in content_lower or "onerror=" in content_lower:
                return "VULNERABLE (XSS Reflected)"
            if res.status_code == 200 and size_diff > 200:
                return f"ANOMALY (XSS: size diff={size_diff}B)"

        elif attack_type == "rce":
            if re.search(r"uid=\d+\(\w+\)", content):
                return "VULNERABLE (RCE: id command output detected)"
            if res.status_code == 200 and size_diff > 200:
                return f"ANOMALY (RCE: size diff={size_diff}B)"

        elif attack_type == "ssti":
            if "49" in content and "{{7*7}}" not in content:
                return "VULNERABLE (SSTI: math expression evaluated)"
            if res.status_code == 200 and size_diff > 200:
                return f"ANOMALY (SSTI: size diff={size_diff}B)"

        elif attack_type == "open_redirect":
            if res.url != url and ("evil.com" in res.url or "dsvw.c1.biz" in res.url):
                return f"VULNERABLE (Open Redirect → {res.url})"
            if res.history and res.history[0].status_code in (301, 302):
                return f"ANOMALY (Redirect chain: {res.history[0].status_code})"

        elif attack_type == "xxe":
            if re.search(r'root:x:\d+:\d+:', content):
                return "VULNERABLE (XXE: /etc/passwd in response)"
            if re.search(r"\w+::\d+:\d+:", content) or "localhost" in content:
                return "VULNERABLE (XXE: Android /etc/passwd in response)"
            if res.status_code == 200 and size_diff > 200:
                return f"ANOMALY (XXE: size diff={size_diff}B)"

        return f"Clean (HTTP {res.status_code} | Size: {size}B | Diff: {size_diff}B)"

    except requests.Timeout:
        return "Timeout (possible blind vuln — investigate manually)"
    except Exception as e:
        return f"Error: {str(e)}"

if __name__ == "__main__":
    if len(sys.argv) > 2:
        print(check_vulnerability(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None))
