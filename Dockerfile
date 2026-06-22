# syntax=docker/dockerfile:1.7

FROM ghcr.io/astral-sh/uv:0.11.23-python3.14-trixie-slim

LABEL maintainer="ai-template contributors" \
      version="0.1.0"

WORKDIR /app

ENV PATH="/app/.venv/bin:${PATH}" \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_DEV=1

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

COPY . /app

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

CMD ["python", "-c", "import sys; print(sys.version)"]
