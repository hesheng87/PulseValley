/**
 * 内容域（云端可热更下发）：
 *   GET  /v1/route/list              校园路线库
 *   GET  /v1/config/route-weights    七维打分权重
 *   POST /v1/config/route-weights    运营热更权重（演示用，生产走 AGC 控制台）
 *   GET  /v1/achievement/meta?since= 勋章元数据增量拉取（版本号比对）
 *   POST /v1/achievement/unlock      勋章全量备份（多设备换机恢复）
 */
import { ok, fail, readBody } from '../response.js'
import { getDb, tx } from '../store.js'

export async function routeList(res) {
  const d = getDb()
  ok(res, { version: d.contentVersion || 1, routes: d.routes })
}

export async function routeWeights(res) {
  const d = getDb()
  ok(res, d.routeWeights)
}

export async function updateRouteWeights(req, res) {
  const body = await readBody(req)
  const keys = ['aqi', 'body', 'uv', 'wind', 'green', 'away', 'pref']
  const next = {}
  let sum = 0
  for (const k of keys) {
    const v = Number(body[k])
    if (!(v >= 0 && v <= 1)) {
      fail(res, 4001, `invalid weight: ${k}`)
      return
    }
    next[k] = v
    sum += v
  }
  if (Math.abs(sum - 1) > 0.001) {
    fail(res, 4001, `weights must sum to 1, got ${sum.toFixed(2)}`)
    return
  }
  tx((d) => {
    d.routeWeights = next
    d.contentVersion = (d.contentVersion || 1) + 1
  })
  ok(res, next, 'route weights updated')
}

export async function achievementMeta(res, since) {
  const d = getDb()
  const meta = d.achievementMeta
  const clientVersion = Number(since || 0)
  if (clientVersion >= meta.version) {
    // 增量拉取：版本不落后则不重复下发
    ok(res, { version: meta.version, updated: false, list: null })
    return
  }
  ok(res, { version: meta.version, updated: true, list: meta.list })
}

export async function unlockBadge(req, res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const body = await readBody(req)
  const badgeId = String(body.badgeId || '').trim()
  if (!badgeId) {
    fail(res, 4001, 'badgeId is required')
    return
  }
  tx((d) => {
    d.unlockedBadges[uid] = d.unlockedBadges[uid] || []
    if (!d.unlockedBadges[uid].includes(badgeId)) {
      d.unlockedBadges[uid].push(badgeId)
    }
  })
  ok(res, { badgeId, backedUp: true }, 'badge backed up to cloud')
}
