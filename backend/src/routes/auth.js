/**
 * 用户域：POST /v1/auth/login、GET/POST /v1/auth/profile
 * 演示环境签发随机 token；生产替换为 AGC 账号服务（华为账号 / 手机号验证码）。
 */
import { ok, fail, readBody } from '../response.js'
import { getDb, issueToken, tx, upsertUser } from '../store.js'

export async function login(req, res) {
  const body = await readBody(req)
  const uid = String(body.uid || '').trim()
  if (!uid) {
    fail(res, 4001, 'uid is required')
    return
  }
  const user = upsertUser({
    uid,
    nickname: body.nickname ? String(body.nickname) : '',
    phone: body.phone ? String(body.phone) : '',
    registerType: body.registerType === 'HUAWEI' ? 'HUAWEI' : 'PHONE',
    avatar: body.avatar ? String(body.avatar) : ''
  })
  const token = issueToken(uid)
  ok(res, {
    token,
    uid: user.uid,
    nickname: user.nickname,
    avatar: user.avatar,
    isNew: Date.now() - user.createdAt < 3000
  })
}

export async function profile(req, res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const d = getDb()
  const user = d.users[uid]
  if (!user) {
    fail(res, 4010, 'user not found')
    return
  }
  ok(res, user)
}

/** 更新资料：昵称/头像（对应端侧 UserService 改资料，跨设备经账号同步域合并） */
export async function updateProfile(req, res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return
  }
  const body = await readBody(req)
  const nickname = String(body.nickname || '').trim()
  const avatar = String(body.avatar || '').trim()
  if (nickname === '' && avatar === '') {
    fail(res, 4001, 'nickname or avatar is required')
    return
  }
  if (nickname.length > 20) {
    fail(res, 4001, 'nickname too long (max 20 chars)')
    return
  }
  const user = tx((d) => {
    const u = d.users[uid]
    if (!u) {
      return null
    }
    if (nickname) {
      u.nickname = nickname
    }
    if (avatar) {
      u.avatar = avatar
    }
    u.profileUpdatedAt = Date.now()
    return u
  })
  if (!user) {
    fail(res, 4010, 'user not found')
    return
  }
  ok(res, user, 'profile updated')
}
