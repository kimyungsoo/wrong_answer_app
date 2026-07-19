import os
import requests
import time
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')

CF_TOKEN = os.environ.get("CF_TOKEN", "")
ZONE_ID = os.environ.get("CF_ZONE_ID", "4b6a2134d3b351eafb846fead4e0b568")
RECORD_ID = os.environ.get("CF_RECORD_ID", "c04ea216d60dce30149950e8a8a43247")
DOMAIN = "wronganswerapp.com"
CHECK_INTERVAL = 300  # 5분마다 체크

HEADERS = {
    "Authorization": f"Bearer {CF_TOKEN}",
    "Content-Type": "application/json",
}


def get_public_ip():
    return requests.get("https://api.ipify.org", timeout=10).text.strip()


def get_dns_ip():
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records/{RECORD_ID}"
    r = requests.get(url, headers=HEADERS, timeout=10)
    return r.json()["result"]["content"]


def update_dns(ip):
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records/{RECORD_ID}"
    data = {"type": "A", "name": "@", "content": ip, "ttl": 1, "proxied": False}
    r = requests.put(url, headers=HEADERS, json=data, timeout=10)
    return r.json()["success"]


def main():
    logging.info(f"DDNS 시작 - {DOMAIN}")
    while True:
        try:
            public_ip = get_public_ip()
            dns_ip = get_dns_ip()
            if public_ip != dns_ip:
                success = update_dns(public_ip)
                if success:
                    logging.info(f"IP 업데이트: {dns_ip} → {public_ip}")
                else:
                    logging.error("IP 업데이트 실패")
            else:
                logging.info(f"IP 변동 없음: {public_ip}")
        except Exception as e:
            logging.error(f"오류: {e}")
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
