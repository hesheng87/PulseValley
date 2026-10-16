/**
 * 健康域（对应端侧 HealthSyncService，华为运动健康 Kit 云端等价）：
 *   POST /v1/health/snapshot   上报健康快照（步数/睡眠/静息心率/卡路里）
 *   GET  /v1/health/snapshot   拉取最近一次健康快照与同步状态
 * 演示环境仅存最近一次快照；生产替换为华为 Health Kit 开放接口。
 */
import { ok, fail, readBody } from '../response.js'
import { getDb, tx } from '../store.js'

function requireUid(res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return false
  }
  return true
}

const RANGES = {
  steps: [0, 300000],
  sleepH: [0, 24],
  restingHr: [30, 220],
  calories: [0, 20000]
}

export async function reportSnapshot(req, res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const body = await readBody(req)
  const snap = {
    steps: Number(body.steps || 0),
    sleepH: Math.round(Number(body.sleepH || 0) * 10) / 10,
    restingHr: Number(body.restingHr || 0),
    calories: Number(body.calories || 0),
    reportedAt: Date.now()
  }
  for (const [key, [min, max]] of Object.entries(RANGES)) {
    if (!(snap[key] >= min && snap[key] <= max)) {
      fail(res, 4001, `invalid ${key}: ${snap[key]} (expected ${min}-${max})`)
      return
    }
  }
  const prev = tx((d) => {
    d.healthSnapshots[uid] = d.healthSnapshots[uid] || { totalSyncCount: 0 }
    const s = d.healthSnapshots[uid]
    const previous = { ...s }
    Object.assign(s, snap)
    s.totalSyncCount = (s.totalSyncCount || 0) + 1
    s.lastSyncTs = Date.now()
    return previous
  })
  ok(res, {
    accepted: true,
    totalSyncCount: getDb().healthSnapshots[uid].totalSyncCount,
    prevSteps: prev.steps || 0
  }, 'health snapshot accepted')
}

export async function getSnapshot(res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const s = d.healthSnapshots[uid]
  if (!s || !s.lastSyncTs) {
    ok(res, { synced: false, lastSyncTs: 0, totalSyncCount: 0 }, 'not synced yet')
    return
  }
  ok(res, { synced: true, ...s })
}
