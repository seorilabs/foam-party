#!/usr/bin/env node
// vX.Y.Z 릴리즈 태그에서 마켓 버전을 산출한다. (org resolver 이식, Godot·v0.x 대응)
//   apple_marketing_version = X.Y.Z (CFBundleShortVersionString)
//   apple_build_number      = X*1_000_000 + Y*1000 + Z (CFBundleVersion, SemVer 단조 증가)
// Foam Party는 major 0 릴리즈(v0.Y.Z)이므로 org 버전과 달리 major 최소값을 0으로 둔다.
//   예) v0.1.2 → build 1002, v0.2.0 → 2000, v1.0.0 → 1_000_000.
// App Store 워크플로우(godot-deploy-app-store.yml)와 Xcode Cloud ci_pre_xcodebuild.sh 가
// `--tag <tag> --github-output` 로 호출한다.
import { appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const GOOGLE_PLAY_MAX_VERSION_CODE = 2100000000;
const VERSION_SEGMENT_BASE = 1000;
const RELEASE_TAG_PATTERN = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

function parseArgs(argv) {
  const args = new Map();
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--') continue;
    if (!arg.startsWith('--')) throw new Error(`Unexpected argument: ${arg}`);
    const key = arg.slice(2);
    if (key === 'github-output' || key === 'github-step-summary' || key === 'quiet') {
      args.set(key, true);
      continue;
    }
    const value = argv[index + 1];
    if (value == null || value.startsWith('--')) throw new Error(`Missing value for --${key}`);
    args.set(key, value);
    index += 1;
  }
  return args;
}

function readInteger(value, label, { min, max }) {
  if (value == null || value === '') throw new Error(`${label} is required.`);
  if (!/^[0-9]+$/.test(value)) throw new Error(`${label} must be an integer, got: ${value}`);
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < min || (max != null && parsed > max)) {
    throw new Error(`${label} must be between ${min} and ${max ?? 'safe integer max'}, got: ${value}`);
  }
  return parsed;
}

function readReleaseTag(args) {
  const tag = args.get('tag') ?? process.env.RELEASE_TAG ?? process.env.CI_TAG ?? process.env.GITHUB_REF_NAME;
  if (tag == null || tag === '') {
    throw new Error('Release tag is required. Use --tag v1.2.3 or run from a vX.Y.Z git tag.');
  }
  return tag;
}

function parseReleaseTag(tag) {
  const match = RELEASE_TAG_PATTERN.exec(tag);
  if (match == null) throw new Error(`Release tag must use vX.Y.Z numeric SemVer format, got: ${tag}`);
  return {
    releaseTag: tag,
    major: readInteger(match[1], 'major', { min: 0 }),
    minor: readInteger(match[2], 'minor', { min: 0, max: VERSION_SEGMENT_BASE - 1 }),
    patch: readInteger(match[3], 'patch', { min: 0, max: VERSION_SEGMENT_BASE - 1 }),
  };
}

// Pure core: tag string → market version fields. Exported for tests.
export function resolveReleaseVersionForTag(tag) {
  const { releaseTag, major, minor, patch } = parseReleaseTag(tag);
  const buildNumber = major * 1_000_000 + minor * VERSION_SEGMENT_BASE + patch;
  if (buildNumber <= 0) {
    throw new Error(`build_number must be positive (App Store CFBundleVersion), got: ${buildNumber} from ${releaseTag}`);
  }
  if (buildNumber > GOOGLE_PLAY_MAX_VERSION_CODE) {
    throw new Error(`build_number exceeds Google Play versionCode maximum: ${buildNumber}`);
  }
  const versionName = `${major}.${minor}.${patch}`;
  return {
    release_tag: releaseTag,
    version_name: versionName,
    release_major: String(major),
    release_minor: String(minor),
    release_patch: String(patch),
    build_number: String(buildNumber),
    google_play_version_code: String(buildNumber),
    apple_marketing_version: versionName,
    apple_build_number: String(buildNumber),
  };
}

function resolveReleaseVersion(args) {
  return resolveReleaseVersionForTag(readReleaseTag(args));
}

function writeGithubOutput(values) {
  const outputPath = process.env.GITHUB_OUTPUT;
  if (outputPath == null || outputPath === '') throw new Error('GITHUB_OUTPUT is required when --github-output is set.');
  const output = Object.entries(values).map(([key, value]) => `${key}=${value}`).join('\n');
  appendFileSync(outputPath, `${output}\n`);
}

function writeGithubStepSummary(values) {
  const summaryPath = process.env.GITHUB_STEP_SUMMARY;
  if (summaryPath == null || summaryPath === '') return;
  appendFileSync(
    summaryPath,
    [
      '### Release version',
      '',
      `- releaseTag: ${values.release_tag}`,
      `- versionName: ${values.version_name}`,
      `- Apple CFBundleShortVersionString: ${values.apple_marketing_version}`,
      `- Apple CFBundleVersion: ${values.apple_build_number}`,
      '',
    ].join('\n')
  );
}

// Run the CLI only when invoked directly (not when imported by tests).
if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const values = resolveReleaseVersion(args);
    if (args.get('github-output')) writeGithubOutput(values);
    if (args.get('github-step-summary')) writeGithubStepSummary(values);
    if (!args.get('quiet')) console.log(JSON.stringify(values, null, 2));
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}
