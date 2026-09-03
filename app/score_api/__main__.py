"""Entrypoint: `python -m score_api`."""

from score_api.server import create_app


def main() -> None:
    app = create_app()
    # single_process: scale with replicas, not with in-container workers.
    app.run(host="0.0.0.0", port=app.ctx.config.port, access_log=False, single_process=True)  # noqa: S104


if __name__ == "__main__":
    main()
