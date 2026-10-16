/**
 * 社交域（对应端侧 CommunityService，概设 M5 社交）：
 *   GET  /v1/community/runners           推荐跑友（非好友的校园用户）
 *   GET  /v1/community/friends           我的好友
 *   POST /v1/community/friend/add        添加跑友 {userId}
 *   GET  /v1/community/posts             动态流（我的图文/转发/分享 + 校园种子动态）
 *   POST /v1/community/moment            发布微博式图文动态 {text, images}
 *   POST /v1/community/share             分享一条运动记录 {recordId, aiContent, summary...}
 *   POST /v1/community/post/:id/like     点赞/取消点赞（幂等切换）
 *   POST /v1/community/post/:id/forward  转发（不可重复转发同一条）
 */
import { ok, fail, readBody } from '../response.js'
import { getDb, tx, upsertUser } from '../store.js'

function requireUid(res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return false
  }
  return true
}

function findCommunityUser(d, id) {
  if (id === 'me') {
    return null
  }
  return d.communityUsers.find((u) => u.id === id) || null
}

/** 把种子动态/用户分享动态统一成 feed 条目，并叠加当前用户点赞/转发状态 */
function decoratePost(d, uid, p, isMe, authorOverride) {
  const liked = (d.postLikes[uid] || []).includes(p.id)
  const forwarded = (d.postForwards[uid] || []).includes(p.id)
  const author = authorOverride || findCommunityUser(d, p.authorId)
  return {
    ...p,
    authorName: authorOverride ? authorOverride.nickname : (author ? author.name : '跑者'),
    authorAvatar: authorOverride ? authorOverride.avatar : (author ? author.avatar : '🏃'),
    isMe,
    likes: (p.baseLikes || 0) + (liked ? 1 : 0),
    forwards: (p.baseForwards || 0) + (forwarded ? 1 : 0),
    likedByMe: liked,
    forwardedByMe: forwarded
  }
}

/** 我的动态流 = 我的图文动态 + 我的转发 + 我分享的记录 + 校园种子动态 */
function buildFeed(d, uid) {
  const me = d.users[uid] || upsertUser({ uid })
  const posts = []

  for (const m of d.moments[uid] || []) {
    posts.push({
      id: m.id, authorId: 'me', content: m.text !== '' ? m.text : '分享了图片',
      kind: 'moment', images: m.images, sportType: 0,
      distanceM: 0, durationS: 0, paceSecPerKm: 0, calorie: 0,
      startTs: m.ts, baseLikes: 0, baseForwards: 0,
      likes: (d.postLikes[uid] || []).includes(m.id) ? 1 : 0,
      forwards: 0,
      likedByMe: (d.postLikes[uid] || []).includes(m.id),
      forwardedByMe: false,
      isMe: true, authorName: me.nickname, authorAvatar: me.avatar
    })
  }

  for (const originId of d.postForwards[uid] || []) {
    const origin = findAnyPost(d, uid, originId)
    if (origin) {
      posts.push({
        id: `repost_${originId}`, authorId: 'me',
        content: `转发了 @${origin.authorName} 的运动记录：${origin.content}`,
        kind: origin.kind, images: origin.images || [],
        sportType: origin.sportType, distanceM: origin.distanceM, durationS: origin.durationS,
        paceSecPerKm: origin.paceSecPerKm, calorie: origin.calorie, startTs: origin.startTs,
        baseLikes: 0, baseForwards: 0, likes: 0, forwards: 0,
        likedByMe: false, forwardedByMe: false,
        isMe: true, authorName: me.nickname, authorAvatar: me.avatar, repostOf: origin.authorName
      })
    }
  }

  for (const s of d.sharedRecords[uid] || []) {
    posts.push({
      id: `share_${s.recordId}`, authorId: 'me', content: s.aiContent || s.defaultContent,
      kind: 'record', images: [],
      sportType: s.type, distanceM: s.distanceM, durationS: s.durationS,
      paceSecPerKm: s.paceSecPerKm, calorie: s.calorie, startTs: s.startTs,
      baseLikes: 0, baseForwards: 0,
      likes: (d.postLikes[uid] || []).includes(`share_${s.recordId}`) ? 1 : 0,
      forwards: 0,
      likedByMe: (d.postLikes[uid] || []).includes(`share_${s.recordId}`),
      forwardedByMe: false,
      isMe: true, fromMyRecord: true, authorName: me.nickname, authorAvatar: me.avatar
    })
  }

  for (const p of d.seedPosts) {
    posts.push(decoratePost(d, uid, p, false, null))
  }
  return posts
}

