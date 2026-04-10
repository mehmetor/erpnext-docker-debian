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

echo "-> Enable scheduler"
bench enable-scheduler
