![mDNS enabled Debezium Connect](https://raw.githubusercontent.com/hausgold/docker-debezium-connect/master/docs/assets/project.svg)

[![Continuous Integration](https://github.com/hausgold/docker-debezium-connect/actions/workflows/package.yml/badge.svg?branch=master)](https://github.com/hausgold/docker-debezium-connect/actions/workflows/package.yml)
[![Source Code](https://img.shields.io/badge/source-on%20github-blue.svg)](https://github.com/hausgold/docker-debezium-connect)
[![Docker Image](https://img.shields.io/badge/image-on%20docker%20hub-blue.svg)](https://hub.docker.com/r/hausgold/debezium-connect/)

This Docker images provides the
[quay.io/debezium/connect](https://quay.io/debezium/connect) image as base with
the mDNS/ZeroConf stack on top.  So you can enjoy [Debezium
Connect](https://debezium.io/documentation/reference/stable/architecture.html)
while it is accessible by default as *debezium-connect.local* (Port 80, 8083)
as a single-node [Kafka
Connect](https://kafka.apache.org/documentation/#connect) cluster.

- [Requirements](#requirements)
- [Getting starting](#getting-starting)
- [Host configs](#host-configs)
- [Configure a different mDNS hostname](#configure-a-different-mdns-hostname)
- [Other top level domains](#other-top-level-domains)
- [Further reading](#further-reading)

## Requirements

* Host enabled Avahi daemon
* Host enabled mDNS NSS lookup

## Getting starting

To get a single-node [Kafka
Connect](https://kafka.apache.org/documentation/#connect) cluster up and
running create a `docker-compose.yml` and insert the following snippet:

```yaml
services:
  debezium-connect:
    image: hausgold/debezium-connect
    volumes:
      # This directory may contain Bash scripts which are executed once the
      # Kafka Connect REST API is available - to register connectors
      - ./debezium-connectors:/hooks/start.post.d
    environment:
      # Just the defaults
      MDNS_HOSTNAME: debezium-connect.local
      # Do not include the table schema on the event messages. This must be set
      # on the Debezium Connect instance, not on a per-connector base.
      # CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE: 'false'
      # CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE: 'false'

  postgres:
    image: hausgold/postgres
    environment:
      POSTGRES_DB: source
      # This is needed for Debezium/pgoutput to work
      POSTGRES_ARGS: -c wal_level=logical
      # Just the defaults:
      MDNS_HOSTNAME: postgres.local
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres

  kafka:
    image: hausgold/kafka
    environment:
      MDNS_HOSTNAME: kafka.local
      # See: http://bit.ly/2UDzgqI for Kafka downscaling
      KAFKA_HEAP_OPTS: -Xmx256M -Xms32M
    ulimits:
      # Due to systemd/pam RLIMIT_NOFILE settings (max int inside the
      # container), the Java process seams to allocate huge limits which result
      # in a +unable to allocate file descriptor table - out of memory+ error.
      # Lowering this value fixes the issue for now.
      #
      # See: http://bit.ly/2U62A80
      # See: http://bit.ly/2T2Izit
      nofile:
        soft: 100000
        hard: 100000
```

Create the `debezium-connectors/` directory and place a `my-connector` file
with the following contents in it:

```shell
#!/usr/bin/env bash

register-pg-connector \
  'my-connector' \
  database.dbname='source' \
  table.include.list='public.table_a,public.table_b'

# Re-route all events to a single Apache Kafka topic
# transforms='Reroute' \
# transforms.Reroute.type='io.debezium.transforms.ByLogicalTableRouter' \
# transforms.Reroute.topic.regex='.*' \
# transforms.Reroute.topic.replacement='my-single-topic' \
```

Checkout the
[`register-pg-connector`](https://github.com/hausgold/docker-debezium-connect/blob/master/build/utilities/register-pg-connector)
and
[`register-connector`](https://github.com/hausgold/docker-debezium-connect/blob/master/build/utilities/register-connector)
utilities for their defaults. And check the [Debezium PostgreSQL connector
configuration
properties](https://debezium.io/documentation/reference/stable/connectors/postgresql.html#postgresql-required-configuration-properties)
for an overview of available configuration options.

Afterwards start the service with the following command:

```bash
$ docker-compose up
```

Now you can list existing connectors at this endpoint
([/connectors?expand=status&expand=info](http://debezium-connect.local/connectors?expand=status&expand=info))
for example.

## Host configs

Install the nss-mdns package, enable and start the avahi-daemon.service. Then,
edit the file /etc/nsswitch.conf and change the hosts line like this:

```bash
hosts: ... mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns ...
```

## Configure a different mDNS hostname

The magic environment variable is *MDNS_HOSTNAME*. Just pass it like that to
your docker run command:

```bash
$ docker run --rm -e MDNS_HOSTNAME=something.else.local hausgold/debezium-connect
```

This will result in *something.else.local*.

You can also configure multiple aliases (CNAME's) for your container by
passing the *MDNS_CNAMES* environment variable. It will register all the comma
separated domains as aliases for the container, next to the regular mDNS
hostname.

```bash
$ docker run --rm \
  -e MDNS_HOSTNAME=something.else.local \
  -e MDNS_CNAMES=nothing.else.local,special.local \
  hausgold/debezium-connect
```

This will result in *something.else.local*, *nothing.else.local* and
*special.local*.

## Other top level domains

By default *.local* is the default mDNS top level domain. This images does not
force you to use it. But if you do not use the default *.local* top level
domain, you need to [configure your host avahi][custom_mdns] to accept it.

## Further reading

* Docker/mDNS demo: https://github.com/Jack12816/docker-mdns
* Archlinux howto: https://wiki.archlinux.org/index.php/avahi
* Ubuntu/Debian howto: https://wiki.ubuntuusers.de/Avahi/

[custom_mdns]: https://wiki.archlinux.org/index.php/avahi#Configuring_mDNS_for_custom_TLD
