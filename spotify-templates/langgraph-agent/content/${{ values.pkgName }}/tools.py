"""The agent's tools. Only tools in `TOOLS` are bound to the model.

A tool's docstring is what the model reads to decide when to call it — write it for the
model.
"""

from langchain_core.tools import tool


@tool
def word_count(text: str) -> str:
    """Count the words in a piece of text. A placeholder — replace it with real tools."""
    return f"{len(text.split())} words"


TOOLS = [word_count]
