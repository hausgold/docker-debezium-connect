FROM quay.io/debezium/connect:3.0
LABEL org.opencontainers.image.authors="containers@hausgold.de"

# You can change this environment variable on run's with -e
ENV MDNS_HOSTNAME=debezium-connect.local

# Switch to the root user
USER root

# Build stage 1 - installation of the mDNS stack, utilites, etc
RUN \
  --mount=type=bind,readwrite,source=build,target=/build \
  /build/run install

# Clear the default entrypoint, as it is the mc command
ENTRYPOINT []

# Define the command to run per default
CMD ["/usr/bin/supervisord", "-nc", "/etc/supervisord.conf"]
