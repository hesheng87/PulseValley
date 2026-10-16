/**
 * 排行域：GET /v1/leaderboard?scope=friends|campus|class|school|team
 * Redis ZSet 等价实现：种子榜 + 用户云端累计里程插入排序；
 * 服务端按 token 标记 isMe（客户端无需自行判断）。
 */
import { ok, fail } from '../response.js'
import { getDb } from '../store.js'

const SCOPES = ['friends', 'campus', 'class', 'school', 'team']

export async function board(res, scope, uid) {
  const s = SCOPES.includes(scope) ? scope : 'campus'
  const d = getDb()
  const seeds = d.leaderboards[s] || []
  const entries = seeds.map((e) => ({ ...e, isMe: false }))

  const me = uid ? d.users[uid] : undefined
  if (me && me.totalKm > 0) {
    const deptByScope = {
      friends: '累计里程',
      campus: '我的学院',
      class: '我贡献的里程',
      school: '我的学校',
      team: '跨挑战累计'
    }
    entries.push({
      name: me.nickname,
      avatar: me.avatar,
      km: Math.round(me.totalKm * 10) / 10,
      dept: deptByScope[s],
      isMe: true
    })
  }

  entries.sort((a, b) => b.km - a.km)
  ok(res, { scope: s, entries })
}
