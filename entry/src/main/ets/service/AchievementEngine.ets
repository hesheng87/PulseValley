/**
 * 脉动光谷 - 成就引擎（M4）
 * 端侧规则引擎：运动完成事件 → 规则匹配 → 解锁勋章；幂等（unlockedSet 持久化）
 * 对应《详细设计文档》6.1/6.2
 */
import { BadgeDef, EnvSnapshot, SportRecord, SportType } from '../common/Types'
import { StoreService } from './StoreService'

export class AchievementEngine {
  /** 勋章目录（生产由云端 achievement_meta 规则 DSL 下发，此处为端侧等价目录） */
  static getCatalog(): BadgeDef[] {
    return [
      BadgeDef.of('first_run', '首跑启程', '🚀', '完成第一次运动记录'),
      BadgeDef.of('night_runner', '夜跑侠', '🌙', '20:00 后完成一次 3km+ 夜跑'),
      BadgeDef.of('eco_runner', '清风跑者', '🍃', 'AQI≤50 优级空气下完成跑步'),
      BadgeDef.of('km_10', '十里少年', '🏅', '累计运动里程达 10 公里'),
      BadgeDef.of('km_50', '越野新秀', '🎖️', '累计运动里程达 50 公里'),
      BadgeDef.of('km_100', '百公里传奇', '🏆', '累计运动里程达 100 公里'),
      BadgeDef.of('streak_3', '三日不辍', '📅', '连续 3 天完成运动'),
      BadgeDef.of('streak_7', '七日之约', '🔥', '连续 7 天完成运动'),
      BadgeDef.of('challenge_join', '组队出征', '🤝', '加入一个组队挑战')
    ]
  }

  static getById(id: string): BadgeDef | undefined {
    const catalog: BadgeDef[] = AchievementEngine.getCatalog()
    for (let i = 0; i < catalog.length; i++) {
      if (catalog[i].id === id) {
        return catalog[i]
      }
    }
    return undefined
  }

  /**
   * 运动完成时触发判定，返回本次新解锁的勋章（可能为空数组）
   * record: 本次记录；statsAfter: 更新后的累计统计
   */
  static evaluateOnFinish(record: SportRecord, statsAfterTotalKm: number,
    streakDays: number, env: EnvSnapshot): BadgeDef[] {
    const store: StoreService = StoreService.getInstance()
    const unlocked: string[] = store.getUnlockedBadgeIds()
    const newly: BadgeDef[] = []
    const push = (id: string): void => {
      if (unlocked.indexOf(id) < 0) {
        unlocked.push(id)
        const def: BadgeDef | undefined = AchievementEngine.getById(id)
        if (def !== undefined) {
          newly.push(def)
        }
      }
    }

    const km: number = record.distanceM / 1000
    const hour: number = new Date(record.startTs).getHours()

    push('first_run')
    if (record.type === SportType.RUN && km >= 3 && hour >= 20) {
      push('night_runner')
    }
    if (record.type === SportType.RUN && env.aqi <= 50) {
      push('eco_runner')
    }
    if (statsAfterTotalKm >= 10) {
      push('km_10')
    }
    if (statsAfterTotalKm >= 50) {
      push('km_50')
    }
    if (statsAfterTotalKm >= 100) {
      push('km_100')
    }
    if (streakDays >= 3) {
      push('streak_3')
    }
    if (streakDays >= 7) {
      push('streak_7')
    }

    if (newly.length > 0) {
      store.saveUnlockedBadgeIds(unlocked)
    }
    return newly
  }

  /** 加入挑战时触发 */
  static evaluateOnJoinChallenge(): BadgeDef[] {
    const store: StoreService = StoreService.getInstance()
    const unlocked: string[] = store.getUnlockedBadgeIds()
    if (unlocked.indexOf('challenge_join') >= 0) {
      return []
    }
    unlocked.push('challenge_join')
    store.saveUnlockedBadgeIds(unlocked)
    const def: BadgeDef | undefined = AchievementEngine.getById('challenge_join')
    if (def !== undefined) {
      return [def]
    }
    return []
  }

  static isUnlocked(id: string): boolean {
    return StoreService.getInstance().getUnlockedBadgeIds().indexOf(id) >= 0
  }
}
