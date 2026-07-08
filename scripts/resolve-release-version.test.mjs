// scripts/resolve-release-version.mjs 단위 테스트. 실행: node --test scripts/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveReleaseVersionForTag } from './resolve-release-version.mjs';

test('SemVer 태그 → apple_build_number (인수조건)', () => {
  const cases = {
    'v0.1.2': '1002',
    'v0.1.3': '1003',
    'v0.2.0': '2000',
    'v1.0.0': '1000000',
  };
  for (const [tag, expected] of Object.entries(cases)) {
    const v = resolveReleaseVersionForTag(tag);
    assert.equal(v.apple_build_number, expected, `${tag} → ${expected}`);
    assert.equal(v.apple_marketing_version, tag.slice(1));
    assert.equal(v.version_name, tag.slice(1));
  }
});

test('build_number는 SemVer 단조 증가', () => {
  const ordered = ['v0.1.2', 'v0.1.3', 'v0.2.0', 'v0.9.999', 'v1.0.0'];
  const nums = ordered.map((t) => Number(resolveReleaseVersionForTag(t).apple_build_number));
  for (let i = 1; i < nums.length; i += 1) {
    assert.ok(nums[i] > nums[i - 1], `${ordered[i]} > ${ordered[i - 1]}`);
  }
});

test('앞으로 태깅할 릴리즈(≥ v0.1.2)는 마지막 론칭 build(4)보다 큼', () => {
  for (const tag of ['v0.1.2', 'v0.1.3', 'v0.2.0', 'v1.0.0', 'v0.1.11']) {
    assert.ok(Number(resolveReleaseVersionForTag(tag).apple_build_number) > 4, tag);
  }
});

test('한 자릿수 0 minor/patch 태그도 허용(v0.1.0·v0.0.1)', () => {
  assert.equal(resolveReleaseVersionForTag('v0.1.0').apple_build_number, '1000');
  assert.equal(resolveReleaseVersionForTag('v0.0.1').apple_build_number, '1');
});

test('잘못된 SemVer 태그는 예외로 거부', () => {
  for (const bad of ['v1.2', 'v01.2.3', 'v1.1000.0', '1.2.3', 'v1.2.3-rc1', 'vx.y.z', '']) {
    assert.throws(() => resolveReleaseVersionForTag(bad), `${bad} 거부`);
  }
});
