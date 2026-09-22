import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..')
const configPath = path.join(repoRoot, 'play-store', 'google-play.config.json')
const config = JSON.parse(readFileSync(configPath, 'utf8'))

function pngDimensions(relativePath: string): { width: number; height: number } {
  const bytes = readFileSync(path.join(repoRoot, relativePath))
  expect(bytes.subarray(1, 4).toString('ascii')).toBe('PNG')
  return {
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
  }
}

describe('Google Play source of truth', () => {
  it('contains English and Korean listing text and release notes', () => {
    for (const locale of ['en-US', 'ko-KR']) {
      expect(config.storeListing.appName[locale]).toBeTruthy()
      expect(config.storeListing.shortDescription[locale]).toBeTruthy()
      expect(config.storeListing.fullDescription[locale]).toBeTruthy()
      expect(config.release.releaseNotes[locale]).toBeTruthy()
    }
    expect(config.release.track).toBe('production')
  })

  // 버전은 릴리즈 태그가 정한다. 마켓 config JSON은 version authority가 아니므로
  // 값이 남아 있으면 중앙 워크플로우의 artifact readback 대조가 어긋난다.
  it('keeps no version authority in the market config', () => {
    expect(config.release.versionName).toBeUndefined()
    expect(config.release.versionCode).toBeUndefined()
    expect(config.release.name).toBeUndefined()
  })

  it('tracks the exact feature graphic and tablet screenshot dimensions', () => {
    expect(pngDimensions(config.assets.featureGraphic)).toEqual({ width: 1024, height: 500 })

    const tabletSets = [
      { paths: config.assets.sevenInchTabletScreenshots, width: 1080, height: 1920 },
      { paths: config.assets.tenInchTabletScreenshots, width: 1800, height: 3200 },
    ]
    for (const tabletSet of tabletSets) {
      expect(tabletSet.paths).toHaveLength(8)
      for (const screenshotPath of tabletSet.paths) {
        expect(pngDimensions(screenshotPath)).toEqual({
          width: tabletSet.width,
          height: tabletSet.height,
        })
      }
    }
  })

  it('keeps the production launch state and its evidence explicit', () => {
    // 2026-07-18 에는 한국 개발자 Account Details 미완으로 production commit 이 거부돼
    // draft 에 머물렀다. 2026-09-22 승격에서 재현되지 않아 completed 로 올라갔다.
    // 원장이 실제 트랙 상태를 따라가는지만 고정하고 특정 시점 값을 박아 두지 않는다.
    expect(config.release.productionLaunch.currentStatus).toBe('completed')
    expect(config.release.productionLaunch.intendedStatus).toBe('completed')
    expect(config.release.productionLaunch.versionCode).toBe(1003012)
    expect(config.release.productionLaunch.evidence).toContain('"releaseStatus":"completed"')
    expect(config.adMob.androidRewardedAdUnits.coin_double).toContain('확정 필요')
    expect(config.adMob.androidRewardedAdUnits.star_rescue).toContain('확정 필요')

    const marketDoc = readFileSync(path.join(repoRoot, 'docs', '05-markets', 'google-play.md'), 'utf8')
    expect(marketDoc).toContain('Production track (2026-09-22): `1.3.18` / versionCode `1003012` / `completed`')
  })
})
