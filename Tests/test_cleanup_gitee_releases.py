import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parent.parent / "Scripts" / "cleanup-gitee-releases.py"
SPEC = importlib.util.spec_from_file_location("cleanup_gitee_releases", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CleanupRulesTests(unittest.TestCase):
    def test_manifest_keeps_build_and_all_download_tags(self):
        tags = MODULE.manifest_keep_tags("app.json", {
            "build": 3,
            "url": "https://gitee.com/o/r/releases/download/app.3/app.zip",
            "urls": ["https://gitee.com/o/r/releases/download/mirror.3/app.zip"],
        })
        self.assertEqual(tags, {"app.3", "mirror.3"})

    def test_invalid_manifest_fails_closed(self):
        with self.assertRaises(ValueError):
            MODULE.manifest_keep_tags("broken.json", {"build": 0})
        with self.assertRaises(ValueError):
            MODULE.manifest_keep_tags("broken.json", {"build": 2})
        with self.assertRaises(ValueError):
            MODULE.manifest_keep_tags("broken.json", {"build": 2, "url": "https://example.com/app.zip"})

    def test_only_unreferenced_releases_are_deleted(self):
        releases = [
            {"id": 1, "tag_name": "app.2"},
            {"id": 2, "tag_name": "app.1"},
            {"id": 3, "tag_name": "other.7"},
        ]
        kept, deleted = MODULE.partition_releases(releases, {"app.2"})
        self.assertEqual([item["id"] for item in kept], [1])
        self.assertEqual([item["id"] for item in deleted], [2, 3])


if __name__ == "__main__":
    unittest.main()
