#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

repo="${GITEE_REPO:-lanshanshu/release}"
token="${GITEE_TOKEN:-}"
if [[ -z "$token" && -f "$ROOT/secrets/release.env" ]]; then
    token="$(sed -n 's/^GITEE_TOKEN=//p' "$ROOT/secrets/release.env" | head -1)"
fi
if [[ -z "$token" ]]; then
    echo "GITEE_TOKEN is required in the environment or secrets/release.env" >&2
    exit 1
fi

plist="$ROOT/Resources/Info.plist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")"
if command -v md5sum >/dev/null 2>&1; then
    key="$(printf '%s' "$app_id" | md5sum | cut -d' ' -f1)"
else
    key="$(printf '%s' "$app_id" | md5 -q)"
fi
tag="$key.$build"
archive="$ROOT/dist/$key.zip"
manifest="$ROOT/dist/$key.json"
download_url="https://gitee.com/$repo/releases/download/$tag/$key.zip"
notes="${RELEASE_NOTES:-CleanDisk $version，macOS arm64。}"

python3 -m unittest Tests/test_cleanup_gitee_releases.py
swift test
"$ROOT/Scripts/build-app.sh"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/CleanDisk.app" "$archive"

python3 - "$manifest" "$version" "$build" "$download_url" "$notes" <<'PY'
import json, sys
path, version, build, url, notes = sys.argv[1:]
with open(path, "w") as file:
    json.dump({
        "version": version,
        "build": int(build),
        "notes": notes,
        "url": url,
        "urls": [url],
    }, file, ensure_ascii=False, indent=2)
    file.write("\n")
PY

api="https://gitee.com/api/v5/repos/$repo"
curl -fsS "$api?access_token=$token" >/dev/null

branches="$(curl -fsS "$api/branches?access_token=$token")"
count="$(printf '%s' "$branches" | python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)))
except Exception: print(0)')"
if [[ "$count" == "0" ]]; then
    curl -fsS -X POST -H "Content-Type: application/json" \
        "$api/contents/README.md?access_token=$token" \
        -d "$(python3 -c 'import json,base64; print(json.dumps({"content":base64.b64encode(b"# release").decode(),"message":"release","branch":"master"}))')" \
        >/dev/null
    branches="$(curl -fsS "$api/branches?access_token=$token")"
fi
branch="$(printf '%s' "$branches" | python3 -c 'import json,sys
items=json.load(sys.stdin)
print(next((item["name"] for item in items if item["name"] == "master"), items[0]["name"]))')"

existing="$(curl -fsS "$api/releases/tags/$tag?access_token=$token" 2>/dev/null || true)"
release_id="$(printf '%s' "$existing" | python3 -c 'import json,sys
try:
    answer=json.load(sys.stdin)
    print(answer.get("id", "") if isinstance(answer, dict) else "")
except Exception:
    print("")')"
if [[ -z "$release_id" ]]; then
    payload="$(python3 -c 'import json,sys; print(json.dumps({"tag_name":sys.argv[1],"name":sys.argv[1],"body":"-","target_commitish":sys.argv[2],"prerelease":False}))' "$tag" "$branch")"
    curl -fsS -X POST -H "Content-Type: application/json" \
        "$api/releases?access_token=$token" -d "$payload" \
        >"$ROOT/dist/gitee-release.json"
else
    printf '%s' "$existing" >"$ROOT/dist/gitee-release.json"
fi
release_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$ROOT/dist/gitee-release.json")"

attachments="$(curl -fsS "$api/releases/$release_id/attach_files?access_token=$token")"
for name in "$key.zip" "$key.json"; do
    attachment_id="$(printf '%s' "$attachments" | python3 -c 'import json,sys
print(next((str(item["id"]) for item in json.load(sys.stdin) if item["name"] == sys.argv[1]), ""))' "$name")"
    if [[ -n "$attachment_id" ]]; then
        curl -fsS -X DELETE \
            "$api/releases/$release_id/attach_files/$attachment_id?access_token=$token" \
            >/dev/null
    fi
done

curl -fsS -X POST "$api/releases/$release_id/attach_files?access_token=$token" \
    -F "file=@$archive;filename=$key.zip" >/dev/null
curl -fsS -X POST "$api/releases/$release_id/attach_files?access_token=$token" \
    -F "file=@$manifest;filename=$key.json" >/dev/null

pointer="latest/$key.json"
sha="$(curl -fsS "$api/contents/$pointer?ref=$branch&access_token=$token" 2>/dev/null |
    python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("sha", ""))
except Exception: print("")')"
payload="$(python3 -c 'import json,base64,sys
body = {
    "content": base64.b64encode(open(sys.argv[1], "rb").read()).decode(),
    "message": "release",
    "branch": sys.argv[3],
}
if sys.argv[2]: body["sha"] = sys.argv[2]
print(json.dumps(body))' "$manifest" "$sha" "$branch")"
if [[ -n "$sha" ]]; then
    curl -fsS -X PUT -H "Content-Type: application/json" \
        "$api/contents/$pointer?access_token=$token" -d "$payload" >/dev/null
else
    curl -fsS -X POST -H "Content-Type: application/json" \
        "$api/contents/$pointer?access_token=$token" -d "$payload" >/dev/null
fi

if [[ "${RELEASE_SKIP_CLEANUP:-0}" != "1" ]]; then
    python3 "$ROOT/Scripts/cleanup-gitee-releases.py" --delete --repo "$repo"
fi

echo "https://gitee.com/$repo/releases/tag/$tag"
echo "$download_url"
