"""The asynchronous path: Gitea webhook -> RabbitMQ -> dispatcher -> the agent's own A2A server.

One cheap always-on process (`agent receive`) does both halves:

- **Receiver.** Gitea calls `POST /webhook/gitea` when a pull request opens or gets new
  commits. It checks the HMAC signature, keeps only the events the agent cares about,
  publishes a job and returns 202. It never runs a graph: reviewing takes minutes and Gitea
  times a delivery out in seconds.
- **Dispatcher.** Consumes the queue and relays each job as one A2A message to the agent's
  Service. Runs therefore go through kagent's executor, checkpointer and task store, and
  show up in the kagent UI next to interactive sessions — one code path, not two.

Delivery is at-least-once. A failed relay is republished with its attempt number bumped and
dead-lettered to `jobs.dead` after MAX_ATTEMPTS; a dispatcher that dies mid-run leaves its
messages unacked, and RabbitMQ redelivers them (the quorum queue's delivery limit bounds
that path too). KEDA scales the agent pods on the queue's ready + unacked count
(chart/templates/queue.yaml).
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import logging
import os
import uuid
from contextlib import asynccontextmanager
from typing import Any

import aio_pika
import httpx
from a2a.client import A2ACardResolver, ClientConfig, ClientFactory
from a2a.client.errors import A2AClientHTTPError
from a2a.types import Message, Part, Role, TaskState, TextPart
from fastapi import FastAPI, Header, HTTPException, Request, Response

from ${{ values.pkgName }}.server import app_name, env_int

log = logging.getLogger(__name__)

QUEUE = "jobs"
DEAD_LETTER_QUEUE = "jobs.dead"
# Relay attempts before a job is dead-lettered. Tracked in our own header: RabbitMQ 4 does not
# count nack-with-requeue toward the quorum delivery limit, which only catches crashes.
MAX_ATTEMPTS = 3
# Pause before handing a failed job back, so a not-yet-ready agent pod doesn't burn every
# attempt in a few seconds.
RETRY_DELAY_SECONDS = 20.0
# Wait between retries when the agent answered 503 (every pod at AGENT_MAX_INFLIGHT).
CAPACITY_RETRY_SECONDS = 15.0

# Gitea pull_request actions worth a run. `synchronized` = new commits on an open PR.
HANDLED_ACTIONS = frozenset({"opened", "reopened", "synchronized"})

# Interrupted states (input-required) count as failures: nobody answers an unattended run.
_TERMINAL = {TaskState.completed, TaskState.failed, TaskState.canceled, TaskState.rejected}


def verify_signature(body: bytes, signature: str | None, secret: str | None) -> bool:
    """Constant-time check of Gitea's `X-Gitea-Signature` (hex HMAC-SHA256, no prefix)."""
    if not secret:
        return True
    if not signature:
        return False
    expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def extract(payload: dict[str, Any], branch_prefix: str = "") -> dict[str, Any] | None:
    """Reduce a Gitea pull_request event to what the agent needs, or None to ignore it.

    Filtering here rather than in the graph keeps queue depth an honest scaling signal.
    """
    pr = payload.get("pull_request") or {}
    head = pr.get("head") or {}
    repo = (payload.get("repository") or {}).get("full_name")
    if payload.get("action") not in HANDLED_ACTIONS or not repo or not pr.get("number"):
        return None
    if pr.get("state", "open") != "open" or not head.get("ref", "").startswith(branch_prefix):
        return None
    return {
        "repository": repo,
        "number": pr["number"],
        "title": pr.get("title", ""),
        "url": pr.get("html_url", ""),
        "branch": head.get("ref", ""),
        "head": head.get("sha", ""),
        "action": payload["action"],
    }


def prompt_for(job: dict[str, Any]) -> str:
    """The user message the agent receives for a queued job."""
    return (
        f'Pull request #{job["number"]} "{job["title"]}" in {job["repository"]} was {job["action"]}.\n'
        f"URL: {job['url']}\nBranch: {job['branch']} at commit {job['head']}\n\n"
        "Handle it according to your instructions."
    )


async def declare(channel: aio_pika.abc.AbstractChannel) -> aio_pika.abc.AbstractQueue:
    await channel.declare_queue(DEAD_LETTER_QUEUE, durable=True, arguments={"x-queue-type": "quorum"})
    return await channel.declare_queue(
        QUEUE,
        durable=True,
        arguments={
            "x-queue-type": "quorum",
            "x-delivery-limit": MAX_ATTEMPTS,
            "x-dead-letter-exchange": "",
            "x-dead-letter-routing-key": DEAD_LETTER_QUEUE,
        },
    )


