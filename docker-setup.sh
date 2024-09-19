#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-only

print_usage() {
    echo "Usage: docker-setup.sh"
    exit 1
}

check_error() {
    if [ $1 -ne 0 ]; then
        echo "Failed $2"
        echo "Exiting..."
        exit 1
    fi
}

setup_init() {
echo "Cleaning previously started containers..."
./docker-tear-down.sh
echo "Docker pruning"
docker system prune -f
docker volume prune -f
}

setup_keycloak() {
./config/keycloak/certs/gen-certs.sh
echo "Starting containers for: keycloak"
docker compose -p security -f docker-compose-security.yaml up -d
}

populate_keycloak(){
# Create realm in keycloak
. scripts/populate_keycloak.sh

create_realms nonrtric-realm
while [ $? -ne 0 ]; do
    create_realms nonrtric-realm
done

# Create client for admin calls
cid="console-setup"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

echo ""

cid="console-setup"
__get_admin_token
TOKEN=$(get_client_token nonrtric-realm $cid)

cid="kafka-producer-pm-xml2json"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export XML2JSON_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

cid="pm-producer-json2kafka"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export JSON2KAFKA_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

cid="dfc"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export DFC_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)

cid="nrt-pm-log"
create_clients nonrtric-realm $cid
check_error $?
generate_client_secrets nonrtric-realm $cid
check_error $?

export PMLOG_CLIENT_SECRET=$(< .sec_nonrtric-realm_$cid)
}

setup_kafka() {
echo "Starting containers for: kafka, zookeeper, kafka client, minio"
docker compose -p msgbus -f docker-compose-msgbus.yaml up -d
}

create_docker_networks() {
echo "Creating Docker Netowrks: $DNETWORKS"
for net in $DNETWORKS; do
    docker network inspect $net 2> /dev/null 1> /dev/null
    if [ $? -ne 0 ]; then
        docker network create $net
    else
        echo "  Network: $net exits"
    fi
done
}

create_topics() {
echo "Creating topics: $TOPICS, may take a while ..."
for t in $TOPICS; do
    retcode=1
    rt=43200000
    echo "Creating topic $t with retention $(($rt/1000)) seconds"
    while [ $retcode -ne 0 ]; do
        docker exec -it common-kafka-1-1 ./bin/kafka-topics.sh \
		--create --topic $t --config retention.ms=$rt  --bootstrap-server kafka:9092
        retcode=$?
    done
done
}

## MAIN #####
export KAFKA_NUM_PARTITIONS=10
export TOPICS="file-ready collected-file json-file-ready-kp json-file-ready-kpadp pmreports"
export DNETWORKS="smo"

setup_init

create_docker_networks
check_error $?

setup_keycloak
check_error $?

# Wait for keycloak to start
echo 'Waiting for keycloak to be ready'
until [ $(curl -s -w '%{http_code}' -o /dev/null 'http://localhost:8462') -eq 200 ];
do
	echo -n '.'
	sleep 2
done
echo ""

populate_keycloak

setup_kafka
check_error $?

create_topics
