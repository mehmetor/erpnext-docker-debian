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

echo "-> Bursting env into config"
envsubst '$RFP_DOMAIN_NAME' < /home/$systemUser/temp_nginx.conf > /etc/nginx/conf.d/default.conf
envsubst '$PATH,$HOME,$NVM_DIR,$NODE_VERSION' < /home/$systemUser/temp_supervisor.conf > /home/$systemUser/supervisor.conf

echo "-> Starting nginx"
nginx

echo "-> Starting supervisor"
/usr/bin/supervisord -c /home/$systemUser/supervisor.conf
