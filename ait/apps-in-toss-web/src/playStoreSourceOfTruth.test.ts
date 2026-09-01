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

  it('keeps the production draft and Korean account blocker explicit', () => {
    expect(config.release.productionLaunch.currentStatus).toBe('draft')
    expect(config.release.productionLaunch.intendedStatus).toBe('completed')
    expect(config.release.productionLaunch.blocker).toContain('Account Details')
    expect(config.release.productionLaunch.commitError).toContain('Korean law')
    expect(config.adMob.androidRewardedAdUnits.coin_double).toContain('확정 필요')
    expect(config.adMob.androidRewardedAdUnits.star_rescue).toContain('확정 필요')

    const marketDoc = readFileSync(path.join(repoRoot, 'docs', '05-markets', 'google-play.md'), 'utf8')
    expect(marketDoc).toContain('Production track: `1.0.0` / versionCode `1000000` / `draft`')
    expect(marketDoc).toContain('Account Details')
  })
})
