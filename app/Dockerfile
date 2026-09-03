# Two stages purely to leave the 47MB uv binary behind: only the built venv reaches the runtime
# image. Nothing else here needs a build toolchain.
FROM python:3.13-slim@sha256:7ce4b6dfe35e55397b7cda544f8a13f191b7ae28dc5aad71fe664dbc9bc2623f AS builder

COPY --from=ghcr.io/astral-sh/uv:0.11.2 /uv /bin/uv

ENV UV_LINK_MODE=copy \
    UV_NO_CACHE=1 \
    UV_PROJECT_ENVIRONMENT=/opt/venv

WORKDIR /app
# Only the manifests: the venv depends on the lock, not on the source.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev


FROM python:3.13-slim@sha256:7ce4b6dfe35e55397b7cda544f8a13f191b7ae28dc5aad71fe664dbc9bc2623f AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:${PATH}" \
    PORT=8080

RUN groupadd --gid 1000 score \
    && useradd --uid 1000 --gid score --no-create-home --shell /usr/sbin/nologin score

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=score:score score_api ./score_api

USER score
EXPOSE 8080

CMD ["python", "-m", "score_api"]
