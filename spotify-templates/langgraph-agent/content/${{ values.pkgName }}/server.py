"""kagent BYO A2A server bootstrap. Usually left alone.

The contract the kagent controller expects of a BYO agent:

- Serve A2A on port 8080 (`$PORT`). `KAGENT_URL` points at the *controller* on :8083,
  a different thing.
- Answer `GET /.well-known/agent-card.json`. It is the readiness probe, so a failure here
  shows up as an Agent stuck at Ready=False with a healthy-looking pod.
- Read the agent card from `/config/agent-card.json`, which the controller generates from
  the Agent CR's `description` and mounts.
- Don't set `KAGENT_URL` / `KAGENT_NAME` / `KAGENT_NAMESPACE`; the controller injects them.
"""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path

import httpx
import uvicorn
from a2a.types import AgentCard
from kagent.core import KAgentConfig
from kagent.langgraph import KAgentApp, KAgentCheckpointer
from kagent.langgraph._executor import LangGraphAgentExecutorConfig

log = logging.getLogger(__name__)

AGENT_CARD_PATH = Path("/config/agent-card.json")


def env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name) or default)
    except ValueError:
        log.warning("%s=%r is not an integer; using %s.", name, os.getenv(name), default)
        return default


def app_name() -> str:
    return os.getenv("KAGENT_NAME") or os.getenv("AGENT_NAME") or "local-agent"


def _in_cluster() -> bool:
    return all(os.getenv(v) for v in ("KAGENT_URL", "KAGENT_NAME", "KAGENT_NAMESPACE"))


def checkpointer():
    """kagent's REST checkpointer in-cluster, an in-memory one locally.

    In-cluster, conversation state lives in the kagent controller, so the agent needs no
    database and any replica can serve any conversation. The platform's controller runs
    AUTH_MODE=unsecure, so a bare client is enough.
    """
    if not _in_cluster():
        from langgraph.checkpoint.memory import MemorySaver

        log.warning("KAGENT_* unset — using an in-memory checkpointer. State is not durable.")
        return MemorySaver()
    config = KAgentConfig()
    return KAgentCheckpointer(client=httpx.AsyncClient(base_url=config.url), app_name=config.app_name)


def _agent_card(name: str) -> AgentCard:
    if AGENT_CARD_PATH.is_file():
        card = json.loads(AGENT_CARD_PATH.read_text())
        # The controller writes `version: ""` for BYO agents and FastAPI refuses an empty
        # OpenAPI version, so fill it from the deployed image tag.
        card["version"] = card.get("version") or os.getenv("AGENT_VERSION") or "0.0.0"
        return AgentCard.model_validate(card)
    port = os.getenv("PORT", "8080")
    log.warning("%s absent — using a local agent card.", AGENT_CARD_PATH)
    return AgentCard.model_validate(
        {
            "name": name,
            "description": f"Local development card for {name}.",
            "url": f"http://localhost:{port}",
            "version": "0.0.0-local",
            "capabilities": {"streaming": True},
            "defaultInputModes": ["text"],
            "defaultOutputModes": ["text"],
            "skills": [],
        }
    )


class InflightLimit:
    """ASGI middleware: at most `limit` A2A requests in flight per pod; the rest get 503.

    Without it the only cap is memory, and past capacity every run on the pod dies together
    in an OOM kill. The queue dispatcher treats 503 as "retry shortly", which keeps the job
    counted in the queue so KEDA adds a pod.
    """

    EXEMPT = frozenset({"/.well-known/agent-card.json", "/health"})

    def __init__(self, app, limit: int) -> None:
        self.app = app
        self.limit = limit
        self.inflight = 0

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope.get("path") in self.EXEMPT:
            await self.app(scope, receive, send)
            return
        if self.inflight >= self.limit:
            body = json.dumps({"error": "agent at capacity", "limit": self.limit}).encode()
            await send(
                {
                    "type": "http.response.start",
                    "status": 503,
                    "headers": [
                        (b"content-type", b"application/json"),
                        (b"retry-after", b"5"),
                        (b"content-length", str(len(body)).encode()),
                    ],
                }
            )
            await send({"type": "http.response.body", "body": body})
            return
        self.inflight += 1
        try:
            await self.app(scope, receive, send)
        finally:
            self.inflight -= 1


def serve(graph) -> None:
    """Serve a compiled LangGraph over A2A on $PORT (8080 by default)."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    name = app_name()
    if _in_cluster():
        config = KAgentConfig()
    else:
        config = KAgentConfig(url="http://localhost:8083", name=name, namespace="local")

    app = KAgentApp(
        graph=graph,
        agent_card=_agent_card(name),
        config=config,
        # kagent's default of 300s is sized for a chat turn
        executor_config=LangGraphAgentExecutorConfig(
            execution_timeout=float(env_int("AGENT_EXECUTION_TIMEOUT", 300))
        ),
        # No OTel collector on the platform
        tracing=False,
    )
    asgi_app = app.build()
    if limit := env_int("AGENT_MAX_INFLIGHT", 0):
        asgi_app.add_middleware(InflightLimit, limit=limit)

    port = env_int("PORT", 8080)
    log.info("Serving agent %r on :%d", name, port)
    uvicorn.run(asgi_app, host="0.0.0.0", port=port)
