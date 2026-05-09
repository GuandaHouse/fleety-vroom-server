# OSRM Brasil completo
#
# Estratégia 3-stages:
#   1. pbf-downloader (Debian 12): baixa Brasil-latest.osm.pbf via curl.
#      Não usamos apt do osrm/osrm-backend porque a imagem v5.25.0 é
#      baseada em Debian Stretch (EOL) — repos apt removidos.
#   2. builder (osrm/osrm-backend:v5.25.0): processa o pbf com
#      osrm-extract + osrm-partition + osrm-customize. RAM peak ~14GB
#      no partition, runner GHA público tem 16GB + swap.
#   3. runtime (osrm/osrm-backend:v5.25.0): copia só os .osrm processados
#      e expõe osrm-routed na 5000.
#
# Custos:
#   - Runtime Fly.io shared-cpu-2x 8GB GRU = $42.79/mês always-on
#   - Build: GHA público grátis (~25-30min processando)

FROM debian:12-slim AS pbf-downloader

WORKDIR /data

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Brasil completo da Geofabrik — 1.9GB compressed em 2026-04-26.
RUN curl -L --fail \
    https://download.geofabrik.de/south-america/brazil-latest.osm.pbf \
    -o map.osm.pbf

# ────────────────────────────────────────────────────────────────────────
# Builder stage: processa o pbf com binários OSRM
FROM osrm/osrm-backend:v5.25.0 AS builder

WORKDIR /data

COPY --from=pbf-downloader /data/map.osm.pbf /data/map.osm.pbf

# Pipeline OSRM:
#   extract: PBF → grafo (~3-4x do PBF em RAM, ~5-8GB)
#   partition: grafo → multi-level (~5-10x do PBF, ~10-14GB) ← o pesado
#   customize: matriz de tempo entre células
RUN osrm-extract -p /opt/car.lua map.osm.pbf
RUN osrm-partition map.osrm
RUN osrm-customize map.osrm

# Limpa o PBF original (1.9GB) — só os .osrm processados importam pro runtime
RUN rm map.osm.pbf

# ────────────────────────────────────────────────────────────────────────
# Runtime stage
FROM osrm/osrm-backend:v5.25.0

WORKDIR /data

COPY --from=builder /data/*.osrm* /data/

EXPOSE 5000

# osrm-routed com algoritmo MLD (mais leve em RAM que CH)
CMD ["osrm-routed", "--algorithm", "mld", "/data/map.osrm"]
