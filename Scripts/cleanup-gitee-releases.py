#!/usr/bin/env python3
"""Keep only releases referenced by latest/*.json; dry-run unless --delete is given."""

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def manifest_keep_tags(filename, manifest):
    if not filename.endswith(".json"):
        raise ValueError(f"Invalid manifest name: {filename}")
    build = manifest.get("build")
    if not isinstance(build, int) or build <= 0:
        raise ValueError(f"{filename} has no valid build")
    key = filename[:-5]
    tags = {f"{key}.{build}"}
    has_release_url = False
    for value in [*manifest.get("urls", []), manifest.get("url", "")]:
        if not isinstance(value, str) or not value:
            continue
        parsed = urllib.parse.urlparse(value)
        parts = parsed.path.split("/")
        if "download" in parts:
            index = parts.index("download")
            if index + 1 < len(parts) and parts[index + 1]:
                tags.add(urllib.parse.unquote(parts[index + 1]))
                has_release_url = True
    if not has_release_url:
        raise ValueError(f"{filename} has no release download URL")
    return tags


def partition_releases(releases, keep_tags):
    keep, delete = [], []
    for release in releases:
        tag = release.get("tag_name", "")
        target = keep if tag in keep_tags else delete
        target.append(release)
    return keep, delete


def load_token():
    if os.environ.get("GITEE_TOKEN"):
        return os.environ["GITEE_TOKEN"]
    path = Path(__file__).resolve().parent.parent / "secrets" / "release.env"
    if path.exists():
        for line in path.read_text().splitlines():
            if line.startswith("GITEE_TOKEN="):
                return line.split("=", 1)[1].strip()
    raise RuntimeError("GITEE_TOKEN is required in the environment or secrets/release.env")


class GiteeClient:
    def __init__(self, repo, token):
        self.repo = repo
        self.token = token

    def request(self, path, method="GET"):
        separator = "&" if "?" in path else "?"
        url = (
            f"https://gitee.com/api/v5/repos/{self.repo}{path}"
            f"{separator}access_token={urllib.parse.quote(self.token)}"
        )
        request = urllib.request.Request(
            url,
            method=method,
            headers={"User-Agent": "CleanDisk-Release-Cleanup/1.0"},
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"Gitee API {method} {path} failed: HTTP {error.code}") from error
        except urllib.error.URLError as error:
            raise RuntimeError(f"Gitee API {method} {path} failed: {error.reason}") from error

    def releases(self):
        releases = []
        page = 1
        while True:
            batch = self.request(f"/releases?page={page}&per_page=100")
            if not isinstance(batch, list):
                raise RuntimeError("Gitee returned an invalid release list")
            releases.extend(batch)
            if len(batch) < 100:
                return releases
            page += 1

    def latest_manifests(self):
        items = self.request("/contents/latest?ref=master")
        if not isinstance(items, list):
            raise RuntimeError("Gitee returned an invalid latest directory")
        manifests = []
        for item in items:
            name = item.get("name", "")
            if not name.endswith(".json"):
                continue
            document = self.request(f"/contents/latest/{name}?ref=master")
            try:
                content = base64.b64decode(document["content"]).decode("utf-8")
                manifest = json.loads(content)
                manifests.append((name, manifest, manifest_keep_tags(name, manifest)))
            except (KeyError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
                raise RuntimeError(f"Cannot validate latest/{name}: {error}") from error
        if not manifests:
            raise RuntimeError("No latest JSON manifests found; refusing to delete releases")
        return manifests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=os.environ.get("GITEE_REPO", "lanshanshu/release"))
    parser.add_argument("--delete", action="store_true", help="Actually delete unreferenced releases")
    args = parser.parse_args()

    client = GiteeClient(args.repo, load_token())
    # Fetch releases first: anything published by another app while manifests are read
    # will not be in this deletion candidate list.
    releases = client.releases()
    manifests = client.latest_manifests()
    keep_tags = set().union(*(tags for _, _, tags in manifests))
    kept, candidates = partition_releases(releases, keep_tags)

    print(f"Manifests: {len(manifests)}; releases: {len(releases)}")
    print(f"Keeping {len(kept)} releases referenced by latest/*.json")
    for release in sorted(kept, key=lambda item: item.get("tag_name", "")):
        print(f"  KEEP   {release.get('tag_name', '')}")
    print(f"Found {len(candidates)} unreferenced releases")
    for release in sorted(candidates, key=lambda item: item.get("tag_name", "")):
        print(f"  DELETE {release.get('tag_name', '')}")

    if not args.delete:
        print("Dry run only; pass --delete to remove these releases")
        return
    for release in candidates:
        tag = release.get("tag_name", "")
        client.request(f"/releases/{release['id']}", method="DELETE")
        print(f"Deleted {tag}")
    print(f"Deleted {len(candidates)} releases")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
