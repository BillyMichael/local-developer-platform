"""The agent. This is the file you edit.

The model comes from `agent.model` in chart/values.yaml (AGENT_MODEL). Conversation state is
persisted to the kagent controller by `checkpointer()`, so the agent needs no database.
"""

import os

from langchain.agents import create_agent
from langchain_anthropic import ChatAnthropic

from ${{ values.pkgName }}.server import checkpointer, env_int
from ${{ values.pkgName }}.tools import TOOLS

SYSTEM_PROMPT = """${{ values.systemPrompt }}"""


def build_graph():
    graph = create_agent(
        model=ChatAnthropic(model=os.getenv("AGENT_MODEL", "claude-sonnet-5")),
        tools=TOOLS,
        system_prompt=SYSTEM_PROMPT,
        checkpointer=checkpointer(),
    )
    # ~2 graph steps per tool call; raise AGENT_RECURSION_LIMIT for long tool chains
    return graph.with_config(recursion_limit=env_int("AGENT_RECURSION_LIMIT", 50))
