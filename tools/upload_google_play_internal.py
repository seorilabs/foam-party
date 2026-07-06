#!/usr/bin/env python3
import argparse
import base64
import json
import os
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore", category=FutureWarning)

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "play-store" / "google-play.config.json"
ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
DEFAULT_TIMEOUT_SECONDS = 300
DEFAULT_RETRIES = 5


def load_config():
    with CONFIG_PATH.open(encoding="utf-8") as file:
        return json.load(file)


def decode_service_account_secret():
    raw_json = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
    encoded_json = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64")
    json_file = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_FILE")
    configured = [value for value in (raw_json, encoded_json, json_file) if value]
    if len(configured) > 1:
        raise RuntimeError("Set only one of GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64, or GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_FILE.")
    if raw_json:
        return json.loads(raw_json)
    if encoded_json:
        return json.loads(base64.b64decode(encoded_json).decode("utf-8"))
    if json_file:
        with Path(json_file).expanduser().open(encoding="utf-8") as file:
            return json.load(file)
    return None


def make_publisher(timeout_seconds):
    try:
        import google.auth
        import google_auth_httplib2
        import httplib2
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
    except ImportError as error:
        raise RuntimeError("Install google-api-python-client google-auth google-auth-httplib2 httplib2.") from error

    info = decode_service_account_secret()
    if info:
        credentials = service_account.Credentials.from_service_account_info(info, scopes=[ANDROID_PUBLISHER_SCOPE])
    else:
        credentials, _project_id = google.auth.default(scopes=[ANDROID_PUBLISHER_SCOPE])

    http = httplib2.Http(timeout=timeout_seconds)
    try:
        http.redirect_codes = http.redirect_codes - {308}
    except AttributeError:
        pass
    authed_http = google_auth_httplib2.AuthorizedHttp(credentials, http=http)
    return build("androidpublisher", "v3", http=authed_http, cache_discovery=False)


def execute(request, retries):
    return request.execute(num_retries=retries)


def default_notes(config, language):
    notes = config.get("release", {}).get("releaseNotes", {})
    if isinstance(notes, dict):
        if notes.get(language):
            return notes[language]
        for value in notes.values():
            if value:
                return value
    return "Initial internal testing build."


def resolve_track(publisher, package_name, edit_id, requested_track, retries):
    try:
        response = execute(publisher.edits().tracks().list(packageName=package_name, editId=edit_id), retries)
    except Exception:
        return requested_track
    tracks = {track.get("track") for track in response.get("tracks", [])}
    if requested_track in tracks:
        return requested_track
    aliases = {"internal": "qa", "qa": "internal"}
    alias = aliases.get(requested_track)
    return alias if alias in tracks else requested_track


def upload(args):
    package_name = args.package_name
    aab_path = Path(args.aab_path).resolve()
    if not aab_path.exists():
        raise FileNotFoundError(f"AAB file does not exist: {aab_path}")
    if not args.release_notes:
        raise RuntimeError("Release notes are required.")

    publisher = make_publisher(args.timeout_seconds)
    edit = execute(publisher.edits().insert(packageName=package_name, body={}), args.retries)
    edit_id = edit["id"]
    try:
        from googleapiclient.http import MediaFileUpload

        media = MediaFileUpload(str(aab_path), mimetype="application/octet-stream", chunksize=16 * 1024 * 1024, resumable=True)
        bundle = execute(publisher.edits().bundles().upload(packageName=package_name, editId=edit_id, media_body=media), args.retries)
        version_code = int(bundle["versionCode"])
        track = resolve_track(publisher, package_name, edit_id, args.track, args.retries)
        release = {
            "name": args.release_name,
            "versionCodes": [str(version_code)],
            "status": args.release_status,
            "releaseNotes": [{"language": args.release_notes_language, "text": args.release_notes}],
        }
        execute(
            publisher.edits().tracks().update(
                packageName=package_name,
                editId=edit_id,
                track=track,
                body={"track": track, "releases": [release]},
            ),
            args.retries,
        )
        commit_args = {"packageName": package_name, "editId": edit_id}
        if args.changes_not_sent_for_review:
            commit_args["changesNotSentForReview"] = True
        try:
            committed = execute(publisher.edits().commit(**commit_args), args.retries)
        except Exception as commit_error:
            if not args.changes_not_sent_for_review or "changesNotSentForReview must not be set" not in str(commit_error):
                raise
            commit_args.pop("changesNotSentForReview", None)
            committed = execute(publisher.edits().commit(**commit_args), args.retries)
        return {
            "packageName": package_name,
            "requestedTrack": args.track,
            "track": track,
            "releaseStatus": args.release_status,
            "versionCode": version_code,
            "editId": committed["id"],
            "aabPath": str(aab_path),
        }
    except Exception:
        try:
            execute(publisher.edits().delete(packageName=package_name, editId=edit_id), args.retries)
        except Exception as cleanup_error:
            print(f"Warning: failed to delete Google Play edit {edit_id}: {cleanup_error}", file=sys.stderr)
        raise


def main():
    config = load_config()
    release = config.get("release", {})
    default_language = config.get("defaultLanguage", "en-US")
    default_aab = ROOT / release.get("aabPath", "build/android/foam-party-internal.aab")

    parser = argparse.ArgumentParser(description="Upload a signed AAB to Google Play internal testing.")
    parser.add_argument("--package-name", default=config.get("packageName"))
    parser.add_argument("--aab-path", default=str(default_aab))
    parser.add_argument("--track", default=release.get("track", "internal"))
    parser.add_argument("--release-status", choices=["draft", "completed"], default="draft")
    parser.add_argument("--release-name", default=release.get("name", "foam-party 0.1.0 internal"))
    parser.add_argument("--release-notes-language", default=default_language)
    parser.add_argument("--release-notes", default=default_notes(config, default_language))
    parser.add_argument("--changes-not-sent-for-review", action="store_true")
    parser.add_argument("--timeout-seconds", type=int, default=int(os.environ.get("GOOGLE_PLAY_API_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS)))
    parser.add_argument("--retries", type=int, default=int(os.environ.get("GOOGLE_PLAY_API_RETRIES", DEFAULT_RETRIES)))
    args = parser.parse_args()

    try:
        print(json.dumps(upload(args), ensure_ascii=False, indent=2))
        return 0
    except Exception as error:
        print(f"Google Play internal upload failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
