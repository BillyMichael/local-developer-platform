# Build context is the repo root. First run on the host, with the same Node
# version as FROM below (mismatches break native modules):
#   yarn install --immutable && yarn tsc && yarn build:backend

FROM node:24-trixie-slim

# Toolchain for native modules (better-sqlite3, isolated-vm) when no prebuilt
# binary can be fetched, e.g. behind a TLS-inspecting proxy; python3-venv for
# mkdocs, since TechDocs builds in-process (techdocs.generator.runIn: local).
ENV PYTHON=/usr/bin/python3
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential libsqlite3-dev python3-venv && \
    rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV && \
    $VIRTUAL_ENV/bin/pip install --no-cache-dir mkdocs-techdocs-core==1.7.1
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

USER node

# Needs BuildKit so /app is created as `node`, or the tar below fails.
WORKDIR /app

COPY --chown=node:node .yarn ./.yarn
COPY --chown=node:node .yarnrc.yml ./
COPY --chown=node:node backstage.json ./

ENV NODE_ENV=production

# Skeleton (package.json files) first, so code changes don't invalidate the install layer.
COPY --chown=node:node yarn.lock package.json packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production && rm -rf "$(yarn cache clean)"

COPY --chown=node:node packages/backend/dist/bundle.tar.gz app-config*.yaml ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
