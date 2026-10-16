/**
 * 脉动光谷 - 健身房训练服务（M6 健身模块）
 * 器械动作库 + 组记录（动作×组数×次数×重量）+ 组间休息计时
 * 训练计划由 AI 能力层（AiCoach.generateTrainingPlan）按需求生成后经 applyPlan 注入
 * 训练结束生成 GymWorkout 持久化，并统计训练容量与卡路里
 */
import { GymMove, GymSetLog, GymWorkout } from '../common/Types'
import { StoreService } from './StoreService'

/** 组间休息时长（秒） */
export const REST_SECONDS: number = 60

export class GymService {
  private static moves: GymMove[] = GymService.buildMoves()

  /** 器械动作库（生产由健身房 POI 云端下发） */
  private static buildMoves(): GymMove[] {
    return [
      GymMove.of('g_bench', '杠铃卧推', '🏋️', '胸大肌', 4, 12, 30),
      GymMove.of('g_squat', '杠铃深蹲', '🦵', '股四头肌', 4, 12, 35),
      GymMove.of('g_deadlift', '硬拉', '💪', '下背/臀腿', 4, 10, 40),
      GymMove.of('g_pullup', '引体向上', '🧗', '背阔肌', 4, 8, 0),
      GymMove.of('g_curl', '哑铃弯举', '💪', '肱二头肌', 3, 14, 10),
      GymMove.of('g_row', '划船机', '🚣', '全身有氧', 3, 20, 0),
      GymMove.of('g_treadmill', '跑步机', '🏃', '心肺有氧', 1, 15, 0),
      GymMove.of('g_crunch', '卷腹', '🧘', '腹直肌', 4, 20, 0)
    ]
  }

  static getMoves(): GymMove[] {
    return GymService.moves
  }

  static getMoveById(id: string): GymMove | undefined {
    for (let i = 0; i < GymService.moves.length; i++) {
      if (GymService.moves[i].id === id) {
        return GymService.moves[i]
      }
    }
    return undefined
  }

  /** ---------- 训练计划（由 AI 能力层生成后注入） ---------- */

  private static activePlan: GymMove[] = []
  private static activePlanTitle: string = ''

  /** 应用 AI 生成的训练计划（GymPage 生成后调用） */
  static applyPlan(moves: GymMove[], title: string): void {
    GymService.activePlan = moves
    GymService.activePlanTitle = title
    if (!GymService.active && moves.length > 0) {
      GymService.currentMoveId = moves[0].id
    }
  }

  /** 当前生效的训练计划动作 */
  static getActivePlan(): GymMove[] {
    return GymService.activePlan
  }

  /** 当前生效的训练计划标题 */
  static getPlanTitle(): string {
    return GymService.activePlanTitle
  }

  /** ---------- 训练会话 ---------- */

  private static active: boolean = false
  private static startTs: number = 0
  private static currentMoveId: string = ''
  private static setLogs: GymSetLog[] = []

  static isActive(): boolean {
    return GymService.active
  }

  static startWorkout(): void {
    GymService.active = true
    GymService.startTs = Date.now()
    GymService.setLogs = []
    // 首个动作取 AI 生成计划的第一项；无计划时回退动作库首项
    if (GymService.activePlan.length > 0) {
      GymService.currentMoveId = GymService.activePlan[0].id
    } else if (GymService.moves.length > 0) {
      GymService.currentMoveId = GymService.moves[0].id
    }
  }

  static getCurrentMoveId(): string {
    return GymService.currentMoveId
  }

  static selectMove(moveId: string): void {
    GymService.currentMoveId = moveId
  }

  static getSetLogs(): GymSetLog[] {
    return GymService.setLogs
  }

  /** 当前动作已完成组数 */
  static doneSetsOf(moveId: string): number {
    let count: number = 0
    for (let i = 0; i < GymService.setLogs.length; i++) {
      if (GymService.setLogs[i].moveName === GymService.moveNameOf(moveId)) {
        count += 1
      }
    }
    return count
  }

  private static moveNameOf(moveId: string): string {
    const m: GymMove | undefined = GymService.getMoveById(moveId)
    return m !== undefined ? m.name : ''
  }

  /** 完成一组：记录并返回该组日志 */
  static logSet(moveId: string, reps: number, weightKg: number): GymSetLog {
    const m: GymMove | undefined = GymService.getMoveById(moveId)
    const name: string = m !== undefined ? m.name : '自由训练'
    const emoji: string = m !== undefined ? m.emoji : '🏋️'
    const log: GymSetLog = GymSetLog.of(name, emoji, GymService.doneSetsOf(moveId) + 1,
      reps, weightKg, Date.now())
    GymService.setLogs.push(log)
    return log
  }

  /** 结束训练：生成训练记录持久化（卡路里 = 组数 × 系数 + 容量换算） */
  static finishWorkout(): GymWorkout | undefined {
    if (!GymService.active || GymService.setLogs.length === 0) {
      GymService.active = false
      return undefined
    }
    let volume: number = 0
    for (let i = 0; i < GymService.setLogs.length; i++) {
      volume += GymService.setLogs[i].reps * GymService.setLogs[i].weightKg
    }
    const minutes: number = Math.max(15, Math.round((Date.now() - GymService.startTs) / 60000))
    const calories: number = Math.round(GymService.setLogs.length * 18 + volume * 0.06)
    const workout: GymWorkout = GymWorkout.of(
      `g_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      GymService.startTs, Date.now(), GymService.setLogs, calories, Math.round(volume))
    StoreService.getInstance().saveGymWorkout(workout)
    GymService.active = false
    GymService.setLogs = []
    return workout
  }

  /** 历史训练 */
  static history(): GymWorkout[] {
    return StoreService.getInstance().getGymWorkouts()
  }

  /** 累计健身统计 */
  static totalStats(): GymTotalStats {
    const list: GymWorkout[] = StoreService.getInstance().getGymWorkouts()
    const total: GymTotalStats = new GymTotalStats()
    for (let i = 0; i < list.length; i++) {
      total.times += 1
      total.sets += list[i].totalSets
      total.volumeKg += list[i].volumeKg
      total.calories += list[i].calories
    }
    return total
  }
}

/** 健身累计统计 */
export class GymTotalStats {
  times: number = 0
  sets: number = 0
  volumeKg: number = 0
  calories: number = 0
}
