#!/usr/bin/env python3
"""Interactive AI review of an existing paperless-ngx library.

Walks every document, asks paperless for LLM suggestions, and shows only the
ones that would actually change something. You approve or skip each document.

Mounted into the worker container. The webserver shares the pod's network
namespace, so PAPERLESS_URL defaults to http://localhost:8000 and only a token
is needed:

    kubectl exec -it -n paperless deploy/paperless -c worker -- \\
      env PAPERLESS_TOKEN=... paperless-ai-review --dry-run --limit 20

Get a token from Settings -> My Profile -> API token. Override PAPERLESS_URL to
run it from outside the cluster instead.

Every document costs one LLM call, so start with --limit. Suggestions are
cached server-side per backend, so a second pass over the same documents is
cheap; changing model or endpoint invalidates that cache.

Only *existing* tags/correspondents/types/paths are ever applied. Names the
model invents are shown as "new:" and never created - inventing taxonomy in
bulk is how a library gets messy, and it should be a deliberate decision.
Titles and dates are shown but only applied with --titles / --dates.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 120


class Api:
    def __init__(self, base: str, token: str) -> None:
        self.base = base.rstrip("/")
        self.token = token

    def _call(self, method: str, path: str, body: dict | None = None) -> dict:
        url = path if path.startswith("http") else f"{self.base}{path}"
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Token {self.token}")
        req.add_header("Accept", "application/json")
        if data:
            req.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}

    def get(self, path: str) -> dict:
        return self._call("GET", path)

    def patch(self, path: str, body: dict) -> dict:
        return self._call("PATCH", path, body)


def load_names(api: Api, endpoint: str) -> dict[int, str]:
    """id -> name for a taxonomy endpoint, following pagination."""
    out: dict[int, str] = {}
    url = f"/api/{endpoint}/?page_size=250"
    while url:
        page = api.get(url)
        for item in page.get("results", []):
            out[item["id"]] = item.get("name", str(item["id"]))
        url = page.get("next") or ""
    return out


def iter_documents(api: Api, start_id: int):
    url = f"/api/documents/?page_size=100&ordering=id&id__gte={start_id}"
    while url:
        page = api.get(url)
        yield from page.get("results", [])
        url = page.get("next") or ""


def describe(ids: list[int], names: dict[int, str]) -> str:
    return ", ".join(names.get(i, f"#{i}") for i in ids) or "-"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, help="stop after N documents that have changes")
    ap.add_argument("--start-id", type=int, default=0, help="resume from this document id")
    ap.add_argument("--dry-run", action="store_true", help="never write, just report")
    ap.add_argument("--titles", action="store_true", help="allow applying suggested titles")
    ap.add_argument("--dates", action="store_true", help="allow applying suggested dates")
    ap.add_argument("--delay", type=float, default=0.0, help="seconds between documents")
    ap.add_argument("--yes", action="store_true", help="apply every change without asking")
    args = ap.parse_args()

    base = os.environ.get("PAPERLESS_URL", "http://localhost:8000")
    token = os.environ.get("PAPERLESS_TOKEN")
    if not token:
        print("set PAPERLESS_TOKEN (Settings -> My Profile -> API token)", file=sys.stderr)
        return 2

    api = Api(base, token)
    print("loading taxonomy...", file=sys.stderr)
    tags = load_names(api, "tags")
    corrs = load_names(api, "correspondents")
    types = load_names(api, "document_types")
    paths = load_names(api, "storage_paths")

    seen = changed = applied = failed = 0
    try:
        for doc in iter_documents(api, args.start_id):
            seen += 1
            did = doc["id"]
            try:
                s = api.get(f"/api/documents/{did}/ai_suggestions/")
            except urllib.error.HTTPError as e:
                # 400 = AI disabled; 503 = backend timeout. Neither is fatal.
                print(f"  #{did}: suggestion failed ({e.code} {e.reason})", file=sys.stderr)
                failed += 1
                continue
            except Exception as e:  # noqa: BLE001 - network flake, keep going
                print(f"  #{did}: {type(e).__name__}: {e}", file=sys.stderr)
                failed += 1
                continue

            patch: dict = {}
            lines: list[str] = []

            # Tags are additive - never drop tags the model did not mention.
            cur_tags = set(doc.get("tags") or [])
            new_tags = [t for t in s.get("tags", []) if t not in cur_tags]
            if new_tags:
                patch["tags"] = sorted(cur_tags | set(new_tags))
                lines.append(f"    + tags        {describe(new_tags, tags)}")

            for field, names, key in (
                ("correspondent", corrs, "correspondents"),
                ("document_type", types, "document_types"),
                ("storage_path", paths, "storage_paths"),
            ):
                proposed = s.get(key) or []
                if proposed and doc.get(field) != proposed[0]:
                    patch[field] = proposed[0]
                    was = names.get(doc.get(field), "-") if doc.get(field) else "-"
                    lines.append(f"    ~ {field:<12} {was} -> {names.get(proposed[0])}")

            if args.titles and s.get("title") and s["title"] != doc.get("title"):
                patch["title"] = s["title"]
                lines.append(f"    ~ title       {doc.get('title')!r} -> {s['title']!r}")

            if args.dates and s.get("dates"):
                proposed = s["dates"][0]
                if proposed and not str(doc.get("created", "")).startswith(proposed):
                    patch["created"] = proposed
                    lines.append(f"    ~ created     {doc.get('created')} -> {proposed}")

            # Names the model invented. Reported, never created.
            for key, label in (
                ("suggested_tags", "tags"),
                ("suggested_correspondents", "correspondents"),
                ("suggested_document_types", "document types"),
                ("suggested_storage_paths", "storage paths"),
            ):
                if s.get(key):
                    lines.append(f"      new: {label}: {', '.join(s[key])} (not created)")

            if not lines:
                continue

            changed += 1
            print(f"\n[{changed}] #{did}  {doc.get('title','')[:70]}")
            print(f"    {base}/documents/{did}/details")
            for line in lines:
                print(line)

            if not patch:
                print("    (nothing applicable - only uncreated names)")
            elif args.dry_run:
                print("    dry-run, not applied")
            else:
                ans = "y" if args.yes else input("    apply? [y/N/q] ").strip().lower()
                if ans == "q":
                    break
                if ans == "y":
                    try:
                        api.patch(f"/api/documents/{did}/", patch)
                        applied += 1
                        print("    applied")
                    except Exception as e:  # noqa: BLE001
                        failed += 1
                        print(f"    FAILED: {e}", file=sys.stderr)

            if args.limit and changed >= args.limit:
                break
            if args.delay:
                time.sleep(args.delay)
    except KeyboardInterrupt:
        print("\ninterrupted", file=sys.stderr)

    print(
        f"\nscanned={seen} with-changes={changed} applied={applied} errors={failed}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
