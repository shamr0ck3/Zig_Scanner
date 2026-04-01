import sys

def analyze_results(server, waf):
    print("\n[⚡] ZIG_ANALYSIS REPORT:")
    
    # Analyze Server Header
    if "Apache/2.4.7" in server:
        print("    [!] ALERT: Legacy Apache 2.4.7 detected (Ubuntu 14.04 era).")
        print("        Check for: CVE-2014-0226 or Heartbleed-related leaks.")
    
    # Analyze WAF
    if "detected" in waf.lower():
        print("    [i] ADVICE: Target is behind a WAF. Use slow timing (-T2) to avoid blocks.")
    else:
        print("    [+] ADVICE: No WAF detected. Faster fuzzing is safer here.")

if __name__ == "__main__":
    # Expects: server_header, waf_status
    if len(sys.argv) > 2:
        analyze_results(sys.argv[1], sys.argv[2])
