# Mothership
mothershipconnector

## Provenance gap scanner

Scan a newline-delimited, CSV, JSON, or JSONL link trace against an exported
provenance catalog:

```sh
python3 tools/provenance_gap_scanner.py link-trace.jsonl provenance-catalog.csv \
  --output-dir build/provenance
```

The scanner writes `provenance.jsonl`, `provenance.csv`, and `delta.md` to the
output directory. It does not fetch or resolve links; catalog gaps mean only
that an artifact was absent from the supplied catalog. Obvious OAuth, JWT, and
signed-URL credentials are redacted before reports are written.
