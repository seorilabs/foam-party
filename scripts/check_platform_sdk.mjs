#!/usr/bin/env node
/**
 * vendoring한 플랫폼 SDK가 Release archive와 같은지 확인한다.
 *
 * GDScript에는 패키지 매니저가 없어서 파일을 복사해 온다. 복사본은 조용히
 * 갈라지므로 SDK를 올릴 때는 파일을 직접 고치지 말고 Platform Release의
 * tarball과 `.sha256`을 검증한 뒤 통째로 교체한다.
 *
 * - tree 체크섬: 배포 파일 전체(`VERSION`·`SOURCE` 포함)가 archive와 같은지 본다.
 *   archive의 `CHECKSUM`은 Release 파이프라인의 tree 체크섬이고, 그 규칙은
 *   `lib/vendored_tree_checksum.mjs`가 그대로 옮겨 놓았다.
 * - 판올림 신원: 체크섬은 tree가 기록된 `CHECKSUM`과 맞는지만 말한다. 그 tree가
 *   어느 release인지는 말하지 않으므로 `VERSION`·`SOURCE`·`SDK_VERSION`이 서로를
 *   가리키는지 따로 본다.
 * - iOS pack: Platform 인증이 읽는 `GoogleService-Info.plist`가 iOS export에 포함되는지 본다.
 */
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { collectVendoredFiles, computeVendoredTreeChecksum } from "./lib/vendored_tree_checksum.mjs";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const addonDir = join(repoRoot, "godot", "addons", "seorilabs_platform");
const exportPresetsFile = join(repoRoot, "godot", "export_presets.cfg");

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (!existsSync(addonDir) || !statSync(addonDir).isDirectory()) {
  fail(`플랫폼 SDK가 vendoring되어 있지 않다: ${addonDir}`);
}

for (const name of ["CHECKSUM", "VERSION", "SOURCE", "platform_client.gd"]) {
  if (!existsSync(join(addonDir, name))) {
    fail(`${name} 파일이 없다. Release archive에서 함께 복사해라.`);
  }
}

const expected = readFileSync(join(addonDir, "CHECKSUM"), "utf8").trim();
const version = readFileSync(join(addonDir, "VERSION"), "utf8").trim();
const actual = computeVendoredTreeChecksum(collectVendoredFiles(addonDir));

if (actual !== expected) {
  fail(
    [
      "vendoring한 SDK가 Release archive와 다르다.",
      `  기록: ${expected}`,
      `  실제: ${actual}`,
      "",
      "여기서 직접 고치지 마라. Platform Release의 tarball로 통째로 교체한다.",
    ].join("\n"),
  );
}
console.log(`플랫폼 SDK v${version} 체크섬 일치: ${actual}`);

const clientVersion = /^const SDK_VERSION := "(.*)"$/mu.exec(
  readFileSync(join(addonDir, "platform_client.gd"), "utf8"),
)?.[1];

if (!version || !clientVersion) {
  fail("플랫폼 SDK 버전을 읽지 못했다.");
}
if (version !== clientVersion) {
  fail(`VERSION(${version})과 platform_client.gd의 SDK_VERSION(${clientVersion})이 다르다.`);
}
console.log(`플랫폼 SDK 버전 일치: ${version}`);

const source = readFileSync(join(addonDir, "SOURCE"), "utf8").trim();
const expectedSource = `https://github.com/seorilabs/platform/releases/download/v${version}/seorilabs-platform-gdscript-${version}.tar.gz`;
if (source !== expectedSource) {
  fail("플랫폼 SDK SOURCE가 고정 release asset이 아니다.");
}
if (!existsSync(join(addonDir, "core", "presence_client.gd"))) {
  fail("플랫폼 Presence SDK가 없다.");
}
console.log(`플랫폼 SDK release 출처 일치: ${source}`);

/** export_presets.cfg의 [preset.0](iOS) 섹션에서 include_filter 값을 읽는다. */
function iosIncludeFilter(text) {
  let inIosPreset = false;
  for (const line of text.split(/\r?\n/u)) {
    if (line === "[preset.0]") {
      inIosPreset = true;
      continue;
    }
    if (!inIosPreset) continue;
    if (line.startsWith("[")) break;
    const matched = /^include_filter="(.*)"$/u.exec(line);
    if (matched) return matched[1];
  }
  return "";
}

const includeFilters = iosIncludeFilter(readFileSync(exportPresetsFile, "utf8")).split(",");
if (!includeFilters.includes("GoogleService-Info.plist")) {
  fail("iOS export must include GoogleService-Info.plist in the Godot resource pack.");
}
console.log("iOS export pack에 GoogleService-Info.plist 포함 확인");
