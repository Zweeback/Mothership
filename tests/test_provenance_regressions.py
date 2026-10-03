import unittest
import json
import re
from pathlib import Path

FIXTURES_DIR = Path(__file__).parent / "fixtures"


def redact_secrets(text: str) -> str:
    """
    Redacts sensitive credentials, tokens, signed URL parameters, OAuth Bearer tokens,
    JWTs, and API keys from a string.
    """
    # Redact OAuth Bearer tokens
    text = re.sub(r'(Authorization:\s*Bearer\s+)(ya29\.[A-Za-z0-9_\-]+)', r'\1[REDACTED_BEARER]', text)
    # Redact JWTs (eyJ...)
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

        synthetic = {
            "<TOKEN_FIXTURE>": "fixture_" + "token_" + "value",
            "<OAUTH_FIXTURE>": "ya" + "29." + "fixture_oauth_value",
            "<JWT_FIXTURE>": ".".join((
                "ey" + "Jheaderpart",
                "ey" + "Jpayloadpart",
                "signaturepart",
            )),
            "<API_KEY_FIXTURE>": "mxs_" + ("ab" * 24),
        }

        for sample in data["raw_samples"]:
            raw_text = sample["raw"]
            for placeholder, value in synthetic.items():
                raw_text = raw_text.replace(placeholder, value)
            redacted_text = redact_secrets(raw_text)

            for value in synthetic.values():
                self.assertNotIn(value, redacted_text)


if __name__ == "__main__":
    unittest.main()
