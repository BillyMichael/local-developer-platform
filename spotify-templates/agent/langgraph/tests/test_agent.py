import hashlib
import hmac

from ${{ values.pkgName }}.graph import build_graph
from ${{ values.pkgName }}.jobs import extract, verify_signature
from ${{ values.pkgName }}.tools import word_count

PR_EVENT = {
    "action": "opened",
    "pull_request": {
        "number": 7,
        "title": "Bump httpx",
        "state": "open",
        "html_url": "https://vcs.example/org/repo/pulls/7",
        "head": {"ref": "renovate/httpx", "sha": "abc123"},
    },
    "repository": {"full_name": "org/repo"},
}


def test_graph_builds(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test")
    assert hasattr(build_graph(), "ainvoke")


def test_word_count():
    assert word_count.invoke({"text": "one two three"}) == "3 words"


def test_signature():
    body = b'{"a": 1}'
    good = hmac.new(b"s3cret", body, hashlib.sha256).hexdigest()
    assert verify_signature(body, good, "s3cret")
    assert not verify_signature(body, "0" * 64, "s3cret")
    assert not verify_signature(body, None, "s3cret")
    assert verify_signature(body, None, None)


def test_extract_filters_events():
    job = extract(PR_EVENT)
    assert job["repository"] == "org/repo" and job["number"] == 7 and job["head"] == "abc123"
    assert extract({**PR_EVENT, "action": "closed"}) is None
    assert extract(PR_EVENT, branch_prefix="renovate/") is not None
    assert extract(PR_EVENT, branch_prefix="dependabot/") is None
