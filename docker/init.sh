#!/bin/bash

set -euo pipefail

log() {
    echo "[init] $*"
}

on_error() {
    local exit_code=$?
    local line_no=${1:-unknown}
    log "ERROR: command failed at line ${line_no} with exit code ${exit_code}"
    log "TIP: check MariaDB/Redis readiness and bench command output above"
    exit "${exit_code}"
}

trap 'on_error $LINENO' ERR

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    log "Bench already exists, skipping init and starting services"
    cd frappe-bench
    bench start
    exit 0
else
    log "Creating new bench..."
fi

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

bench init --skip-redis-config-generation frappe-bench

cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app erpnext
bench get-app hrms

bench new-site hrms.localhost \
--force \
--mariadb-root-password 123 \
--admin-password admin \
--no-mariadb-socket

bench --site hrms.localhost install-app hrms
bench --site hrms.localhost set-config developer_mode 1
bench --site hrms.localhost enable-scheduler
bench --site hrms.localhost clear-cache
bench use hrms.localhost

log "Initialization complete, starting bench services"
bench start
