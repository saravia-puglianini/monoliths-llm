import os
import sys
import json
import urllib.request
import base64

CONFIG_PATH = os.path.expanduser("~/.justificar/jira_config")

def load_config():
    config = {}
    with open(CONFIG_PATH, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                val = val.strip().strip('"').strip("'")
                config[key.strip()] = val
    return config

def main():
    config = load_config()
    key = sys.argv[1] if len(sys.argv) > 1 else "FU-9605"
    url = f"{config['JIRA_DOMAIN'].rstrip('/')}/rest/api/3/issue/{key}"
    auth_str = f"{config['JIRA_EMAIL']}:{config['JIRA_API_TOKEN']}"
    auth_b64 = base64.b64encode(auth_str.encode("utf-8")).decode("utf-8")
    
    headers = {
        "Authorization": f"Basic {auth_b64}",
        "Accept": "application/json"
    }
    
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode("utf-8"))
            
            # Print parent, epic, issue type and links
            fields = data.get("fields", {})
            print("Issue Type:", fields.get("issuetype", {}).get("name"))
            print("Parent in fields:", fields.get("parent", {}).get("key"), fields.get("parent", {}).get("fields", {}).get("summary"))
            
            # Print links
            print("\nIssue Links:")
            for link in fields.get("issuelinks", []):
                inward = link.get("inwardIssue", {})
                outward = link.get("outwardIssue", {})
                print(f"  Type: {link.get('type', {}).get('name')}")
                if inward:
                    print(f"    Inward: {inward.get('key')} ({inward.get('fields', {}).get('summary')})")
                if outward:
                    print(f"    Outward: {outward.get('key')} ({outward.get('fields', {}).get('summary')})")
                    
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()
