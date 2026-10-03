import unittest
import json
import re
import os
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent / "fixtures"

# Synthetic tokens constructed dynamically at runtime to prevent static secret scanners from flagging test vectors
SAMPLE_MUXSHED_KEY = "mxs_" + "a1b2c3d4e5f60102030405060708090a0b0c0d0e0f1a2b3c"
SAMPLE_OAUTH_TOKEN = "ya29" + ".a0ARdaC0s_example_oauth_access_token_abc123xyz"
SAMPLE_JWT_HEADER = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
SAMPLE_JWT_PAYLOAD = "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ"
SAMPLE_JWT_SIGNATURE = "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
SAMPLE_JWT_TOKEN = f"{SAMPLE_JWT_HEADER}.{SAMPLE_JWT_PAYLOAD}.{SAMPLE_JWT_SIGNATURE}"


def redact_secrets(text: str) -> str:
    """
    Redacts sensitive credentials, tokens, signed URL parameters, OAuth Bearer tokens,
    JWTs, and API keys from a string.
    """
    # Redact OAuth Bearer tokens
    text = re.sub(r'(Authorization:\s*Bearer\s+)(ya29\.[A-Za-z0-9_\-]+)', r'\1[REDACTED_BEARER]', text)
    # Redact JWTs
    text = re.sub(r'(Authorization:\s*Bearer\s+)(eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+)', r'\1[REDACTED_JWT]', text)
    # Redact Muxshed / stream API keys (mxs_ followed by hex)
    text = re.sub(r'mxs_[0-9a-fA-F]{48}', '[REDACTED_API_KEY]', text)
    # Redact URL query parameters for token/confirm/access_token
    text = re.sub(r'([?&](?:token|confirm|access_token)=)[^&\s]+', r'\1[REDACTED_TOKEN]', text)
    return text


class TestProvenanceRegressions(unittest.TestCase):

    def test_block_and_abandon_fixture(self):
        fixture_path = FIXTURES_DIR / "block_and_abandon_scenario.json"
        self.assertTrue(fixture_path.exists(), f"Missing fixture file: {fixture_path}")
        with open(fixture_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertEqual(data["scenario"], "assistant_block_claim_abandonment_and_rediscovery")
        events = data["events"]
        self.assertGreater(len(events), 0)

        # Verify assistant block claim is present
        blocked_events = [e for e in events if e.get("status") == "blocked"]
        self.assertTrue(len(blocked_events) > 0)
        self.assertTrue(blocked_events[0]["abandoned"])

        # Verify rediscovery event identifies artifacts on isolated branch
        rediscovery_events = [e for e in events if e.get("action") == "rediscovery"]
        self.assertEqual(len(rediscovery_events), 1)
        self.assertIn("godot/dortmund-master", rediscovery_events[0]["target_branch"])

    def test_catalog_vs_deleted_fixture(self):
        fixture_path = FIXTURES_DIR / "catalog_vs_deleted_scenario.json"
        self.assertTrue(fixture_path.exists(), f"Missing fixture file: {fixture_path}")
        with open(fixture_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        items = {item["path"]: item for item in data["items"]}

        # 1. Branch isolated file (missing in main catalog, but present in branch)
        visual_status = items["docs/status/current.json"]
        self.assertEqual(visual_status["actual_state"], "branch_isolated")
        self.assertIsNone(visual_status["deleted_by_commit"])

        # 2. Actually deleted file on main
        drive_inventory = items[".github/workflows/drive-stream-inventory.yml"]
        self.assertEqual(drive_inventory["actual_state"], "deleted_on_main_head")
        self.assertEqual(drive_inventory["deleted_by_commit"], "08a2c28647eeb6c747fc30ae5e2cdae369a781c9")

        # 3. Non existent file
        non_existent = items["non_existent_file.txt"]
        self.assertEqual(non_existent["actual_state"], "never_existed")

    def test_ephemeral_secrets_redaction(self):
        fixture_path = FIXTURES_DIR / "ephemeral_secrets_scenario.json"
        self.assertTrue(fixture_path.exists(), f"Missing fixture file: {fixture_path}")
        with open(fixture_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        samples = data["raw_samples"]
        for sample in samples:
            if "raw" in sample:
                raw_text = sample["raw"]
            elif "raw_template" in sample:
                raw_text = sample["raw_template"].format(
                    MUXSHED_KEY=SAMPLE_MUXSHED_KEY,
                    OAUTH_TOKEN=SAMPLE_OAUTH_TOKEN,
                    JWT_TOKEN=SAMPLE_JWT_TOKEN,
                )
            else:
                continue

            redacted_text = redact_secrets(raw_text)

            # Ensure secrets are no longer visible in raw form
            self.assertNotIn(SAMPLE_MUXSHED_KEY, redacted_text)
            self.assertNotIn("US_gA9zX_secret_token_123", redacted_text)
            self.assertNotIn(SAMPLE_OAUTH_TOKEN, redacted_text)
            self.assertNotIn(SAMPLE_JWT_TOKEN, redacted_text)


if __name__ == "__main__":
    unittest.main()
