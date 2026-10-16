/**
 * 健身域（对应端侧 GymService，M6 健身模块）：
 *   GET  /v1/gym/moves     器械动作库云端下发（健身房 POI 内容域，可热更）
 *   GET  /v1/gym/plan      AI 今日训练计划（按星期轮换训练分化）
 *   POST /v1/gym/workout   训练记录上报（组日志 + 容量/卡路里服务端重算）
 *   GET  /v1/gym/history   我的训练历史与累计统计
 */
import { ok, fail, readBody } from '../response.js'
import { getDb, tx } from '../store.js'

const PLAN_TABLE = [
  ['g_bench', 'g_curl', 'g_crunch', 'g_treadmill'],
  ['g_deadlift', 'g_pullup', 'g_crunch', 'g_row'],
  ['g_squat', 'g_bench', 'g_curl', 'g_treadmill'],
  ['g_pullup', 'g_row', 'g_crunch', 'g_deadlift'],
  ['g_bench', 'g_squat', 'g_crunch', 'g_treadmill'],
  ['g_deadlift', 'g_row', 'g_curl', 'g_treadmill'],
  ['g_squat', 'g_pullup', 'g_crunch', 'g_treadmill']
]
const PLAN_TITLES = ['推力日', '拉力日', '腿臀日', '核心日', '全身日', '有氧日', '综合日']

function requireUid(res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return false
  }
  return true
}

export async function moves(res) {
  const d = getDb()
  ok(res, { version: d.contentVersion || 1, moves: d.gymMoves })
}

export async function plan(res) {
  const d = getDb()
  const day = new Date().getDay()
  const ids = PLAN_TABLE[day % PLAN_TABLE.length]
  const list = ids
    .map((id) => d.gymMoves.find((m) => m.id === id))
    .filter((m) => m)
  ok(res, { title: PLAN_TITLES[day % PLAN_TITLES.length], moves: list })
}

export async function reportWorkout(req, res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const body = await readBody(req)
  const id = String(body.id || '').trim()
  const startTs = Number(body.startTs || 0)
  const endTs = Number(body.endTs || Date.now())
  const setLogs = Array.isArray(body.setLogs) ? body.setLogs : []
  if (!id || startTs <= 0 || setLogs.length === 0) {
    fail(res, 4001, 'id/startTs/setLogs are required')
    return
  }

  // 云端重算为准：训练容量与卡路里按组日志重新计算（不信任端上报值）
  let volumeKg = 0
  const logs = setLogs.slice(0, 200).map((l) => {
    const reps = Math.max(0, Number(l.reps || 0))
    const weightKg = Math.max(0, Number(l.weightKg || 0))
    volumeKg += reps * weightKg
    return {
      moveName: String(l.moveName || '自由训练'),
      moveEmoji: String(l.moveEmoji || '🏋️'),
      setIndex: Number(l.setIndex || 0),
      reps,
      weightKg,
      ts: Number(l.ts || Date.now())
    }
  })
  const minutes = Math.max(15, Math.round((endTs - startTs) / 60000))
  const calories = Math.round(logs.length * 18 + volumeKg * 0.06)

  const workout = {
    id,
    startTs,
    endTs,
    totalSets: logs.length,
    calories,
    volumeKg: Math.round(volumeKg),
    minutes,
    setLogs: logs,
    reportedAt: Date.now()
  }
  const result = tx((d) => {
    d.gymWorkouts[uid] = d.gymWorkouts[uid] || []
    if (d.gymWorkouts[uid].some((w) => w.id === id)) {
      return { duplicate: true }
    }
    d.gymWorkouts[uid].unshift(workout)
    if (d.gymWorkouts[uid].length > 100) {
      d.gymWorkouts[uid].splice(100)
    }
    return { duplicate: false }
  })
  ok(res, { accepted: true, duplicate: result.duplicate, workout }, 'workout accepted')
}

export async function history(res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const list = d.gymWorkouts[uid] || []
  const totals = list.reduce((acc, w) => ({
    times: acc.times + 1,
    sets: acc.sets + w.totalSets,
    volumeKg: acc.volumeKg + w.volumeKg,
    calories: acc.calories + w.calories
  }), { times: 0, sets: 0, volumeKg: 0, calories: 0 })
  ok(res, { workouts: list, totals })
}
