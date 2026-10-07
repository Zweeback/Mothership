import unittest
import json
import re
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent / "fixtures"

# Synthetic test values are assembled only at runtime so static secret scanners
# do not mistake regression vectors for stored credentials.
SAMPLE_MUXSHED_KEY = "mxs_" + "a1b2c3d4e5f60102030405060708090a0b0c0d0e0f1a2b3c"
SAMPLE_OAUTH_TOKEN = "ya29" + ".a0ARdaC0s_example_oauth_access_token_abc123xyz"
SAMPLE_JWT_HEADER = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
SAMPLE_JWT_PAYLOAD = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
SAMPLE_JWT_SIGNATURE = "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
SAMPLE_JWT_TOKEN = f"{SAMPLE_JWT_HEADER}.{SAMPLE_JWT_PAYLOAD}.{SAMPLE_JWT_SIGNATURE}"
SAMPLE_GDRIVE_TOKEN = "_".join(("US", "gA9zX", "secret", "token", "123"))


def redact_secrets(text: str) -> str:
    """Redact credential-like material from provenance text."""
    text = re.sub(
        r'(Authorization:\\s*Bearer\\s+)(ya29\\.[A-Za-z0-9_\\-]+)',
        r'\\1[REDACTED_BEARER]',
        text,
    )
    text = re.sub(
        r'(Authorization:\\s*Bearer\\s+)(eyJ[A-Za-z0-9_\\-]+\\.eyJ[A-Za-z0-9_\\-]+\\.[A-Za-z0-9_\\-]+)',
        r'\\1[REDACTED_JWT]',
        text,
    )
    text = re.sub(r'mxs_[0-9a-fA-F]{48}', '[REDACTED_API_KEY]', text)
    text = re.sub(
        r'([?&](?:token|confirm|access_token)=)[^&\\s]+',
        r'\\1[REDACTED_TOKEN]',
        text,
    )
    return text


def materialize_sample(sample: dict) -> str:
    """Build synthetic secret-bearing input from a named generator."""
    if "raw" in sample:
        return sample["raw"]

    generator = sample.get("generator")
    generated = {
        "gdrive_signed_url": (
            "https://drive.google.com/uc?export=download"
            "&id=1rONvxcNPn1r41h_ELj5IJ5d7keEmd6Uj"
            f"&confirm=t&token={SAMPLE_GDRIVE_TOKEN}"
        ),
        "pinggy_rtmp_tunnel": f"rtmp://tcp.pinggy.link:43210/live/{SAMPLE_MUXSHED_KEY}",
        "oauth_bearer_header": f"Authorization: Bearer {SAMPLE_OAUTH_TOKEN}",
        "jwt_bearer_header": f"Authorization: Bearer {SAMPLE_JWT_TOKEN}",
        "muxshed_api_key": f"MUXSHED_API_KEY={SAMPLE_MUXSHED_KEY}",
    }
    if generator not in generated:
        raise AssertionError(f"Unknown sample generator: {generator!r}")
    return generated[generator]


class TestProvenanceRegressions(unittest.TestCase):

    def test_block_and_abandon_fixture(self):
        fixture_path = FIXTURES_DIR / "block_and_abandon_scenario.json"
        self.assertTrue(fixture_path.exists(), f"Missing fixture file: {fixture_path}")
        with open(fixture_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertEqual(data["scenario"], "assistant_block_claim_abandonment_and_rediscovery")
        events = data["events"]
        self.assertGreater(len(events), 0)

        blocked_events = [e for e in events if e.get("status") == "blocked"]
        self.assertTrue(len(blocked_events) > 0)
        self.assertTrue(blocked_events[0]["abandoned"])

        rediscovery_events = [e for e in events if e.get("action") == "rediscovery"]
        self.assertEqual(len(rediscovery_events), 1)
        self.assertIn("godot/dortmund-master", rediscovery_events[0]["target_branch"])

    def test_catalog_vs_deleted_fixture(self):
        fixture_path = FIXTURES_DIR / "catalog_vs_deleted_scenario.json"
        self.assertTrue(fixture_path.exists(), f"Missing fixture file: {fixture_path}")
        with open(fixture_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        items = {item["path"]: item for item in data["items"]}

        visual_status = items["docs/status/current.json"]
        self.assertEqual(visual_status["actual_state"], "branch_isolated")
        self.assertIsNone(visual_status["deleted_by_commit"])

        drive_inventory = items[".github/workflows/drive-stream-inventory.yml"]
        self.assertEqual(drive_inventory["actual_state"], "deleted_on_main_head")
        self.assertEqual(
            drive_inventory["deleted_by_commit"],
            "08a2c28647eeb6c747fc30ae5e2cdae369a781c9",
        )

        non_existent = items["non_existent_file.txt"]
        self.assertEqual(non_existent["actual_state"], "never_existed")

    def test_ephemeral_secrets_redaction(self):
        fixture_path = FIXTURES_DIR / "ephemeral_secrets_scenario.json"
        self.assertTrue(fixture_path.exists(), f"Missing fixture file: {fixture_path}")
        with open(fixture_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        samples = data["raw_samples"]
        for sample in samples:
            raw_text = materialize_sample(sample)
            redacted_text = redact_secrets(raw_text)

            self.assertNotIn(SAMPLE_MUXSHED_KEY, redacted_text)
            self.assertNotIn(SAMPLE_GDRIVE_TOKEN, redacted_text)
            self.assertNotIn(SAMPLE_OAUTH_TOKEN, redacted_text)
            self.assertNotIn(SAMPLE_JWT_TOKEN, redacted_text)

        fixture_serialized = json.dumps(data, sort_keys=True)
        self.assertNotIn("{MUXSHED_KEY}", fixture_serialized)
        self.assertNotIn("{OAUTH_TOKEN}", fixture_serialized)
        self.assertNotIn("{JWT_TOKEN}", fixture_serialized)


if __name__ == "__main__":
    unittest.main()
