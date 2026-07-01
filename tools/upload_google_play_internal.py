#!/usr/bin/env python3
import argparse
import base64
import json
import os
import sys
from pathlib import Path

import google.auth
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "play-store" / "google-play.config.json"
DEFAULT_AAB_PATH = ROOT / "build" / "android" / "foam-party.aab"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def load_config():
    with CONFIG_PATH.open(encoding="utf-8") as file:
        return json.load(file)


def default_release_notes(config, language):
    release_notes = config.get("release", {}).get("releaseNotes", {})
    if isinstance(release_notes, dict):
        if release_notes.get(language):
            return release_notes[language]
        default_language = config.get("defaultLanguage")
        if default_language and release_notes.get(default_language):
            return release_notes[default_language]

    return (
        "폼 파티 내부 테스트 빌드입니다. 세차/거품 놀이 게임 플레이와 "
        "기본 진행, 저장, UI 흐름을 확인합니다."
    )


def decode_service_account_secret():
    raw_json = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
    encoded_json = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64")

    if raw_json and encoded_json:
        raise RuntimeError(
            "Set only one of GOOGLE_PLAY_SERVICE_ACCOUNT_JSON or "
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64."
        )

    if raw_json:
        return json.loads(raw_json)

    if encoded_json:
        decoded = base64.b64decode(encoded_json).decode("utf-8")
        return json.loads(decoded)

    return None


def make_android_publisher():
    info = decode_service_account_secret()
    if info:
        credentials = service_account.Credentials.from_service_account_info(
            info,
            scopes=[ANDROID_PUBLISHER_SCOPE],
        )
    else:
        credentials, _project_id = google.auth.default(scopes=[ANDROID_PUBLISHER_SCOPE])

    return build("androidpublisher", "v3", credentials=credentials, cache_discovery=False)


def resolve_version_code(publisher, package_name, edit_id, aab_path, args):
    if args.skip_upload:
        if args.version_code is None:
            raise RuntimeError("--version-code is required when using --skip-upload.")
        return int(args.version_code)

    media = MediaFileUpload(
        str(aab_path),
        mimetype="application/octet-stream",
        chunksize=16 * 1024 * 1024,
        resumable=True,
    )
    bundle = (
        publisher.edits()
        .bundles()
        .upload(packageName=package_name, editId=edit_id, media_body=media)
        .execute()
    )
    return int(bundle["versionCode"])


def upload_internal_release(args):
    config = load_config()
    package_name = args.package_name or config["packageName"]
    aab_path = Path(args.aab_path).resolve()

    if not args.skip_upload and not aab_path.exists():
        raise FileNotFoundError(f"AAB file does not exist: {aab_path}")

    publisher = make_android_publisher()
    edit = publisher.edits().insert(packageName=package_name, body={}).execute()
    edit_id = edit["id"]

    try:
        version_code = resolve_version_code(publisher, package_name, edit_id, aab_path, args)

        release = {
            "name": args.release_name,
            "versionCodes": [str(version_code)],
            "status": args.release_status,
            "releaseNotes": [
                {
                    "language": args.release_notes_language,
                    "text": args.release_notes,
                }
            ],
        }
        track_body = {
            "track": args.track,
            "releases": [release],
        }

        publisher.edits().tracks().update(
            packageName=package_name,
            editId=edit_id,
            track=args.track,
            body=track_body,
        ).execute()

        commit_kwargs = {
            "packageName": package_name,
            "editId": edit_id,
        }
        if args.changes_not_sent_for_review:
            commit_kwargs["changesNotSentForReview"] = True

        committed_edit = publisher.edits().commit(**commit_kwargs).execute()
        return {
            "packageName": package_name,
            "track": args.track,
            "releaseStatus": args.release_status,
            "bundleUploaded": not args.skip_upload,
            "versionCode": version_code,
            "editId": committed_edit["id"],
        }
    except Exception:
        publisher.edits().delete(packageName=package_name, editId=edit_id).execute()
        raise


def main():
    config = load_config()
    release_config = config.get("release", {})
    version_name = release_config.get("versionName", "1.0.0")
    version_code = release_config.get("versionCode", 1)

    parser = argparse.ArgumentParser(
        description="Upload a signed AAB to Google Play internal testing via Android Publisher API."
    )
    parser.add_argument("--package-name", default=config.get("packageName"))
    parser.add_argument("--aab-path", default=str(DEFAULT_AAB_PATH))
    parser.add_argument("--track", default=release_config.get("track", "internal"))
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Create or update a track release from an already uploaded versionCode.",
    )
    parser.add_argument(
        "--version-code",
        type=int,
        help="Existing uploaded versionCode to use with --skip-upload.",
    )
    parser.add_argument(
        "--release-status",
        choices=["draft", "completed"],
        default="draft",
        help="Use draft for first automation runs; completed makes it available to internal testers.",
    )
    parser.add_argument(
        "--release-name",
        default=f"foam-party {version_name} ({version_code})",
    )
    parser.add_argument("--release-notes-language", default=config.get("defaultLanguage", "en-US"))
    parser.add_argument(
        "--release-notes",
        default=None,
    )
    parser.add_argument(
        "--changes-not-sent-for-review",
        action="store_true",
        help="Commit the edit with changesNotSentForReview=true.",
    )
    args = parser.parse_args()
    if args.release_notes is None:
        args.release_notes = default_release_notes(config, args.release_notes_language)

    try:
        result = upload_internal_release(args)
    except Exception as error:
        print(f"Google Play release update failed: {error}", file=sys.stderr)
        return 1

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
