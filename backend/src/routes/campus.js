/**
 * 校园域（对应端侧 CampusService）：
 *   GET  /v1/campus/schools  支持绑定的学校列表
 *   GET  /v1/campus/info     我的校园绑定信息
 *   POST /v1/campus/bind     校园实名绑定（服务端校验：学校白名单 + 学号 6-12 位数字 + 姓名非空）
 *   POST /v1/campus/unbind   解绑
 *   GET  /v1/campus/alumni   校友目录（按绑定学校标注同校）
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

export async function schools(res) {
  const d = getDb()
  ok(res, d.schools)
}

export async function info(res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const b = d.campusBindings[uid]
  if (!b) {
    ok(res, { bound: false, school: '', studentId: '', studentName: '', verified: false, boundTs: 0 })
    return
  }
  ok(res, { bound: true, ...b })
}

export async function bind(req, res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const body = await readBody(req)
  const school = String(body.school || '').trim()
  const studentId = String(body.studentId || '').trim()
  const studentName = String(body.studentName || '').trim()
  const d = getDb()
  if (!d.schools.includes(school)) {
    fail(res, 4001, `unsupported school: ${school || '(empty)'}`)
    return
  }
  if (studentName === '') {
    fail(res, 4001, 'studentName is required')
    return
  }
  if (!/^\d{6,12}$/.test(studentId)) {
    fail(res, 4001, 'studentId must be 6-12 digits')
    return
  }
  const binding = { school, studentId, studentName, verified: true, boundTs: Date.now() }
  tx((db) => {
    db.campusBindings[uid] = binding
  })
  ok(res, { bound: true, ...binding }, 'campus bound')
}

export async function unbind(req, res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  tx((d) => {
    delete d.campusBindings[uid]
  })
  ok(res, { bound: false }, 'campus unbound')
}

export async function alumni(res, uid) {
  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const me = d.users[uid]
  const b = d.campusBindings[uid]
  const mySchool = b ? b.school : ''
  const myName = b ? b.studentName : (me ? me.nickname : '我')
  const list = [
    {
      id: 'me', name: myName, avatar: me ? me.avatar : '🏃',
      school: mySchool || d.schools[0], dept: '我的学院',
      weeklyKm: me ? me.weeklyKm || 0 : 0, isMe: true
    },
    ...d.alumni.map((a) => ({ ...a, isMe: false }))
  ]
  const sameSchool = list.filter((a) => mySchool && a.school === mySchool).length
  ok(res, { alumni: list, sameSchoolCount: Math.max(0, sameSchool - 1) })
}
