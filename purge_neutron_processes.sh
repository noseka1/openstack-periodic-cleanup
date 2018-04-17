#!/bin/bash

DATE=$(date)
LOG_DIR=/var/log/openstack_maintenance
LOG_NAME=$LOG_DIR/purge_neutron_processes.log

EXTERNAL_PID_DIR=/var/lib/neutron/external/pids
ROUTER_PID_DIR=/var/lib/neutron/ha_confs
LBAAS_PID_DIR=/var/lib/neutron/lbaas

KEEPALIVED=keepalived
KEEPALIVED_STATE_CHANGE=/usr/bin/neutron-keepalived-state-change
NS_METADATA_PROXY=/usr/bin/neutron-ns-metadata-proxy
HAPROXY=haproxy

NEUTRON_LOG_DIR=/var/log/neutron
NEUTRON_LOCK_DIR=/var/lib/neutron/lock
NEUTRON_DHCP_DIR=/var/lib/neutron/dhcp

MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure ip command is on the path
export PATH=$PATH:/usr/sbin

mkdir -p $LOG_DIR

function kill_process_safely {

  PID_FILE=$1
  NAME=$2
  NAME_POS=$3
  MSG=$4

  PID=$(cat $PID_FILE)
  ARG=$(cat /proc/$PID/cmdline | cut -d "$(echo -e '\000')" -f $NAME_POS)
  if [ "$ARG" = "$NAME" ]; then
    echo $DATE $MSG
    kill -SIGKILL $PID
    echo $DATE Deleting pid file $PID_FILE
    rm -f $PID_FILE
  fi

}

