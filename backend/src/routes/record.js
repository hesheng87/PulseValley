/**
 * 运动域：POST /v1/record/summary（风控防作弊校验）、GET /v1/record/list
 * 对应《详细设计文档》"云端重算为准，不信端上报"原则：
 *   1. 人体速度红线：distanceM / durationS > 10 m/s → 拒绝（记入 cheat_record）
 *   2. 单次里程上限：> 200km → 拒绝
 *   3. 无 GPS 轨迹（pointCount=0）却上报超长里程 → 拒绝（步数估算上限 10km）
 * 通过后：落库 records、累计进用户统计、并入五维榜单里程。
 */
import { ok, fail, readBody } from '../response.js'
import { getDb, tx, upsertUser } from '../store.js'

const MAX_HUMAN_SPEED_MPS = 10.0
const MAX_SINGLE_DISTANCE_M = 200 * 1000
const MAX_NO_GPS_DISTANCE_M = 10 * 1000

export async function reportSummary(req, res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const body = await readBody(req)
  const id = String(body.id || '')
  const distanceM = Number(body.distanceM || 0)
  const durationS = Number(body.durationS || 0)
  if (!id || distanceM <= 0 || durationS <= 0) {
    fail(res, 4001, 'id/distanceM/durationS are required and must be positive')
    return
  }

  // ---- 风控域：cheat_record 校验 ----
  const reasons = []
  if (distanceM / durationS > MAX_HUMAN_SPEED_MPS) {
    reasons.push(`avg speed ${(distanceM / durationS).toFixed(2)} m/s exceeds human limit ${MAX_HUMAN_SPEED_MPS}`)
  }
  if (distanceM > MAX_SINGLE_DISTANCE_M) {
    reasons.push(`single distance ${distanceM}m exceeds limit`)
  }
  if (!Number(body.pointCount) && distanceM > MAX_NO_GPS_DISTANCE_M) {
    reasons.push('no GPS points but distance > 10km (step-estimate cap)')
  }
  if (reasons.length > 0) {
    tx((d) => {
      d.cheatRecords = d.cheatRecords || []
      d.cheatRecords.unshift({ uid, recordId: id, reasons, ts: Date.now() })
      if (d.cheatRecords.length > 200) {
        d.cheatRecords.splice(200)
      }
    })
    fail(res, 4030, `cheat check failed: ${reasons.join('; ')}`)
    return
  }

  // ---- 运动域落库 + 用户统计重算 ----
  const summary = tx((d) => {
    d.records[uid] = d.records[uid] || []
    const list = d.records[uid]
    const exist = list.find((r) => r.id === id)
    if (exist) {
      return { duplicate: true }
    }
    list.unshift({
      id,
      type: Number(body.type || 0),
      startTs: Number(body.startTs || 0),
      endTs: Number(body.endTs || 0),
      distanceM,
      durationS,
      steps: Number(body.steps || 0),
      calorie: Number(body.calorie || 0),
      paceSecPerKm: Number(body.paceSecPerKm || 0),
      pointCount: Number(body.pointCount || 0),
      reportedAt: Date.now()
    })
    if (list.length > 500) {
      list.splice(500)
    }
    const u = upsertUser({ uid })
    u.totalKm = Math.round((u.totalKm + distanceM / 1000) * 100) / 100
    u.totalTimes += 1
    u.weeklyKm = Math.round((u.weeklyKm + distanceM / 1000) * 100) / 100
    return { duplicate: false }
  })

  ok(res, {
    accepted: true,
    duplicate: summary.duplicate,
    settleTs: Date.now()
  }, 'summary accepted')
}

export async function listRecords(res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const d = getDb()
  ok(res, d.records[uid] || [])
}
