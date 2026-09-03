# Score API

Provided as-is — you should not need to change it. A tiny Sanic service with two endpoints and
no database or other backing service.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/healthz` | none | Liveness / readiness probe |
| `POST` | `/decision` | HTTP basic | Dummy score for a client |

## Environment

| Variable | Required | Default | Notes |
|---|---|---|---|
| `BASIC_AUTH_PASSWORD` | **yes** | — | Password for `/decision`. Username is always `score`. Without it `/decision` returns `503`. |
| `LOG_LEVEL` | no | `INFO` | One of `CRITICAL`, `ERROR`, `WARNING`, `INFO`, `DEBUG`. Per-request logs appear only at `DEBUG`. |
| `PORT` | no | `8080` | Listen port. |
| `SERVICE_VERSION` | no | `local` | Echoed back by `/healthz`. |

Logs go to stdout as plain lines.

## Build and run

```bash
docker build -t score-api:local .
docker run --rm -p 8080:8080 -e BASIC_AUTH_PASSWORD=devsecret score-api:local
```

The image runs as non-root (uid 1000). Dependencies are locked in `uv.lock` and installed with
[uv](https://docs.astral.sh/uv/) inside the build — you do not need uv on your machine to build the
image. Sanic is the only direct dependency.

## Request and response

```bash
curl -s localhost:8080/healthz
# {"status":"ok","version":"local"}

curl -s -u score:devsecret -X POST localhost:8080/decision \
  -H 'Content-Type: application/json' \
  -d '{"client_id": "CL-0001", "amount": 1500}'
# {"decision_id":"…","client_id":"CL-0001","amount":1500.0,"score":0.1712,"decision":"APPROVE","state":"FINISHED"}
```

`client_id` is required; `amount` is optional and defaults to `0`. The score is a hash of
`client_id`, so responses are stable: `CL-0001` approves, `CL-0007` reviews, `CL-0002` declines.

## Run without Docker

Needs [uv](https://docs.astral.sh/uv/getting-started/installation/):

```bash
uv sync --frozen
BASIC_AUTH_PASSWORD=devsecret uv run python -m score_api
```
