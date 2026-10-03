import csv
import tempfile
import unittest
from pathlib import Path

from tools.provenance_gap_scanner import (
    _read_records,
    redact_url,
    scan_records,
    write_reports,
)


class ProvenanceGapScannerTests(unittest.TestCase):
    def test_classifies_chatgpt_conversation_and_signed_url(self):
        url = (
            "https://chatgpt.com/c/abc12345-1234-1234-1234-123456789abc"
            "?X-Amz-Signature=private-signature"
        )
        safe_url, redacted = redact_url(url)
        self.assertTrue(redacted)
        self.assertNotIn("private-signature", safe_url)

        items = scan_records([{"url": url}], [])
        self.assertEqual(items[0]["provider"], "chatgpt.com")
        self.assertEqual(items[0]["artifact_type"], "chatgpt_conversation")
        self.assertEqual(items[0]["artifact_id"], "abc12345-1234-1234-1234-123456789abc")
        self.assertIn("SECRET_REDACTED", items[0]["flags"])
        self.assertIn("CATALOG_ABSENT", items[0]["flags"])

    def test_redacts_oauth_and_jwt_material_before_report_output(self):
        jwt = "".join(
            ("eyJhbGciOi", "JIUzI1NiJ9", ".", "eyJzdWIiOiIxMjM0NTY3ODkwIn0", ".", "signaturevalue")
        )
        url = f"https://example.com/resource?access_token=oauth-secret&jwt={jwt}"
        bearer = "Bearer " + "oauth-bearer-secret"
        records = [{"url": url, "project": bearer}]
        items = scan_records(records, [])

        with tempfile.TemporaryDirectory() as directory:
            write_reports(items, Path(directory))
            for name in ("provenance.jsonl", "provenance.csv", "delta.md"):
                report = (Path(directory) / name).read_text(encoding="utf-8")
                self.assertNotIn("oauth-secret", report)
                self.assertNotIn("oauth-bearer-secret", report)
                self.assertNotIn(jwt, report)
                self.assertNotIn(bearer, report)
                if name != "delta.md":
                    self.assertIn("SECRET_REDACTED", report)

    def test_marks_all_duplicate_records_and_catalog_gaps(self):
        repeated = {"url": "https://chatgpt.com/c/conversation-42"}
        cataloged = {"conversation_id": "conversation-42"}
        items = scan_records([repeated, repeated], [cataloged])
        self.assertTrue(all("DUPLICATE" in item["flags"] for item in items))
        self.assertTrue(all("CATALOG_ABSENT" not in item["flags"] for item in items))
        self.assertTrue(all(item["evidence_state"] == "RESOLVED" for item in items))

        missing = scan_records([{"url": "https://chatgpt.com/c/not-in-catalog"}], [])
        self.assertIn("CATALOG_ABSENT", missing[0]["flags"])
        self.assertEqual(missing[0]["evidence_state"], "OBSERVED")

    def test_reads_csv_and_jsonl_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            csv_path = Path(directory) / "trace.csv"
            with csv_path.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.DictWriter(stream, fieldnames=["url", "project"])
                writer.writeheader()
                writer.writerow({"url": "https://example.com/item", "project": "Archive"})
            jsonl_path = Path(directory) / "catalog.jsonl"
            jsonl_path.write_text(
                '{"artifact_id":"item"}\n{"artifact_id":"another"}\n',
                encoding="utf-8",
            )
            self.assertEqual(_read_records(csv_path)[0]["project"], "Archive")
            self.assertEqual(len(_read_records(jsonl_path)), 2)


    def test_splits_concatenated_urls_and_marks_capture_damage(self):
        raw = (
            "noise https://chatgpt.com/c/"
            "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
            "https://example.com/item tail"
        )
        catalog = [{
            "conversation_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        }]
        items = scan_records([{"trace": raw}], catalog)

        self.assertEqual(len(items), 2)
        self.assertEqual(
            items[0]["artifact_id"],
            "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        )
        self.assertEqual(items[0]["evidence_state"], "RESOLVED")
        self.assertEqual(items[1]["url"], "https://example.com/item")
        self.assertTrue(
            all("CAPTURE_DAMAGED" in item["flags"] for item in items)
        )

    def test_local_chatgpt_is_a_conversation_not_external(self):
        item = scan_records([{
            "url": "local-chatgpt:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        }], [])[0]

        self.assertEqual(item["provider"], "local-chatgpt")
        self.assertEqual(item["artifact_type"], "chatgpt_conversation")
        self.assertEqual(
            item["artifact_id"],
            "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        )
        self.assertNotIn("EXTERNAL", item["flags"])

    def test_markdown_report_neutralizes_record_injection(self):
        items = scan_records([{
            "artifact_id": "evidence" + "`" + "\n## Forged section"
        }], [])
        with tempfile.TemporaryDirectory() as directory:
            write_reports(items, Path(directory))
            report = (
                Path(directory) / "delta.md"
            ).read_text(encoding="utf-8")

        self.assertNotIn("\n## Forged section", report)
        self.assertIn("evidence\\` ## Forged section", report)


if __name__ == "__main__":
    unittest.main()
