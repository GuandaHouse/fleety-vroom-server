# [vroom-official-image 2026-05-09]
#
# Refatoração radical depois de 4 builds falhados tentando compilar VROOM +
# OSRM + processar Brasil completo from-source:
#   #1: OOM no osrm-partition (8GB ubuntu private)
#   #2: OOM no osrm-partition mesmo com 16GB (ubuntu public)
#   #3: husky postinstall hook fail no vroom-express
#   #4: idem
#
# **Decisão**: usar a imagem oficial `ghcr.io/vroom-project/vroom-docker`
# (mantida pela própria equipe do VROOM) e apontar pra OSRM público inicial-
# mente (router.project-osrm.org). Quando o volume pesar (rate limit do
# servidor público), sobe OSRM próprio com Brasil completo num app Fly.io
# separado e troca a env var.
#
# Vantagens:
#   - ZERO compilação, ZERO processamento de PBF no build
#   - Build em <2min (só pull da imagem)
#   - Imagem oficial = bug fixes automáticos via tag bumps
#   - Cobertura mundial via OSRM público
#
# Trade-off temporário:
#   - router.project-osrm.org tem rate limit (~5k req/dia). Para volume
#     atual da lavanderia (~12 clientes/dia × 12 calls = 144) cabe folgado.
#     Pra 100 tenants ativos: ~14k/dia → estoura. Aí sobe OSRM próprio.

FROM ghcr.io/vroom-project/vroom-docker:v1.15.0

# vroom-docker default config (de https://github.com/VROOM-Project/vroom-docker):
#   VROOM_ROUTER=osrm
#   VROOM_DOCKER=osrm                    (modo)
#   VROOM_LOG=/tmp/vroom.log
# OSRM endpoint via env vars no fly.toml: OSRM_HOST=router.project-osrm.org
#                                          OSRM_PORT=443
#                                          OSRM_PROFILE=driving

# vroom-express healthcheck na 3000
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD curl -sf http://localhost:3000/health || exit 1
