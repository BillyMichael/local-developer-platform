FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Dependencies first, so code changes don't reinstall them
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

COPY ${{ values.pkgName }} ./${{ values.pkgName }}
RUN uv sync --locked --no-dev

# 8080 is fixed by the kagent controller (Service, readiness probe on the agent card)
ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1 PORT=8080
EXPOSE 8080

# ENTRYPOINT + CMD so the chart's `args: ["receive"]` swaps only the role
ENTRYPOINT ["agent"]
CMD ["serve"]
