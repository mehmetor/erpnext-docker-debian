#!/bin/bash
set -e

# -> Run entrypoint
# somehow when specify custom cmd in railway,
# it doesn't run entrypoint first, so we need to run it here.
sudo /usr/local/bin/railway-entrypoint.sh

echo "-> Create empty common site config"
echo "{}" > /home/frappe/bench/sites/common_site_config.json

echo "-> Create new site with ERPNext"
bench new-site ${RFP_DOMAIN_NAME} \
  --admin-password ${RFP_SITE_ADMIN_PASSWORD} \
  --mariadb-user-host-login-scope="%" \
  --db-root-password ${RFP_DB_ROOT_PASSWORD} \
  --install-app erpnext

bench use ${RFP_DOMAIN_NAME}

echo "-> Adding db_host and redis config to site_config"
bench --site ${RFP_DOMAIN_NAME} set-config db_host "${FRAPPE_DB_HOST}"
bench --site ${RFP_DOMAIN_NAME} set-config redis_cache "${FRAPPE_REDIS_CACHE}"
bench --site ${RFP_DOMAIN_NAME} set-config redis_queue "${FRAPPE_REDIS_QUEUE}"

echo "-> Adding redis_cache / redis_queue to common_site_config.json"
/home/frappe/bench/env/bin/python3 << 'PYEOF'
import json, os

path = "/home/frappe/bench/sites/common_site_config.json"
with open(path) as f:
    common = json.load(f)
common["redis_cache"] = os.environ["FRAPPE_REDIS_CACHE"]
common["redis_queue"] = os.environ["FRAPPE_REDIS_QUEUE"]
with open(path, "w") as f:
    json.dump(common, f, indent=1)
PYEOF
chown frappe:frappe /home/frappe/bench/sites/common_site_config.json

echo "-> Enable scheduler"
bench enable-scheduler
