#!/bin/sh
set -e

echo "-> Clearing cache"
if [ -f /home/frappe/bench/sites/common_site_config.json ]; then
  DEFAULT_SITE=$(cat /home/frappe/bench/sites/common_site_config.json | python3 -c "import sys,json; print(json.load(sys.stdin).get('default_site',''))" 2>/dev/null || echo "")
  if [ -n "$DEFAULT_SITE" ] && [ -d "/home/frappe/bench/sites/$DEFAULT_SITE" ]; then
    su frappe -c "bench execute frappe.cache_manager.clear_global_cache" || echo "-> Cache clear skipped (site may not be ready)"
  else
    echo "-> No site found, skipping cache clear"
  fi
else
  echo "-> No common_site_config.json, skipping cache clear"
fi

# Frappe, hash'li asset URL'lerini Redis'teki assets_json ile tutarlı tutar. Docker build
# sırasında Redis yok; bu yüzden yeni image ile diskteki assets.json güncellenir ama Redis
# eski kalır → CSS/JS 404. Her başlangıçta diskteki mapping'i cache Redis'ine yaz.
echo "-> Syncing assets_json to Redis from sites/assets/assets.json"
if [ -f /home/frappe/bench/sites/assets/assets.json ] && [ -n "${FRAPPE_REDIS_CACHE:-}" ]; then
  /home/frappe/bench/env/bin/python3 << 'PYEOF'
import json, os, pickle, sys

try:
    import redis
except ImportError:
    print("-> redis Python paketi yok, assets_json senkronu atlanıyor")
    sys.exit(0)

url = os.environ.get("FRAPPE_REDIS_CACHE", "")
if not url:
    sys.exit(0)

try:
    conn = redis.Redis.from_url(url, decode_responses=False)
    with open("/home/frappe/bench/sites/assets/assets.json") as f:
        assets = json.load(f)
    conn.set("assets_json", pickle.dumps(assets))
    print("-> assets_json Redis ile senkronize edildi")
except Exception as e:
    print("-> assets_json senkronu başarısız (devam ediliyor):", e)
PYEOF
else
  echo "-> assets.json veya FRAPPE_REDIS_CACHE yok; assets_json senkronu atlandı"
fi

echo "-> Bursting env into config"
envsubst '$RFP_DOMAIN_NAME' < /home/$systemUser/temp_nginx.conf > /etc/nginx/conf.d/default.conf
envsubst '$PATH,$HOME,$NVM_DIR,$NODE_VERSION' < /home/$systemUser/temp_supervisor.conf > /home/$systemUser/supervisor.conf

echo "-> Starting nginx"
nginx

echo "-> Starting supervisor"
/usr/bin/supervisord -c /home/$systemUser/supervisor.conf
