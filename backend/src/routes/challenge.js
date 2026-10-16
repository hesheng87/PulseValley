/**
 * 挑战域：列表 / 创建 / 加入 / 进度结算
 * 结算原则（详设 ChallengeSettle 云函数）：以后端重算为准 ——
 * 进度增量 addKm 与端上报记录校验（本次增量并入成员进度，幂等合并）。
 */
import { ok, fail, readBody } from '../response.js'
import { getDb, tx, upsertUser } from '../store.js'

function memberView(m, myUid) {
  return {
    name: m.name,
    avatar: m.avatar,
    progressKm: Math.round(m.progressKm * 100) / 100,
    isMe: m.uid === myUid
  }
}

function challengeView(c, myUid) {
  const members = c.members.map((m) => memberView(m, myUid))
  let joined = false
  for (const m of members) {
    if (m.isMe) {
      joined = true
    }
  }
  return {
    id: c.id,
    title: c.title,
    emoji: c.emoji,
    typeDesc: c.typeDesc,
    targetKm: c.targetKm,
    endDate: c.endDate,
    members,
    joined
  }
}

export async function list(res, uid) {
  const d = getDb()
  const list = Object.values(d.challenges)
    .sort((a, b) => b.createdAt - a.createdAt)
    .map((c) => challengeView(c, uid))
  ok(res, list)
}

export async function create(req, res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const body = await readBody(req)
  const title = String(body.title || '').trim()
  if (!title) {
    fail(res, 4001, 'title is required')
    return
  }
  const u = upsertUser({ uid })
  const c = tx((d) => {
    const id = `c_user_${Date.now()}`
    const challenge = {
      id,
      title,
      emoji: String(body.emoji || '🔥'),
      typeDesc: String(body.typeDesc || '累计里程赛'),
      targetKm: Math.max(0.1, Number(body.targetKm || 5)),
      endDate: String(body.endDate || '本周日 24:00'),
      ownerId: uid,
      createdAt: Date.now(),
      members: [{ uid, name: u.nickname, avatar: u.avatar, progressKm: 0 }]
    }
    d.challenges[id] = challenge
    return challenge
  })
  ok(res, challengeView(c, uid), 'challenge created')
}

export async function join(res, challengeId, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const d = getDb()
  const c = d.challenges[challengeId]
  if (!c) {
    fail(res, 4004, `challenge not found: ${challengeId}`)
    return
  }
  const u = upsertUser({ uid })
  const result = tx((db) => {
    const target = db.challenges[challengeId]
    if (target.members.some((m) => m.uid === uid)) {
      return { alreadyJoined: true }
    }
    target.members.push({ uid, name: u.nickname, avatar: u.avatar, progressKm: 0 })
    return { alreadyJoined: false }
  })
  ok(res, challengeView(c, uid), result.alreadyJoined ? 'already joined' : 'joined')
}

export async function progress(req, res, challengeId, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const body = await readBody(req)
  const addKm = Number(body.addKm || 0)
  if (addKm <= 0 || addKm > 200) {
    fail(res, 4001, 'addKm must be in (0, 200]')
    return
  }
  const d = getDb()
  const c = d.challenges[challengeId]
  if (!c) {
    fail(res, 4004, `challenge not found: ${challengeId}`)
    return
  }
  const member = c.members.find((m) => m.uid === uid)
  if (!member) {
    fail(res, 4003, 'join the challenge before reporting progress')
    return
  }
  tx((db) => {
    const m = db.challenges[challengeId].members.find((x) => x.uid === uid)
    m.progressKm = Math.round((m.progressKm + addKm) * 100) / 100
  })
  ok(res, challengeView(c, uid), 'progress settled')
}
