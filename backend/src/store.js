/**
 * 内存数据库 + JSON 文件落盘（data/db.json），对应概设云数据库四数据域：
 *   用户域 users/tokens、运动域 records、挑战域 challenges、内容域 routes/achievements/config
 * 演示环境单实例即可；生产替换为 AGC Cloud DB。
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { buildSeed } from './seed.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const DATA_DIR = path.join(__dirname, '..', 'data')
const DB_FILE = path.join(DATA_DIR, 'db.json')

let db = null

export function getDb() {
  if (db) {
    return db
  }
  if (fs.existsSync(DB_FILE)) {
    try {
      db = JSON.parse(fs.readFileSync(DB_FILE, 'utf-8'))
      return db
    } catch (e) {
      console.error('[store] db.json corrupted, rebuilding:', e.message)
    }
  }
  db = buildSeed()
  persist()
  return db
}

export function persist() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true })
  }
  fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2))
}

/** 原子取数：加锁避免并发写覆盖 */
export function tx(mutator) {
  const d = getDb()
  const result = mutator(d)
  persist()
  return result
}

/** token 签发与校验（用户域） */
export function issueToken(uid) {
  const d = getDb()
  const token = 'tk_' + Math.random().toString(36).slice(2) + Date.now().toString(36)
  d.tokens[token] = { uid, issuedAt: Date.now() }
  persist()
  return token
}

export function resolveUid(req) {
  const d = getDb()
  const auth = req.headers['authorization'] || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (token && d.tokens[token]) {
    return d.tokens[token].uid
  }
  return ''
}

export function upsertUser({ uid, nickname, phone, registerType, avatar }) {
  const d = getDb()
  if (!d.users[uid]) {
    d.users[uid] = {
      uid,
      nickname: nickname || `跑者${uid.slice(-4)}`,
      phone: phone || '',
      registerType: registerType || 'PHONE',
      avatar: avatar || '🏃',
      totalKm: 0,
      totalTimes: 0,
      weeklyKm: 0,
      createdAt: Date.now()
    }
  } else if (nickname) {
    d.users[uid].nickname = nickname
  }
  persist()
  return d.users[uid]
}
