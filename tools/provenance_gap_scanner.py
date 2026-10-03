#!/usr/bin/env python3
"""Scan link traces against a provenance catalog without resolving links."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Protocol
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


EVIDENCE_STATES = (
    "OBSERVED",
    "RESOLVED",
    "CONTENT_VERIFIED",
    "OWNERSHIP_ACCESS_VERIFIED",
    "PROJECT_MAPPED",
    "HASHED",
    "CURRENT",
    "STALE",
)
FLAGS = (
    "EPHEMERAL",
    "AUTH_REQUIRED",
    "EXTERNAL",
    "DUPLICATE",
    "DEAD",
    "CATALOG_ABSENT",
    "SECRET_REDACTED",
)
REDACTED = "[REDACTED]"
SECRET_PARAMETER = re.compile(
    r"(?:access[_-]?token|auth(?:orization)?|client[_-]?secret|"
    r"authorization[_-]?code|credential|jwt|oauth[_-]?(?:code|token)|"
    r"refresh[_-]?token|signature|"
    r"sig|token|awsaccesskeyid|googleaccessid|"
    r"x-amz-(?:credential|security-token|signature)|"
    r"x-goog-(?:credential|signature))",
    re.IGNORECASE,
)
JWT = re.compile(
    r"(?<![A-Za-z0-9_-])"
    r"eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}"
    r"(?![A-Za-z0-9_-])"
)
BEARER = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+")
SECRET_TEXT_PARAMETER = re.compile(
    r"(?i)(\b(?:access_token|auth|authorization_code|client_secret|"
    r"credential|jwt|oauth_(?:code|token)|refresh_token|signature|"
    r"sig|token|awsaccesskeyid|googleaccessid|"
    r"x-amz-(?:credential|security-token|signature)|"
    r"x-goog-(?:credential|signature))\s*[=:]\s*)"
    r"([^&\s,;]+)"
)
URL_PATTERN = re.compile(r"https?://[^\s<>\"']+", re.IGNORECASE)


class ResolutionAdapter(Protocol):
    """Optional offline or external resolver interface."""

    def resolve(self, item: dict) -> str | None:
        """Return a verified evidence state, or None when unresolved."""


def redact_text(value: str) -> tuple[str, bool]:
    """Remove obvious bearer, JWT, and credential parameter values."""
    redacted = BEARER.sub("Bearer " + REDACTED, value)
    redacted = JWT.sub(REDACTED, redacted)
    redacted = SECRET_TEXT_PARAMETER.sub(rf"\1{REDACTED}", redacted)
    return redacted, redacted != value


def redact_url(value: str) -> tuple[str, bool]:
    """Redact URL credentials and secret query/fragment values."""
    before = value
    try:
        parts = urlsplit(value)
        netloc = (
            f"{REDACTED}@{parts.netloc.rsplit('@', 1)[1]}"
            if "@" in parts.netloc
            else parts.netloc
        )

        query = [
            (key, REDACTED if SECRET_PARAMETER.search(key) else val)
            for key, val in parse_qsl(parts.query, keep_blank_values=True)
        ]
        fragment, _ = redact_text(parts.fragment)
        value = urlunsplit(
            (parts.scheme, netloc, parts.path, urlencode(query), fragment)
        )
    except ValueError:
        pass
    value, _ = redact_text(value)
    return value, value != before


def _read_records(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8-sig")
    if not text.strip():
        return []

    if path.suffix.lower() == ".csv":
        return [dict(row) for row in csv.DictReader(text.splitlines())]

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = None
        records = []
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                records.append({"url": line})
            else:
                records.extend(_unwrap_records(value))
        return records

    if parsed is not None:
        return _unwrap_records(parsed)
    return []


def _unwrap_records(value: object) -> list[dict]:
    if isinstance(value, list):
        return [dict(item) if isinstance(item, dict) else {"url": str(item)}
                for item in value]
    if isinstance(value, dict):
        for key in ("items", "artifacts", "links", "records", "conversations", "catalog", "data"):
            if isinstance(value.get(key), list):
                return _unwrap_records(value[key])
        return [value]
    return [{"url": str(value)}]


def _value(row: dict, *names: str) -> str:
    lowered = {str(key).lower(): value for key, value in row.items()}
    for name in names:
        value = lowered.get(name.lower())
        if value is not None and str(value).strip():
            return str(value).strip()
    return ""


def _find_url(row: dict) -> str:
    candidate = _value(row, "url", "link", "uri", "href", "trace")
    if candidate:
        match = URL_PATTERN.search(candidate)
        return match.group(0).rstrip(".,);]") if match else candidate
    for value in row.values():
        if isinstance(value, str):
            match = URL_PATTERN.search(value)
            if match:
                return match.group(0).rstrip(".,);]")
    return ""


def _classify_url(url: str, row: dict) -> tuple[str, str, set[str], str]:
    parsed = urlsplit(url)
    host = (parsed.hostname or "").lower()
    provider = _value(row, "provider") or host
    explicit_type = _value(row, "artifact_type", "type")
    path_parts = [part for part in parsed.path.split("/") if part]
    chatgpt = host in {"chatgpt.com", "www.chatgpt.com", "chat.openai.com"}
    conversation_id = ""
    if chatgpt:
        for index, part in enumerate(path_parts[:-1]):
            if part.lower() in {"c", "conversation", "conversations", "share"}:
                conversation_id = path_parts[index + 1]
                break
    artifact_type = explicit_type or (
        "chatgpt_conversation" if chatgpt and conversation_id else "link"
    )
    artifact_id = (
        conversation_id
        or _value(row, "artifact_id", "conversation_id", "id")
        or (path_parts[-1] if path_parts else "")
    )

    flags = set()
    host_and_path = f"{host}{parsed.path}".lower()
    if host and host not in {"localhost", "127.0.0.1", "::1"}:
        flags.add("EXTERNAL")
    if any(term in host_and_path for term in ("pastebin", "paste.ee", "tmpfiles", "transfer.sh")):
        flags.add("EPHEMERAL")
    if any(term in host_and_path for term in ("login", "oauth", "authorize")):
        flags.add("AUTH_REQUIRED")
    return provider, artifact_type, flags, artifact_id


def _normalize(row: dict, resolver: ResolutionAdapter | None = None) -> dict:
    raw_url = _find_url(row)
    safe_url, url_redacted = redact_url(raw_url) if raw_url else ("", False)
    # Clean every value that can leave the input parser before it is persisted.
    safe_values = {}
    any_redacted = url_redacted
    for key, value in row.items():
        safe, did_redact = redact_text(str(value))
        safe_values[str(key).lower()] = safe
        any_redacted = any_redacted or did_redact
    provider, artifact_type, flags, artifact_id = _classify_url(safe_url, safe_values)
    flags = set(flags)
    if url_redacted:
        flags.add("SECRET_REDACTED")
    if any_redacted:
        flags.add("SECRET_REDACTED")

    artifact_id = artifact_id or _value(safe_values, "artifact_id", "conversation_id", "id")
    artifact_id, id_redacted = redact_text(artifact_id)
    if id_redacted:
        flags.add("SECRET_REDACTED")

    evidence_state = "OBSERVED"
    if resolver is not None:
        resolved_state = resolver.resolve(
            {"url": safe_url, "artifact_id": artifact_id, "artifact_type": artifact_type}
        )
        if resolved_state in EVIDENCE_STATES:
            evidence_state = resolved_state

    result = {
        "source": _value(safe_values, "source", "origin") or "trace",
        "provider": provider,
        "artifact_type": artifact_type,
        "artifact_id": artifact_id,
        "timestamp": _value(safe_values, "timestamp", "created_at", "date"),
        "project": _value(safe_values, "project", "project_name"),
        "sensitivity": _value(safe_values, "sensitivity", "classification"),
        "evidence_state": evidence_state,
        "flags": sorted(flags),
        "url": safe_url,
    }
    return result


def scan_records(
    trace_records: list[dict],
    catalog_records: list[dict],
    resolver: ResolutionAdapter | None = None,
) -> list[dict]:
    catalog_ids = set()
    for row in catalog_records:
        item = _normalize(row)
        if item["artifact_id"]:
            catalog_ids.add(item["artifact_id"])

    items = [_normalize(row, resolver) for row in trace_records]
    counts = {}
    for item in items:
        if item["artifact_id"]:
            key = (item["provider"], item["artifact_type"], item["artifact_id"])
            counts[key] = counts.get(key, 0) + 1

    for item in items:
        key = (item["provider"], item["artifact_type"], item["artifact_id"])
        flags = set(item["flags"])
        if item["artifact_id"] and counts[key] > 1:
            flags.add("DUPLICATE")
        if item["artifact_id"] and item["artifact_id"] in catalog_ids:
            if item["evidence_state"] == "OBSERVED":
                item["evidence_state"] = "RESOLVED"
        else:
            flags.add("CATALOG_ABSENT")
        item["flags"] = sorted(flags)
    return items


def write_reports(items: list[dict], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    fields = [
        "source", "provider", "artifact_type", "artifact_id", "timestamp",
        "project", "sensitivity", "evidence_state", "flags", "url",
    ]
    with (output_dir / "provenance.jsonl").open("w", encoding="utf-8") as stream:
        for item in items:
            stream.write(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n")
    with (output_dir / "provenance.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for item in items:
            writer.writerow({**item, "flags": json.dumps(item["flags"])})

    gaps = [item for item in items if "CATALOG_ABSENT" in item["flags"]]
    duplicates = sum("DUPLICATE" in item["flags"] for item in items)
    lines = [
        "# Provenance delta",
        "",
        f"- Scanned: {len(items)}",
        f"- Catalog gaps: {len(gaps)}",
        f"- Duplicate records: {duplicates}",
        "",
        "Catalog gaps indicate items absent from the supplied catalog; they do not imply deletion or manipulation.",
    ]
    if gaps:
        lines.extend(["", "## Missing from catalog"])
        for item in gaps:
            label = item["artifact_id"] or item["url"] or "(unidentified artifact)"
            lines.append(f"- `{label}` ({item['provider'] or 'unknown provider'})")
    (output_dir / "delta.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path, help="newline, CSV, JSON, or JSONL link trace")
    parser.add_argument("catalog", type=Path, help="provenance catalog export")
    parser.add_argument("--output-dir", type=Path, default=Path("provenance-report"))
    args = parser.parse_args(argv)
    try:
        items = scan_records(_read_records(args.trace), _read_records(args.catalog))
        write_reports(items, args.output_dir)
    except (OSError, UnicodeError, csv.Error) as error:
        print(f"provenance-gap-scanner: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
