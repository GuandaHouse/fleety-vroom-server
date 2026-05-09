# OSRM Brasil completo — imagem oficial osrm/osrm-backend
#
# Estratégia: build no GHA público (16GB RAM grátis) processa o PBF Brasil
# completo (1.9GB → ~5GB processados), embute na imagem final. Runtime no
# Fly.io carrega o .osrm em RAM e expõe /route, /table, /match etc na 5000.
#
# Algoritmo: MLD (Multi-Level Dijkstra) — usa menos RAM que CH em runtime,
# que é o que importa pro nosso budget no Fly.io (8GB).
#
# Custos esperados:
#   - Runtime: shared-cpu-2x 8GB GRU = $42.79/mês (always-on, mapa em RAM)
#   - Build: GHA público grátis (~25-30min processando)

FROM osrm/osrm-backend:v5.27.1 AS builder

WORKDIR /data

# Brasil completo da Geofabrik — atualizado diariamente.
# 1.9GB compressed em 2026-04-26.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -L --fail \
       https://download.geofabrik.de/south-america/brazil-latest.osm.pbf \
       -o map.osm.pbf

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
FROM osrm/osrm-backend:v5.27.1

WORKDIR /data

COPY --from=builder /data/*.osrm* /data/

EXPOSE 5000

# osrm-routed com algoritmo MLD (mais leve em RAM que CH)
CMD ["osrm-routed", "--algorithm", "mld", "/data/map.osrm"]