function findAnyPost(d, uid, postId) {
  const seed = d.seedPosts.find((p) => p.id === postId)
  if (seed) {
    return decoratePost(d, uid, seed, false, null)
  }
  const share = (d.sharedRecords[uid] || []).find((s) => `share_${s.recordId}` === postId)
  if (share) {
    const me = d.users[uid]
    return {
      ...share, id: postId, content: share.aiContent || share.defaultContent,
      authorName: me ? me.nickname : '我', authorAvatar: me ? me.avatar : '🏃'
    }
  }
  return null
}

export async function listRunners(res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const friends = d.friends[uid] || []
  ok(res, d.communityUsers.filter((u) => !friends.includes(u.id)))
}

export async function listFriends(res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const friends = d.friends[uid] || []
  ok(res, d.communityUsers.filter((u) => friends.includes(u.id)))
}

export async function addFriend(req, res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const body = await readBody(req)
  const userId = String(body.userId || '').trim()
  const d = getDb()
  if (!findCommunityUser(d, userId)) {
    fail(res, 4004, `runner not found: ${userId}`)
    return
  }
  tx((db) => {
    db.friends[uid] = db.friends[uid] || []
    if (!db.friends[uid].includes(userId)) {
      db.friends[uid].unshift(userId)
    }
  })
  ok(res, { userId, added: true }, 'friend added')
}

export async function listPosts(res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  ok(res, buildFeed(getDb(), uid))
}

export async function publishMoment(req, res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const body = await readBody(req)
  const text = String(body.text || '')
  const images = Array.isArray(body.images) ? body.images.slice(0, 9).map(String) : []
  if (text === '' && images.length === 0) {
    fail(res, 4001, 'moment text or images required')
    return
  }
  const item = {
    id: `mom_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
    text,
    images,
    ts: Date.now()
  }
  tx((d) => {
    d.moments[uid] = d.moments[uid] || []
    d.moments[uid].unshift(item)
    if (d.moments[uid].length > 50) {
      d.moments[uid].splice(50)
    }
  })
  ok(res, item, 'moment published')
}

export async function shareRecord(req, res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const body = await readBody(req)
  const recordId = String(body.recordId || '').trim()
  if (!recordId) {
    fail(res, 4001, 'recordId is required')
    return
  }
  const aiContent = String(body.aiContent || '')
  const item = {
    recordId,
    aiContent,
    defaultContent: `完成了运动打卡，累计 ${(Number(body.distanceM || 0) / 1000).toFixed(2)} 公里，一起动起来！`,
    type: Number(body.type || 0),
    distanceM: Number(body.distanceM || 0),
    durationS: Number(body.durationS || 0),
    paceSecPerKm: Number(body.paceSecPerKm || 0),
    calorie: Number(body.calorie || 0),
    startTs: Number(body.startTs || Date.now()),
    sharedAt: Date.now()
  }
  const result = tx((d) => {
    d.sharedRecords[uid] = d.sharedRecords[uid] || []
    if (d.sharedRecords[uid].some((s) => s.recordId === recordId)) {
      return { duplicate: true }
    }
    d.sharedRecords[uid].unshift(item)
    return { duplicate: false }
  })
  ok(res, { recordId, shared: true, duplicate: result.duplicate }, 'record shared to feed')
}

export async function toggleLike(res, postId, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  if (!findAnyPost(d, uid, postId) && !(d.moments[uid] || []).some((m) => m.id === postId)) {
    fail(res, 4004, `post not found: ${postId}`)
    return
  }
  const liked = tx((db) => {
    db.postLikes[uid] = db.postLikes[uid] || []
    const idx = db.postLikes[uid].indexOf(postId)
    if (idx >= 0) {
      db.postLikes[uid].splice(idx, 1)
      return false
    }
    db.postLikes[uid].unshift(postId)
    return true
  })
  ok(res, { postId, liked }, liked ? 'liked' : 'unliked')
}

export async function forward(res, postId, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const origin = findAnyPost(d, uid, postId)
  if (!origin) {
    fail(res, 4004, `post not found: ${postId}`)
    return
  }
  if (origin.isMe) {
    fail(res, 4003, 'cannot forward your own post')
    return
  }
  const result = tx((db) => {
    db.postForwards[uid] = db.postForwards[uid] || []
    if (db.postForwards[uid].includes(postId)) {
      return { duplicate: true }
    }
    db.postForwards[uid].unshift(postId)
    return { duplicate: false }
  })
  if (result.duplicate) {
    fail(res, 4009, 'already forwarded')
    return
  }
  ok(res, { postId, forwarded: true }, 'forwarded')
}
