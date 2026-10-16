/**
 * 脉动光谷 - 组队挑战服务（M3.1）
 * 演示版：本地种子挑战 + 真实运动记录驱动"我的进度"
 * 生产版：云函数结算 + Push/Live View + 碰一碰元服务入队（架构文档 5.3）
 */
import { Challenge, ChallengeMember, SportRecord } from '../common/Types'
import { StoreService } from './StoreService'

export class ChallengeService {
  private static inited: boolean = false

  /** 首次启动播种两个校园挑战 */
  static ensureSeeded(): void {
    if (ChallengeService.inited) {
      return
    }
    ChallengeService.inited = true
    const store: StoreService = StoreService.getInstance()
    if (store.getChallenges().length > 0) {
      return
    }
    const lake: Challenge = Challenge.of('c_lake_week', '环湖跑团 · 周里程赛', '🏞️',
      '累计里程赛', 30, '本周日 24:00', [
        ChallengeMember.of('阿凯', '🏃', 12.5, false),
        ChallengeMember.of('小曼', '🚺', 9.8, false),
        ChallengeMember.of('我', '🏃', 0, true),
        ChallengeMember.of('大川', '🚴', 6.2, false)
      ], false)
    const night: Challenge = Challenge.of('c_night_trio', '操场夜跑三人组', '🌙',
      '接力赛', 21, '本周五 24:00', [
        ChallengeMember.of('露露', '🏃', 7.4, false),
        ChallengeMember.of('我', '🏃', 0, true),
        ChallengeMember.of('老周', '🏃', 4.1, false)
      ], false)
    store.saveChallenges([lake, night])
  }

  static list(): Challenge[] {
    ChallengeService.ensureSeeded()
    return StoreService.getInstance().getChallenges()
  }

  /** 加入挑战（演示版=本地标记；生产走 /v1/challenge/{id}/join） */
  static join(challengeId: string): void {
    ChallengeService.ensureSeeded()
    const list: Challenge[] = ChallengeService.list()
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === challengeId) {
        list[i].joined = true
        for (let j = 0; j < list[i].members.length; j++) {
          if (list[i].members[j].isMe) {
            list[i].members[j].avatar = '🏃'
          }
        }
        break
      }
    }
    StoreService.getInstance().saveChallenges(list)
  }

  /** 运动完成后把里程同步进我参与的挑战（真实数据驱动进度） */
  static applyRecordProgress(record: SportRecord): void {
    const km: number = record.distanceM / 1000
    if (km <= 0) {
      return
    }
    ChallengeService.ensureSeeded()
    const list: Challenge[] = ChallengeService.list()
    let changed: boolean = false
    for (let i = 0; i < list.length; i++) {
      const c: Challenge = list[i]
      if (!c.joined) {
        continue
      }
      for (let j = 0; j < c.members.length; j++) {
        if (c.members[j].isMe) {
          c.members[j].progressKm = Math.round((c.members[j].progressKm + km) * 100) / 100
          changed = true
        }
      }
    }
    if (changed) {
      StoreService.getInstance().saveChallenges(list)
    }
  }

  /**
   * 创建挑战（用户自建，对应需求文档 8.3 创建挑战）
   * title/typeDesc/targetKm/endDate 由创建页表单输入；创建者自动入队
   */
  static create(title: string, emoji: string, typeDesc: string,
    targetKm: number, endDate: string, teamMode: boolean): Challenge {
    ChallengeService.ensureSeeded()
    const list: Challenge[] = ChallengeService.list()
    const c: Challenge = Challenge.of(`c_user_${Date.now()}`, title, emoji, typeDesc,
      targetKm, endDate, [ChallengeMember.of('我', '🏃', 0, true)], true)
    list.unshift(c)
    StoreService.getInstance().saveChallenges(list)
    return c
  }
}
