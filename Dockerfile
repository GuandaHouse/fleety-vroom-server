# [vroom-osrm-debian12 2026-05-09]
# Refatoração depois de 2 fixes incrementais que não resolveram (PRs #314,
# #317, #318): a imagem osrm/osrm-backend:v5.25.0 é baseada em Debian Stretch
# (EOL, libboost 1.62 muito antiga pra compilar VROOM v1.14.0 que precisa
# Boost 1.71+, glibc 2.24 incompatível com Node 20 do NodeSource).
#
# **Solução:** build OSRM v5.27.1 + VROOM v1.14.0 from source no Debian 12
# (Bookworm). Boost 1.74, Node 18 nativo, tudo moderno e compatível.
#
# **Mapa:** Brasil completo — extract da Geofabrik. ~600MB compressed,
# ~2.5GB processado. Builder Fly.io precisa 16GB RAM pra osrm-extract
# (osrm-extract de pbf grande consome ~12-14GB). App em runtime precisa
# 4GB pra carregar dados em memória.
#
# **Algoritmo:** MLD (Multi-Level Dijkstra) — mais leve em RAM que CH.
# Recomendado pra VMs pequenas.
#
# **Trade-off:** primeiro build demora ~30-40min (compila OSRM + VROOM +
# processa pbf Brasil Sudeste). Builds subsequentes usam cache do Depot
# do Fly.io e ficam ~5min. Aceitável pra deploys raros (não mexemos em
# vroom-server/** com frequência).

# ============================================================================
# Stage 1: Build OSRM + processa mapa
# ============================================================================
FROM debian:12-slim AS osrm-build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc-11 \
    g++-11 \
    cmake \
    pkg-config \
    git \
    curl \
    ca-certificates \
    libboost-all-dev \
    libtbb-dev \
    libxml2-dev \
    libsparsehash-dev \
    liblua5.3-dev \
    libluajit-5.1-dev \
    libbz2-dev \
    libzip-dev \
    libosmpbf-dev \
    libprotobuf-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# [gcc11 2026-05-09] OSRM v5.27.1 com sol2-3.3.0 explode em GCC 12 com
# `-Werror=array-bounds`. GCC 11 (default Debian 11) compila limpo.
# Debian 12 mantém gcc-11 disponível via apt.
ENV CC=gcc-11 CXX=g++-11

# Build OSRM v5.27.1 from source.
# [oom-fix 2026-05-09] -j2 (não nproc) — builder Fly.io tem 4 CPU/4GB. cc1plus
# em files OSRM grandes consome 1-2GB cada. -j$(nproc)=4 paralelos = OOM.
# -j2 cabe em 4GB (compila mais devagar, mas não estoura).
RUN git clone --branch v5.27.1 --depth 1 https://github.com/Project-OSRM/osrm-backend.git /tmp/osrm-backend
WORKDIR /tmp/osrm-backend
RUN mkdir build && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release .. \
    && cmake --build . -j2 \
    && cmake --install .

# Baixa e processa Brasil completo (~600MB compressed, ~2.5GB processado).
# Requer builder com 16GB RAM (paid org Fly.io: editar memória do
# fly-builder-* pra 16384MB via dashboard ou `fly machine update`).
WORKDIR /data
RUN curl -L --fail \
    https://download.geofabrik.de/south-america/brazil-latest.osm.pbf \
    -o map.osm.pbf
RUN osrm-extract -p /tmp/osrm-backend/profiles/car.lua map.osm.pbf
RUN osrm-partition map.osrm
RUN osrm-customize map.osrm
RUN rm map.osm.pbf

# ============================================================================
# Stage 2: Imagem final — VROOM + osrm-routed + dados
# ============================================================================
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps (libs que osrm-routed e VROOM linkam dinamicamente) + build
# tools pra VROOM + Node 18 pra vroom-express
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    build-essential \
    cmake \
    pkg-config \
    libboost-all-dev \
    libtbb12 \
    liblua5.3-0 \
    libluajit-5.1-2 \
    libssl-dev \
    libasio-dev \
    libglpk-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Copia OSRM binaries + libs do stage de build
COPY --from=osrm-build /usr/local/bin/osrm-* /usr/local/bin/
COPY --from=osrm-build /usr/local/lib/libosrm* /usr/local/lib/
RUN ldconfig

# Build VROOM v1.14.0 from source
WORKDIR /tmp
RUN git clone --branch v1.14.0 --depth 1 https://github.com/VROOM-Project/vroom.git
WORKDIR /tmp/vroom
# [oom-fix 2026-05-09] -j2 igual OSRM build pra evitar OOM no builder.
RUN git submodule update --init \
    && cd src \
    && make -j2 \
    && cp ../bin/vroom /usr/local/bin/vroom \
    && cd / && rm -rf /tmp/vroom

# Install vroom-express (wrapper HTTP)
WORKDIR /app
RUN git clone --branch v1.14.0 --depth 1 https://github.com/VROOM-Project/vroom-express.git . \
    && npm install --production --no-audit --no-fund

# Copia dados OSRM processados do stage 1
COPY --from=osrm-build /data/*.osrm* /data/

# Configuração vroom-express
ENV VROOM_ROUTER=osrm
ENV VROOM_DOCKER=osrm
ENV PORT=3000

# Healthcheck — start-period maior porque OSRM precisa carregar mapa em RAM
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -sf http://localhost:3000/health || exit 1

# Start script (osrm-routed em background + vroom-express em foreground)
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 3000

CMD ["/usr/local/bin/start.sh"]