function purge_neutron_routers {

  # This function kills all the keepalived and neutron-keepalived-state-change processes whose
  # Neutron router doesn't exist anymore

  # Example process group to purge (up to 3 processes per router):
  # /usr/bin/python2 /usr/bin/neutron-keepalived-state-change --router_id=5f41f474-d14d-4a16-b9c3-7ef2e5ab0335 --namespace=qrouter-5f41f474-d14d-4a16-b9c3-7ef2e5ab0335 --conf_dir=/var/lib/neutron/ha_confs/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335 --monitor_interface=ha-52974943-e5 --monitor_cidr=169.254.0.1/24 --pid_file=/var/lib/neutron/external/pids/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335.monitor.pid --state_path=/var/lib/neutron --user=988 --group=985
  # /var/lib/neutron/ha_confs/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335/keepalived.conf -p /var/lib/neutron/ha_confs/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335.pid -r /var/lib/neutron/ha_confs/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335.pid-vrrp
  # /var/lib/neutron/ha_confs/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335/keepalived.conf -p /var/lib/neutron/ha_confs/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335.pid -r /var/lib/neutron/ha_confs/5f41f474-d14d-4a16-b9c3-7ef2e5ab0335.pid-vrrp

  for PID_FILE in $(ls -1 $ROUTER_PID_DIR/*.pid $ROUTER_PID_DIR/*.pid-vrrp $EXTERNAL_PID_DIR/*.monitor.pid); do
    UUID=$(echo $PID_FILE | grep -o '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}')

    DB_UUID=$(mysql -NBe "SELECT id FROM ovs_neutron.routers WHERE id='$UUID'")

    if [ $? -ne 0 ]; then
      echo "$DATE Database connection failure"
      return 1
    fi

    if [ -z "$DB_UUID" ]; then

      kill_process_safely $PID_FILE $KEEPALIVED_STATE_CHANGE 2 "Purging $KEEPALIVED_STATE_CHANGE process for non-existing HA router $UUID"
      kill_process_safely $PID_FILE $KEEPALIVED 1 "Purging keepalived process for non-existing HA router $UUID" # this will actually kill two processes

      CONF_DIR=$ROUTER_PID_DIR/$UUID
      if [ -d $CONF_DIR ]; then
        echo $DATE Deleting directory $CONF_DIR
        rm -r $CONF_DIR
      fi
    fi
  done

}

function purge_neutron_ns_metadata_proxy {

  # This function kills all the neutron-ns-metadata-proxy processes whose
  # Neutron network doesn't exist anymore

  # Example process to purge (1 process per network)
  # /usr/bin/python2 /usr/bin/neutron-ns-metadata-proxy --pid_file=/var/lib/neutron/external/pids/e01cd013-8858-4744-b233-07c683669ac6.pid --metadata_proxy_socket=/var/lib/neutron/metadata_proxy --network_id=e01cd013-8858-4744-b233-07c683669ac6 --state_path=/var/lib/neutron --metadata_port=80 --metadata_proxy_user=988 --metadata_proxy_group=985 --log-file=neutron-ns-metadata-proxy-e01cd013-8858-4744-b233-07c683669ac6.log --log-dir=/var/log/neutron

  for PID_FILE in $(ls -1 $EXTERNAL_PID_DIR/*.pid); do
    UUID=$(echo $PID_FILE | grep -o '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}')

    DB_UUID=$(mysql -NBe "SELECT id FROM ovs_neutron.networks WHERE id='$UUID'")

    if [ $? -ne 0 ]; then
      echo "$DATE Database connection failure"
      return 1
    fi

    if [ -z "$DB_UUID" ]; then

      kill_process_safely $PID_FILE $NS_METADATA_PROXY 2 "Purging neutron-ns-metadata-proxy for non-existing network $UUID"

      PURGE_LOG_FILE=$NEUTRON_LOG_DIR/neutron-ns-metadata-proxy-$UUID.log
      if [ -f $PURGE_LOG_FILE ]; then
        echo $DATE Deleting $PURGE_LOG_FILE
        rm $PURGE_LOG_FILE
      fi
    fi
  done

}

function purge_neutron_lbaas {

  # This function kills all the haproxy processes whose
  # loadbalancer pool doesn't exist anymore

  # Example process to purge (1 process per pool):
  # haproxy -f /var/lib/neutron/lbaas/7e517454-4718-4e7a-bad6-d989f8661e62/conf -p /var/lib/neutron/lbaas/7e517454-4718-4e7a-bad6-d989f8661e62/pid -sf 18676

  # check if there's any loadbalancer pool
  ls -1 $LBAAS_PID_DIR/*/pid 2>/dev/null || return 0

  for PID_FILE in $(ls -1 $LBAAS_PID_DIR/*/pid); do
    UUID=$(echo $PID_FILE | grep -o '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}')

    DB_UUID=$(mysql -NBe "SELECT id FROM ovs_neutron.pools WHERE id='$UUID'")

    if [ $? -ne 0 ]; then
      echo "$DATE Database connection failure"
      return 1
    fi

    if [ -z "$DB_UUID" ]; then

      kill_process_safely $PID_FILE $HAPROXY 1 "Purging haproxy for non-existing loadbalancer pool $UUID"

      CONF_DIR=$LBAAS_PID_DIR/$UUID
      if [ -d $CONF_DIR ]; then
        echo $DATE Deleting directory $CONF_DIR
        rm -r $CONF_DIR
      fi
    fi
  done

}

function purge_ip_monitor_address {

  # This function kills all the ip processes whose HA router doesn't exist anymore

  for PID in $(ps aux | grep -- 'ip -o monitor address' | awk '{ print $2 }'); do
    PARENT=$(ps -o ppid= $PID | xargs)
    if [ x$PARENT = x1 ]; then
      # The parent of this process is not neutron-keepalived-state-change -> kill it
      echo $DATE Purging ip process PID=$PID whose HA router does not exist
      kill $PID
    fi
  done
}

function delete_ports {

  NAMESPACE=$1

  declare -a PATTERNS=('tap[0-9a-f]\{8\}-[0-9a-f]\{2\}' 'qr-[0-9a-f]\{8\}-[0-9a-f]\{2\}' 'qg-[0-9a-f]\{8\}-[0-9a-f]\{2\}' 'ha-[0-9a-f]\{8\}-[0-9a-f]\{2\}')

  for PATTERN in "${PATTERNS[@]}"; do
    IF=$(ip netns exec $NAMESPACE ip link | grep -o "$PATTERN")
    if [ -n "$IF" ]; then
      echo Namespace $NAMESPACE: Deleting interface $IF
      ovs-vsctl del-port $IF
    fi
  done

}

function delete_namespace_safely {

  NAMESPACE=$1
  TABLE=$2

  UUID=$(echo $NAMESPACE | grep -o '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}')

  DB_UUID=$(mysql -NBe "SELECT id FROM $TABLE WHERE id='$UUID'")

  if [ $? -ne 0 ]; then
    echo "$DATE Database connection failure"
    return 1
  fi

  if [ -z "$DB_UUID" ]; then
    # Nobody is using the namespace -> remove the namespace
    echo $DATE Purging ip namespace $NAMESPACE
    # Delete all ports found in this namespace
    delete_ports $NAMESPACE
    # Delete the namespace itself
    ip netns delete $NAMESPACE
  fi

}

function purge_network_namespaces {

  # This function removes ip namespaces that are not used anymore.
  # Note that the qlbaas namespace is created only when a VIP is created for
  # the given pool

  for NAMESPACE in $(ip netns | grep '^qlbaas'); do
    delete_namespace_safely $NAMESPACE ovs_neutron.pools
  done

  for NAMESPACE in $(ip netns | grep '^qdhcp'); do
    delete_namespace_safely $NAMESPACE ovs_neutron.networks
  done

  for NAMESPACE in $(ip netns | grep '^qrouter'); do
    delete_namespace_safely $NAMESPACE ovs_neutron.routers
  done
}

function delete_file_safely {

  FILE=$1
  TABLE=$2

  UUID=$(echo $FILE | grep -o '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}')

  DB_UUID=$(mysql -NBe "SELECT id FROM $TABLE WHERE id='$UUID'")

  if [ $? -ne 0 ]; then
    echo "$DATE Database connection failure"
    return 1
  fi

  if [ -z "$DB_UUID" ]; then
    echo "$DATE Deleting file $FILE"
    rm -rf $FILE
  fi
}

function purge_stalled_files {

  # This was causing neutron-l3-agent to generate GBs of logs
  #for LOCK_FILE in $NEUTRON_LOCK_DIR/neutron-iptables-qrouter-*; do
  #  delete_file_safely $LOCK_FILE ovs_neutron.routers
  #done

  for LOCK_FILE in $NEUTRON_LOCK_DIR/neutron-iptables-qdhcp-*; do
    delete_file_safely $LOCK_FILE ovs_neutron.networks
  done

  for LOG_FILE in $NEUTRON_LOG_DIR/neutron-ns-metadata-proxy-*; do
    delete_file_safely $LOG_FILE ovs_neutron.networks
  done

  for DHCP_DIR in $NEUTRON_DHCP_DIR/*; do
    delete_file_safely $DHCP_DIR ovs_neutron.networks
  done

}

function main_function {

  echo $DATE Purge start

  purge_neutron_routers

  purge_neutron_ns_metadata_proxy

  purge_neutron_lbaas

  purge_ip_monitor_address

  purge_network_namespaces

  purge_stalled_files

  echo $DATE Purge end
}

main_function 2>&1 | tee --append $LOG_NAME
