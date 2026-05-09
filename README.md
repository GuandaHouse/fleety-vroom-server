# fleety-vroom-server

Build infra do mecanismo de roteirização do [Fleety](https://fleety.com.br): VROOM + OSRM em apps Fly.io separados.

## Layout

```
vroom/                 → app fleety-vroom  (solver VROOM, 512MB RAM)
osrm/                  → app fleety-osrm   (OSRM Brasil completo, 8GB RAM)
.github/workflows/
  deploy-vroom.yml     → roda quando vroom/** muda
  deploy-osrm.yml      → roda quando osrm/** muda
```

## Componentes

- **VROOM** (Vehicle Routing Open-source Optimization Machine) — solver de VRP, imagem oficial `ghcr.io/vroom-project/vroom-docker:v1.15.0`
- **OSRM** (Open Source Routing Machine) — cálculo de tempo/distância por ruas reais, imagem oficial `osrm/osrm-backend:v5.27.1` com algoritmo MLD
- **Mapa:** Brasil completo (Geofabrik, ~1.9 GB PBF, processado em build-time)
- **Região:** Fly.io `gru` (São Paulo) — ambos os apps na mesma região

## Por que repo público

GitHub Actions oferece runner `ubuntu-latest` com 16 GB RAM em **repos públicos** (vs. 8 GB em privados). O `osrm-partition` do Brasil completo passa de 14 GB nos picos, então repo público resolve sem custo de larger runner. Conteúdo: só Dockerfiles/fly.toml/workflows — nenhum código proprietário do Fleety.

## Custo Fly.io (GRU, 2026)

- VROOM (shared-cpu-1x 512MB, scale-to-zero): ~$2/mês máximo
- OSRM (shared-cpu-2x 8GB, always-on): $42.79/mês
- Volume: incluso no Fly Volumes (~$0/mês com snapshot < 10GB)
- **Total: ~$45/mês**

## Comunicação interna

VROOM não suporta HTTPS ([issue #289](https://github.com/VROOM-Project/vroom/issues/289)), então aponta pro OSRM via rede interna Fly.io: `http://fleety-osrm.flycast:5000` (configurado em [vroom/config.yml](vroom/config.yml)).

## Endpoints públicos

- VROOM: `https://fleety-vroom.fly.dev` — `POST /` recebe payload de otimização
- OSRM: `https://fleety-osrm.fly.dev` — `GET /route/v1/...`, `/table/v1/...`, etc

## Deploy

Push em `main` dispara deploy automático. Builds são paths-filtered:

- mudança em `vroom/**` → re-deploy só do VROOM (~3min)
- mudança em `osrm/**` → re-deploy do OSRM (~30min, processa Brasil completo)
