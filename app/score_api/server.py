"""Sanic app: `GET /healthz` and `POST /decision`.

Shaped like a TaranDM service (app factory, `HTTPMethodView`, basic auth on the decision
endpoint) with the strategy engine replaced by a hash. No database, no state.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import logging
import sys
import uuid

from sanic import Sanic
from sanic.exceptions import BadRequest, ServiceUnavailable, Unauthorized
from sanic.request import Request
from sanic.response import HTTPResponse, json
from sanic.views import HTTPMethodView

from score_api.config import BASIC_AUTH_USERNAME, LOG_LEVELS, Config

logger = logging.getLogger(__name__)

REALM = "score-api"

# Score is "risk", so higher is worse.
DECLINE_SCORE_LIMIT = 0.75
REVIEW_SCORE_LIMIT = 0.35
REVIEW_AMOUNT_LIMIT = 10_000.0


def configure_logging(requested_level: str) -> str:
    """Configure stdlib logging; returns the level actually applied."""
    level = requested_level if requested_level in LOG_LEVELS else "INFO"
    # force=True here plus configure_logging=False on the Sanic app keeps every logger — ours and
    # Sanic's own — on this single handler, so container logs have one format.
    logging.basicConfig(
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
        stream=sys.stdout,
        level=level,
        force=True,
    )
    if level != requested_level:
        logger.warning("LOG_LEVEL=%r is not a valid level; using %s.", requested_level, level)
    return level


def _authenticate(request: Request) -> None:
    config: Config = request.app.ctx.config
    if not config.basic_auth_password:
        # No password wired in: refuse everything rather than serve an unprotected endpoint.
        logger.error("BASIC_AUTH_PASSWORD is empty; refusing the request.")
        raise ServiceUnavailable("Service is not configured.")

    unauthorized = Unauthorized("Invalid credentials.", scheme="Basic", realm=REALM)

    scheme, _, token = request.headers.get("Authorization", "").partition(" ")
    if scheme.lower() != "basic":
        raise unauthorized
    try:
        credentials = base64.b64decode(token, validate=True)
    except binascii.Error:
        raise unauthorized
    # Bytes, not str: compare_digest rejects non-ASCII str, which a client is free to send.
    username, separator, password = credentials.partition(b":")
    if not separator:
        raise unauthorized

    # Both halves compared so a wrong username does not answer faster than a wrong password.
    valid = hmac.compare_digest(username, BASIC_AUTH_USERNAME.encode()) & hmac.compare_digest(
        password, config.basic_auth_password.encode()
    )
    if not valid:
        logger.warning("Authentication failed for username %r", username.decode("utf-8", errors="replace"))
        raise unauthorized


def _parse_body(request: Request) -> tuple[str, float]:
    payload = request.json
    if not isinstance(payload, dict):
        raise BadRequest("Request body must be a JSON object.")

    client_id = payload.get("client_id")
    if not isinstance(client_id, str) or not client_id.strip():
        raise BadRequest("Field 'client_id' must be a non-empty string.")

    amount = payload.get("amount", 0)
    if isinstance(amount, bool) or not isinstance(amount, (int, float)) or amount < 0:
        raise BadRequest("Field 'amount' must be a non-negative number.")

    return client_id.strip(), float(amount)


def _score(client_id: str) -> float:
    """Dummy score, derived from the client id so the same request always scores the same."""
    digest = hashlib.sha256(client_id.encode("utf-8")).digest()
    return int.from_bytes(digest[:4], "big") / 0xFFFFFFFF


def _decide(score: float, amount: float) -> str:
    if score >= DECLINE_SCORE_LIMIT:
        return "DECLINE"
    if score >= REVIEW_SCORE_LIMIT or amount > REVIEW_AMOUNT_LIMIT:
        return "REVIEW"
    return "APPROVE"


class HealthView(HTTPMethodView):
    """Probe target: unauthenticated, no dependencies, cheap enough for a 1s period."""

    async def get(self, request: Request) -> HTTPResponse:
        return json({"status": "ok", "version": request.app.ctx.config.version})


class DecisionView(HTTPMethodView):
    """Dummy scoring endpoint, guarded by BASIC_AUTH_PASSWORD."""

    async def post(self, request: Request) -> HTTPResponse:
        _authenticate(request)
        client_id, amount = _parse_body(request)

        score = _score(client_id)
        decision = _decide(score, amount)
        logger.info("Decision for client %s: %s (score %.4f, amount %s)", client_id, decision, score, amount)

        return json(
            {
                "decision_id": str(uuid.uuid4()),
                "client_id": client_id,
                "amount": amount,
                "score": round(score, 4),
                "decision": decision,
                "state": "FINISHED",
            }
        )


def create_app(config: Config | None = None) -> Sanic:
    config = config or Config.from_env()
    log_level = configure_logging(config.log_level)

    app = Sanic("score-api", configure_logging=False)
    app.ctx.config = config
    app.config.FALLBACK_ERROR_FORMAT = "json"
    app.config.MOTD = False

    app.add_route(HealthView.as_view(), "/healthz", name="healthz")
    app.add_route(DecisionView.as_view(), "/decision", name="decision")

    @app.before_server_start
    async def log_startup(_: Sanic) -> None:
        logger.info("Score API %s listening on port %s at log level %s", config.version, config.port, log_level)
        if not config.basic_auth_password:
            logger.warning("BASIC_AUTH_PASSWORD is not set; /decision will return 503.")

    @app.on_response
    async def log_request(request: Request, response: HTTPResponse) -> None:
        logger.debug("%s %s -> %s", request.method, request.path, response.status)

    return app
