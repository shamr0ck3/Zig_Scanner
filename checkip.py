import requests, sys, json
def get_geo(ip):
    try:
        r = requests.get(f"http://ip-api.com/json/{ip}")
        print(json.dumps(r.json(), indent=4))
    except:
        print('{"error": "Failed to fetch geo data"}')
if __name__ == "__main__":
    get_geo(sys.argv[1] if len(sys.argv) > 1 else "")
