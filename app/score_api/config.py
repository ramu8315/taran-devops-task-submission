"""Runtime configuration.

TaranDM services read config through `ConfigProvider` and YAML files; this app keeps it
to a frozen dataclass over `os.environ` so there is nothing to learn before deploying it.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

# The password is per-deployment, the username is not — no reason to make it configurable.
BASIC_AUTH_USERNAME = "score"

DEFAULT_PORT = 8080
LOG_LEVELS = frozenset({"CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"})


@dataclass(frozen=True)
class Config:
    log_level: str
    basic_auth_password: str
    port: int
    version: str

    @classmethod
    def from_env(cls) -> "Config":
        # Nothing here is fatal — a misconfigured deployment starts and reports the problem at the
        # endpoint, rather than crash-looping before it can serve a single request.
        return cls(
            log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
            basic_auth_password=os.environ.get("BASIC_AUTH_PASSWORD", ""),
            port=int(os.environ.get("PORT", DEFAULT_PORT)),
            version=os.environ.get("SERVICE_VERSION", "local"),
        )
