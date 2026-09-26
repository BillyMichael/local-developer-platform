"""Entry point. One image, two roles, chosen by argv:

serve     the kagent A2A server. Runs every graph: interactive turns from the kagent UI
          and the jobs the dispatcher relays. KEDA scales these pods on queue depth.
receive   the Gitea webhook receiver plus the queue dispatcher (queue-enabled agents
          only). Never builds a graph and holds no model key.
trigger   one scheduled run: sends the CronJob's prompt to the agent and exits
          (scheduled agents only).
"""

import sys


def main() -> None:
    role = sys.argv[1] if len(sys.argv) > 1 else "serve"
    if role == "serve":
        from ${{ values.pkgName }}.graph import build_graph
        from ${{ values.pkgName }}.server import serve

        serve(build_graph())
    elif role == "receive":
        from ${{ values.pkgName }}.jobs import serve_receiver

        serve_receiver()
    elif role == "trigger":
        from ${{ values.pkgName }}.jobs import trigger

        trigger()
    else:
        sys.exit(f"unknown role {role!r}; usage: agent [serve|receive|trigger]")


if __name__ == "__main__":
    main()
