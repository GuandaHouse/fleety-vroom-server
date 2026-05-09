# fleety-vroom-server

Build infra para o serviço VROOM + OSRM (Brasil completo) usado pelo [Fleety](https://fleety.com.br).

- **VROOM** v1.14.0 — Vehicle Routing Open-source Optimization Machine
- **OSRM** v5.27.1 — Open Source Routing Machine (algoritmo MLD)
- **Mapa:** Brasil completo (Geofabrik), processado em build-time
- **Deploy:** Fly.io app `fleety-vroom`, região `gru`

## Por que repo público

GitHub Actions oferece runner `ubuntu-latest` com 16 GB RAM em **repos públicos** (vs. 8 GB em privados). O `osrm-extract` do Brasil completo precisa ~12-14 GB de RAM, então repo público resolve sem custo de larger runner.

VROOM e OSRM são open source (BSD/MIT). Este repo só contém Dockerfile/fly.toml/workflow — nenhum código proprietário.

## Deploy

```bash
flyctl deploy --local-only
```

Push em `main` dispara deploy automático via GitHub Actions.

## Endpoint

- Produção: `https://fleety-vroom.fly.dev`
- Health: `GET /health`
- Otimização: `POST /` (payload VROOM JSON)
