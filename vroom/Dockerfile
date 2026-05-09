# VROOM apontando pro OSRM próprio (fleety-osrm.flycast).
#
# O entrypoint do vroom-docker oficial faz:
#   if /conf/config.yml existe → copia pra /vroom-express/config.yml
# Então copiamos NOSSO config.yml pra /conf/ no build.
#
# config.yml define routingServers.osrm.car.host = fleety-osrm.flycast
# (rede interna Fly.io, HTTP, sem latência).

FROM ghcr.io/vroom-project/vroom-docker:v1.15.0

COPY config.yml /conf/config.yml

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD curl -sf http://localhost:3000/health || exit 1
