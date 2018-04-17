#!/bin/bash

set -x
DATE=$(date)
LOG_DIR=/var/log/openstack_maintenance
LOG_NAME=$LOG_DIR/purge_openstack_databases.log
KEEP_DAYS=7
MAX_ROWS=99999

MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p $LOG_DIR

function main_function {

  echo "=================================================================="
  echo "Starting the database clean-up at $DATE"
  echo "=================================================================="

  glance-manage --verbose db purge --age_in_days $KEEP_DAYS --max_rows $MAX_ROWS

  heat-manage --verbose purge_deleted $KEEP_DAYS

  keystone-manage --verbose token_flush

  mysql -vvv < $MY_DIR/purge_cinder_database.sql

  mysql -vvv < $MY_DIR/purge_nova_database.sql

  mysql -vvv < $MY_DIR/purge_nova_api_database.sql
}

main_function 2>&1 | tee --append $LOG_NAME