def job_message(job: dict[str, Any], job_id: str, attempt: int = 1) -> aio_pika.Message:
    return aio_pika.Message(
        json.dumps(job).encode(),
        message_id=job_id,
        headers={"x-attempt": attempt},
        content_type="application/json",
        delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
    )


def _text_of(parts) -> str:
    return " ".join(p.root.text for p in parts if isinstance(p.root, TextPart))


class Dispatcher:
    """Consumes jobs and relays each one to the agent as an A2A message."""

    def __init__(self, url: str, *, timeout: float, user_id: str) -> None:
        self.url = url
        self.timeout = timeout
        # x-user-id is how kagent attributes the session in its UI.
        self._http = httpx.AsyncClient(
            base_url=url,
            headers={"x-user-id": user_id},
            timeout=httpx.Timeout(timeout, connect=10.0),
            # No keep-alive: kube-proxy balances per connection, so warm connections pin every
            # relay to the first pod and pods KEDA adds would never get work.
            limits=httpx.Limits(max_keepalive_connections=0),
        )
        self._client = None
        self._tasks: set[asyncio.Task] = set()

    async def _a2a_client(self):
        # Lazy: the agent may not be Ready when the receiver starts. The card's advertised URL
        # routes via the kagent controller; talk to the Service directly instead.
        if self._client is None:
            card = await A2ACardResolver(self._http, self.url).get_agent_card()
            card.url = self.url
            self._client = ClientFactory(ClientConfig(httpx_client=self._http)).create(card)
        return self._client

    async def relay(self, text: str, context_id: str) -> str:
        """One A2A message -> wait for a terminal state. Raises on failure."""
        client = await self._a2a_client()
        message = Message(
            role=Role.user,
            message_id=uuid.uuid4().hex,
            context_id=context_id,
            parts=[Part(root=TextPart(text=text))],
        )
        async with asyncio.timeout(self.timeout):
            while True:
                try:
                    state, note = await self._await_terminal(client, message)
                    break
                except A2AClientHTTPError as e:
                    if e.status_code != 503:
                        raise
                    log.info("Agent at capacity; retrying %s in %.0fs.", context_id, CAPACITY_RETRY_SECONDS)
                    await asyncio.sleep(CAPACITY_RETRY_SECONDS)
        if state is not TaskState.completed:
            # kagent replaces the exception text with a generic message; the traceback is in
            # the agent pod's log.
            raise RuntimeError(f"agent finished {context_id} in state {state}: {note[:200]}")
        return note

    async def _await_terminal(self, client, message: Message) -> tuple[Any, str]:
        state, note = TaskState.unknown, ""
        async for event in client.send_message(message):
            if isinstance(event, Message):
                return TaskState.completed, _text_of(event.parts)
            task, _update = event
            state = task.status.state
            if task.status.message and task.status.message.parts:
                note = _text_of(task.status.message.parts) or note
        if state not in _TERMINAL:
            raise RuntimeError(f"A2A stream ended with task still {state}")
        return state, note

    async def handle(self, msg: aio_pika.abc.AbstractIncomingMessage, exchange) -> None:
        """Never raises: a failed relay is retried as a new message, or dead-lettered."""
        attempt = int((msg.headers or {}).get("x-attempt") or 1)
        # Fresh LangGraph thread per attempt: a run that crashed mid-tool-call leaves a
        # history LangGraph refuses to continue, so reusing it would fail every retry.
        context_id = f"{msg.message_id}-a{attempt}"
        job = json.loads(msg.body)
        try:
            note = await self.relay(prompt_for(job), context_id)
            await msg.ack()
            log.info("Completed %s: %s", context_id, note[:200])
            return
        except Exception:
            log.exception("Relay of %s failed (attempt %d of %d).", context_id, attempt, MAX_ATTEMPTS)
        if attempt >= MAX_ATTEMPTS:
            await msg.nack(requeue=False)  # -> jobs.dead
            return
        await asyncio.sleep(RETRY_DELAY_SECONDS)
        # Publish before ack: a crash in between duplicates the job rather than losing it
        await exchange.publish(job_message(job, msg.message_id, attempt + 1), routing_key=QUEUE)
        await msg.ack()

    async def run(self, queue: aio_pika.abc.AbstractQueue, exchange) -> None:
        """Concurrency is bounded by the channel's prefetch count."""
        log.info("Dispatching %s to %s", queue.name, self.url)
        async with queue.iterator() as messages:
            async for msg in messages:
                task = asyncio.create_task(self.handle(msg, exchange))
                self._tasks.add(task)
                task.add_done_callback(self._tasks.discard)


