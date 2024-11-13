#!/usr/bin/env bash

# Configure application defaults
export HOST_NAME=${HOST_NAME:-${MDNS_HOSTNAME}}
export ADVERTISED_HOST_NAME=${ADVERTISED_HOST_NAME:-${MDNS_HOSTNAME}}
export ADVERTISED_PORT=${ADVERTISED_PORT:-'80'}
export REST_HOST_NAME=${REST_HOST_NAME:-'0.0.0.0'}
export REST_PORT=${REST_PORT:-'80'}
export CONNECT_ACCESS_CONTROL_ALLOW_ORIGIN=${CONNECT_ACCESS_CONTROL_ALLOW_ORIGIN:-'GET,POST,PUT,DELETE'}
export CONNECT_ACCESS_CONTROL_ALLOW_HEADERS=${CONNECT_ACCESS_CONTROL_ALLOW_HEADERS:-'origin,content-type,accept,authorization'}

# Kafka bootstrap servers (host:port,host:port)
export BOOTSTRAP_SERVERS=${BOOTSTRAP_SERVERS:-'kafka.local:9092'}

# ID that uniquely identifies the Kafka Connect cluster the service and
# its workers belong to.
export GROUP_ID=${GROUP_ID:-'1'}

# This environment variable is required when running the Kafka Connect service.
# Set this to the name of the Kafka topic where the Kafka Connect services in
# the group store connector configurations. The topic must have a single
# partition and be highly replicated (e.g., 3x or more).
export CONFIG_STORAGE_TOPIC=${CONFIG_STORAGE_TOPIC:-'debezium.configs'}

# This environment variable is required when running the Kafka Connect service.
# Set this to the name of the Kafka topic where the Kafka Connect services in
# the group store connector offsets. The topic must have a large number of
# partitions (e.g., 25 or 50), be highly replicated (e.g., 3x or more) and
# should be configured for compaction.
export OFFSET_STORAGE_TOPIC=${OFFSET_STORAGE_TOPIC:-'debezium.offsets'}

# This environment variable should be provided when running the Kafka Connect
# service. Set this to the name of the Kafka topic where the Kafka Connect
# services in the group store connector status. The topic can have multiple
# partitions, should be highly replicated (e.g., 3x or more) and should be
# configured for compaction.
export STATUS_STORAGE_TOPIC=${STATUS_STORAGE_TOPIC:-'debezium.statuses'}

# Run the hooks inside the given directory. Each file is treated as
# runable/sourceable. The execution order can be adjusted with left-padded
# numbering of the filenames/directories.
#
# We automatically try to load the given directory inside the +/app/config/+
# directory as a convention. So when +/container/configure.d+ is given, we also
# try to load hooks from +/app/config/container/configure.d+.
#
# $1 - the directory to search for hooks
# $n - additional arguments
function run-hooks()
{
  # This ensure that regular +exit+/+exit 0+ calls within the sourced hook
  # files will not produce an exit code 1. This seems to be a special case in
  # combination with the +set -e+ fail-safe flag.
  unset SHLVL

  # Try the given directory (if one) first
  if [ -d "${1}" ]; then
    for FILE in $(find "${1}" -type f | sort -n); do
      source "${FILE}"
    done
  fi
}

# Run before start hooks
run-hooks '/hooks/start.pre.d'

# Spin up a sub-shell to await the application start and run after-start hooks
(
  await-kafka-connect
  run-hooks '/hooks/start.post.d'
) &

# Start the original bootstrapping
exec /docker-entrypoint.sh start
