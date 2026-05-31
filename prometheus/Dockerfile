FROM prom/prometheus:v3.12.0

USER root

COPY prometheus.yml /etc/prometheus/prometheus.yml.template

ENTRYPOINT ["/bin/sh", "-c", "sed \"s|\\${GRAFANA_TOKEN}|${GRAFANA_TOKEN}|g\" /etc/prometheus/prometheus.yml.template > /etc/prometheus/prometheus.yml && /bin/prometheus --config.file=/etc/prometheus/prometheus.yml"]