def build_app() -> FastAPI:
    name = app_name()
    secret = os.getenv("AGENT_WEBHOOK_SECRET")
    branch_prefix = os.getenv("AGENT_BRANCH_PREFIX", "")
    if not secret:
        log.warning("AGENT_WEBHOOK_SECRET unset — webhook signatures are NOT verified.")
    state: dict[str, Any] = {}

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        # RabbitMQ boots slower than this pod on a fresh install; wait rather than crash-loop
        # (the chart's startupProbe allows for it)
        while True:
            try:
                conn = await aio_pika.connect_robust(os.environ["AMQP_URL"])
                break
            except (OSError, aio_pika.exceptions.AMQPConnectionError) as e:
                log.warning("RabbitMQ not reachable yet (%s); retrying in 5s.", e)
                await asyncio.sleep(5)
        publish_channel = await conn.channel()
        await declare(publish_channel)
        consume_channel = await conn.channel()
        await consume_channel.set_qos(prefetch_count=env_int("AGENT_DISPATCH_CONCURRENCY", 20))
        dispatcher = Dispatcher(
            os.getenv("AGENT_A2A_URL") or f"http://{name}:8080",
            timeout=float(env_int("AGENT_DISPATCH_TIMEOUT", 3600)),
            user_id=f"queue@{name}",
        )
        queue = await declare(consume_channel)
        task = asyncio.create_task(dispatcher.run(queue, consume_channel.default_exchange))
        state.update(conn=conn, channel=publish_channel)
        try:
            yield
        finally:
            # In-flight messages are unacked; RabbitMQ redelivers them to another consumer.
            task.cancel()
            await conn.close()

    app = FastAPI(title=f"{name} webhook receiver", docs_url=None, redoc_url=None, lifespan=lifespan)

    @app.get("/healthz")
    async def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/readyz")
    async def readyz() -> dict[str, str]:
        if state["conn"].is_closed:
            raise HTTPException(status_code=503, detail="queue unreachable")
        return {"status": "ok"}

    @app.post("/webhook/gitea", status_code=202)
    async def gitea(
        request: Request,
        response: Response,
        x_gitea_event: str | None = Header(default=None),
        x_gitea_signature: str | None = Header(default=None),
    ) -> dict[str, Any]:
        body = await request.body()
        if not verify_signature(body, x_gitea_signature, secret):
            raise HTTPException(status_code=401, detail="bad signature")
        job = extract(json.loads(body), branch_prefix) if x_gitea_event == "pull_request" else None
        if job is None:
            response.status_code = 200
            return {"ignored": x_gitea_event}
        # ponytail: no de-duplication. Gitea only redelivers by hand, and a new push is new work.
        job_id = uuid.uuid4().hex
        await state["channel"].default_exchange.publish(job_message(job, job_id), routing_key=QUEUE)
        log.info("Queued %s for %s#%s", job_id, job["repository"], job["number"])
        return {"queued": job_id, **job}

    return app


def trigger() -> None:
    """The CronJob's role: send AGENT_TRIGGER_PROMPT as one A2A message and exit.

    The run happens in the agent's own pods, exactly like a chat turn, and shows up in the
    kagent UI as a session from `cron@<agent>`. Exits non-zero unless the run completed. No
    retries: the next tick is the retry, and the CronJob's `Forbid` policy stops overlaps.
    """
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    prompt = os.getenv("AGENT_TRIGGER_PROMPT", "").strip()
    if not prompt:
        raise SystemExit("AGENT_TRIGGER_PROMPT is unset (the chart sets it from schedule.prompt).")
    name = app_name()
    dispatcher = Dispatcher(
        os.getenv("AGENT_A2A_URL") or f"http://{name}:8080",
        timeout=float(env_int("AGENT_DISPATCH_TIMEOUT", 1740)),
        user_id=f"cron@{name}",
    )
    # Fresh thread per firing, for the same reason as the dispatcher's fresh thread per attempt
    context_id = f"cron-{uuid.uuid4().hex}"
    note = asyncio.run(dispatcher.relay(prompt, context_id))
    log.info("Completed %s: %s", context_id, note[:200])


def serve_receiver() -> None:
    import uvicorn

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    uvicorn.run(build_app(), host="0.0.0.0", port=env_int("PORT", 8080), access_log=False)
