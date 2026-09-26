# ${{ values.name }}

${{ values.description }}

A LangGraph agent served by kagent over A2A. Chat with it at <https://agents-127-0-0-1.nip.io>.

## Changing what it does

- `${{ values.pkgName }}/graph.py` — the system prompt and the graph. Start here.
- `${{ values.pkgName }}/tools.py` — the tools the model can call (`word_count` is a placeholder).
- `chart/values.yaml` — model, timeouts, resources{% if values.schedule %}, schedule{% endif %}{% if values.queue %}, queue and scaling{% endif %}.

Push to `main` and Gitea Actions tests the code, builds the image, pushes it to the Gitea
registry and pins `chart/values.yaml` to the new tag. ArgoCD then rolls it out. A brand
new agent shows `ImagePullBackOff` until that first build finishes — watch the Actions tab.

If you add a dependency, run `uv lock` and commit `uv.lock`; the build uses `uv sync --locked`.

## Running it locally

```bash
uv sync
export ANTHROPIC_API_KEY=...
uv run agent            # A2A server on :8080, in-memory conversation state
uv run pytest
```
{% if values.schedule %}
## Scheduled runs

A CronJob (`${{ values.name }}-schedule`) sends the agent `schedule.prompt` on
`schedule.cron` (Europe/London), both in `chart/values.yaml`. Each run shows up in the
kagent UI as a session from `cron@${{ values.name }}`. A failed run is not retried; the next
tick is the retry, and runs never overlap. To run it now:

```bash
kubectl -n ${{ values.name }} create job --from=cronjob/${{ values.name }}-schedule run-now
```
{% endif %}
{% if values.queue %}
## Webhook-triggered runs

Pull request events go Gitea → receiver → RabbitMQ → dispatcher → this agent, and KEDA
scales the agent's pods on queue depth (up to `queue.keda.maxReplicas`). Each run shows up
in the kagent UI as a session from `queue@${{ values.name }}`. A job that fails three times
is moved to the `jobs.dead` queue.

To connect a repository, add a webhook to it (or to the whole organisation) in Gitea under
**Settings → Webhooks → Add webhook → Gitea**:

- **Target URL:** `http://${{ values.name }}-receiver.${{ values.name }}.svc.cluster.local:8080/webhook/gitea`
- **Secret:** the output of

  ```bash
  kubectl -n ${{ values.name }} get secret queue-credentials -o jsonpath='{.data.webhook-secret}' | base64 -d
  ```

- **Trigger on:** custom events → *Pull Request* and *Pull Request Synchronized*

Set `queue.branchPrefix` (for example `renovate/`) to react only to some branches.

The RabbitMQ management UI is available with
`kubectl -n ${{ values.name }} port-forward svc/rabbitmq 15672` (user `admin`, password
under the `password` key of the same secret).
{% endif %}
