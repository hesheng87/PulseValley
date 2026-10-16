/**
 * 脉动光谷 - 本地数据持久化服务（Local-First）
 * 基于 Preferences：运动记录 / 挑战 / 勋章 / 用户统计
 * 对应《架构设计文档》4.1 端侧数据层
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import {
  AiWeekPlan, AiWeekPlanDay, CampusInfo, Challenge, ChallengeMember, GymMove,
  GymSetLog, GymWorkout, HealthSyncState, SportRecord, UserStats, SyncState
} from '../common/Types'
import { POINTS_PER_KM, POINTS_PER_RUN, LEVEL_DIVISOR } from '../common/Constants'
import { FormatUtils } from '../common/FormatUtils'

const STORE_NAME: string = 'maidong_store'
const KEY_RECORDS: string = 'sport_records'
const KEY_CHALLENGES: string = 'challenges'
const KEY_BADGES: string = 'badges'
const KEY_STATS: string = 'user_stats'
const KEY_LAST_SYNC_TS: string = 'last_sync_ts'
const KEY_COMMUNITY_STATE: string = 'community_state'
const KEY_GYM_WORKOUTS: string = 'gym_workouts'
const KEY_HEALTH_SYNC: string = 'health_sync_state'
const KEY_CAMPUS: string = 'campus_info'
const KEY_AI_WEEK_PLAN: string = 'ai_week_plan'

export class StoreService {
  private static instance: StoreService | undefined = undefined
  private store: preferences.Preferences | undefined = undefined
  private onRecordSaved: (() => void) | undefined = undefined

  static getInstance(): StoreService {
    if (StoreService.instance === undefined) {
      StoreService.instance = new StoreService()
    }
    return StoreService.instance
  }

  init(context: common.UIAbilityContext): void {
    if (this.store === undefined) {
      try {
        this.store = preferences.getPreferencesSync(context, { name: STORE_NAME })
      } catch (e) {
        console.error('[Store] init preferences failed')
      }
    }
  }

  /** 是否已完成初始化（页面 onPageShow 时避免早于 aboutToAppear 的空访问） */
  isInited(): boolean {
    return this.store !== undefined
  }

  /** 注册“运动记录已保存”回调（UserService 用于把记录发布到账号同步） */
  setOnRecordSaved(listener: () => void): void {
    this.onRecordSaved = listener
  }

  private ensureStore(): preferences.Preferences {
    if (this.store === undefined) {
      throw new Error('StoreService not initialized')
    }
    return this.store
  }

  private getStr(key: string, def: string): string {
    try {
      return this.ensureStore().getSync(key, def) as string
    } catch (e) {
      return def
    }
  }

  private putVal(key: string, value: preferences.ValueType): void {
    try {
      this.ensureStore().putSync(key, value)
    } catch (e) {
    }
  }

  private flushStore(): void {
    try {
      this.ensureStore().flush()
    } catch (e) {
    }
  }

  /** ---------- 运动记录 ---------- */

  getRecords(): SportRecord[] {
    const raw: string = this.getStr(KEY_RECORDS, '[]')
    return this.parseRecords(raw)
  }

  /** 解析运动记录对象列表（跨设备同步合并用） */
  parseRecordObjects(arr: object[]): SportRecord[] {
    const list: SportRecord[] = []
    for (let i = 0; i < arr.length; i++) {
      const o: Record<string, Object> = arr[i] as Record<string, Object>
      const r: SportRecord = new SportRecord()
      r.id = (o['id'] ?? '') as string
      r.type = (o['type'] ?? 0) as number
      r.startTs = (o['startTs'] ?? 0) as number
      r.endTs = (o['endTs'] ?? 0) as number
      r.distanceM = (o['distanceM'] ?? 0) as number
      r.durationS = (o['durationS'] ?? 0) as number
      r.steps = (o['steps'] ?? 0) as number
      r.calorie = (o['calorie'] ?? 0) as number
      r.paceSecPerKm = (o['paceSecPerKm'] ?? 0) as number
      r.pointCount = (o['pointCount'] ?? 0) as number
      list.push(r)
    }
    return list
  }

  private parseRecords(raw: string): SportRecord[] {
    try {
      const arr: object[] = JSON.parse(raw) as object[]
      return this.parseRecordObjects(arr)
    } catch (e) {
      return []
    }
  }

  /** 保存运动记录并更新用户统计，返回更新后的统计 */
  saveRecord(record: SportRecord): UserStats {
    const list: SportRecord[] = this.getRecords()
    list.unshift(record)
    if (list.length > 200) {
      list.splice(200, list.length - 200)
    }
    this.putVal(KEY_RECORDS, JSON.stringify(list))
    const stats: UserStats = this.updateStatsOnFinish(record)
    this.markSynced(record.id)
    this.flushStore()
    if (this.onRecordSaved !== undefined) {
      this.onRecordSaved()
    }
    return stats
  }

  /**
   * 合并其他设备同步来的运动记录（按 id 去重，新记录合入后重算统计）
   * 返回 true 表示本地数据有更新
   */
  mergeRecords(remote: SportRecord[]): boolean {
    if (remote.length === 0) {
      return false
    }
    const list: SportRecord[] = this.getRecords()
    const localIds: Set<string> = new Set<string>()
    for (let i = 0; i < list.length; i++) {
      localIds.add(list[i].id)
    }
    let added: number = 0
    for (let i = 0; i < remote.length; i++) {
      if (!localIds.has(remote[i].id)) {
        list.push(remote[i])
        added += 1
      }
    }
    if (added === 0) {
      return false
    }
    list.sort((a: SportRecord, b: SportRecord): number => b.startTs - a.startTs)
    if (list.length > 200) {
      list.splice(200, list.length - 200)
    }
    this.putVal(KEY_RECORDS, JSON.stringify(list))
    this.recomputeStats(list)
    this.flushStore()
    return true
  }

  /** 根据记录列表重算用户统计（合并远端记录后保持统计一致） */
  private recomputeStats(list: SportRecord[]): void {
    const stats: UserStats = new UserStats()
    const sorted: SportRecord[] = list.slice().sort((a: SportRecord, b: SportRecord): number => a.startTs - b.startTs)
    const dateSet: Set<string> = new Set<string>()
    for (let i = 0; i < sorted.length; i++) {
      const r: SportRecord = sorted[i]
      stats.totalKm = Math.round((stats.totalKm + r.distanceM / 1000) * 100) / 100
      stats.totalTimes += 1
      stats.totalMinutes += Math.floor(r.durationS / 60)
      const km: number = r.distanceM / 1000
      stats.totalPoints += Math.floor(km * POINTS_PER_KM) + POINTS_PER_RUN
      dateSet.add(FormatUtils.dateKeyOf(r.startTs))
    }
    stats.level = Math.floor(Math.sqrt(stats.totalPoints / LEVEL_DIVISOR)) + 1
    const dates: string[] = []
    dateSet.forEach((d: string): void => {
      dates.push(d)
    })
    dates.sort()
    if (dates.length > 0) {
      stats.lastSportDate = dates[dates.length - 1]
      let streak: number = 1
      for (let i = dates.length - 1; i > 0; i--) {
        const cur: number = new Date(dates[i].replace(/-/g, '/')).getTime()
        const prev: number = new Date(dates[i - 1].replace(/-/g, '/')).getTime()
        if (cur - prev === 24 * 3600 * 1000) {
          streak += 1
        } else {
          break
        }
      }
      stats.streakDays = streak
    }
    this.putVal(KEY_STATS, JSON.stringify(stats))
  }

  private markSynced(recordId: string): void {
    // Local-First：记录已落盘即视为可同步，此处置为 SYNCED（云端上报由 Outbox 场景扩展）
    const list: SportRecord[] = this.getRecords()
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === recordId) {
        list[i].syncState = SyncState.SYNCED
        break
      }
    }
    this.putVal(KEY_RECORDS, JSON.stringify(list))
    this.putVal(KEY_LAST_SYNC_TS, Date.now())
  }

  private updateStatsOnFinish(record: SportRecord): UserStats {
    const stats: UserStats = this.getUserStats()
    stats.totalKm = Math.round((stats.totalKm + record.distanceM / 1000) * 100) / 100
    stats.totalTimes += 1
    stats.totalMinutes += Math.floor(record.durationS / 60)
    const km: number = record.distanceM / 1000
    stats.totalPoints += Math.floor(km * POINTS_PER_KM) + POINTS_PER_RUN
    stats.level = Math.floor(Math.sqrt(stats.totalPoints / LEVEL_DIVISOR)) + 1
    const todayKey: string = FormatUtils.dateKeyOf(record.startTs)
    if (stats.lastSportDate !== todayKey) {
      const yesterday: string = FormatUtils.dateKeyOf(record.startTs - 24 * 3600 * 1000)
      stats.streakDays = stats.lastSportDate === yesterday ? stats.streakDays + 1 : 1
      stats.lastSportDate = todayKey
    }
    this.putVal(KEY_STATS, JSON.stringify(stats))
    return stats
  }

  /** ---------- 用户统计 ---------- */

  getUserStats(): UserStats {
    const raw: string = this.getStr(KEY_STATS, '')
    if (raw === '') {
      return new UserStats()
    }
    try {
      const o: Record<string, Object> = JSON.parse(raw) as Record<string, Object>
      const s: UserStats = new UserStats()
      s.totalKm = (o['totalKm'] ?? 0) as number
      s.totalTimes = (o['totalTimes'] ?? 0) as number
      s.totalMinutes = (o['totalMinutes'] ?? 0) as number
      s.totalPoints = (o['totalPoints'] ?? 0) as number
      s.level = (o['level'] ?? 1) as number
      s.streakDays = (o['streakDays'] ?? 0) as number
      s.lastSportDate = (o['lastSportDate'] ?? '') as string
      return s
    } catch (e) {
      return new UserStats()
    }
  }

  /** ---------- 勋章解锁 ---------- */

  getUnlockedBadgeIds(): string[] {
    const raw: string = this.getStr(KEY_BADGES, '[]')
    try {
      return JSON.parse(raw) as string[]
    } catch (e) {
      return []
    }
  }

  saveUnlockedBadgeIds(ids: string[]): void {
    this.putVal(KEY_BADGES, JSON.stringify(ids))
  }

  /** ---------- 挑战 ---------- */

  getChallenges(): Challenge[] {
    const raw: string = this.getStr(KEY_CHALLENGES, '')
    if (raw === '') {
      return []
    }
    try {
      return this.parseChallenges(raw)
    } catch (e) {
      return []
    }
  }

  saveChallenges(list: Challenge[]): void {
    this.putVal(KEY_CHALLENGES, JSON.stringify(list))
  }

  private parseChallenges(raw: string): Challenge[] {
    const arr: object[] = JSON.parse(raw) as object[]
    const list: Challenge[] = []
    for (let i = 0; i < arr.length; i++) {
      const o: Record<string, Object> = arr[i] as Record<string, Object>
      const c: Challenge = new Challenge()
      c.id = (o['id'] ?? '') as string
      c.title = (o['title'] ?? '') as string
      c.emoji = (o['emoji'] ?? '🔥') as string
      c.typeDesc = (o['typeDesc'] ?? '') as string
      c.targetKm = (o['targetKm'] ?? 0) as number
      c.endDate = (o['endDate'] ?? '') as string
      c.joined = (o['joined'] ?? false) as boolean
      const membersRaw: object[] = (o['members'] ?? []) as object[]
      const members: ChallengeMember[] = []
      for (let j = 0; j < membersRaw.length; j++) {
        const m: Record<string, Object> = membersRaw[j] as Record<string, Object>
        const cm = ChallengeMember.of((m['name'] ?? '') as string, (m['avatar'] ?? '🏃') as string,
          (m['progressKm'] ?? 0) as number, (m['isMe'] ?? false) as boolean)
        members.push(cm)
      }
      c.members = members
      list.push(c)
    }
    return list
  }

  /** ---------- 社区 ---------- */

  getCommunityState(): string {
    return this.getStr(KEY_COMMUNITY_STATE, '')
  }

  saveCommunityState(raw: string): void {
    this.putVal(KEY_COMMUNITY_STATE, raw)
    this.flushStore()
  }

  /** ---------- 健身房训练 ---------- */

  getGymWorkouts(): GymWorkout[] {
    const raw: string = this.getStr(KEY_GYM_WORKOUTS, '[]')
    try {
      const arr: object[] = JSON.parse(raw) as object[]
      const list: GymWorkout[] = []
      for (let i = 0; i < arr.length; i++) {
        const o: Record<string, Object> = arr[i] as Record<string, Object>
        const w: GymWorkout = new GymWorkout()
        w.id = (o['id'] ?? '') as string
        w.startTs = (o['startTs'] ?? 0) as number
        w.endTs = (o['endTs'] ?? 0) as number
        w.totalSets = (o['totalSets'] ?? 0) as number
        w.calories = (o['calories'] ?? 0) as number
        w.volumeKg = (o['volumeKg'] ?? 0) as number
        const logsRaw: object[] = (o['setLogs'] ?? []) as object[]
        for (let j = 0; j < logsRaw.length; j++) {
          const l: Record<string, Object> = logsRaw[j] as Record<string, Object>
          w.setLogs.push(GymSetLog.of((l['moveName'] ?? '') as string, (l['moveEmoji'] ?? '🏋️') as string,
            (l['setIndex'] ?? 0) as number, (l['reps'] ?? 0) as number,
            (l['weightKg'] ?? 0) as number, (l['ts'] ?? 0) as number))
        }
        list.push(w)
      }
      return list
    } catch (e) {
      return []
    }
  }

  saveGymWorkout(workout: GymWorkout): void {
    const list: GymWorkout[] = this.getGymWorkouts()
    list.unshift(workout)
    if (list.length > 50) {
      list.splice(50, list.length - 50)
    }
    this.putVal(KEY_GYM_WORKOUTS, JSON.stringify(list))
  }

  /** ---------- 华为运动健康同步 ---------- */

  getHealthSyncState(): HealthSyncState {
    const raw: string = this.getStr(KEY_HEALTH_SYNC, '')
    if (raw === '') {
      return new HealthSyncState()
    }
    try {
      const o: Record<string, Object> = JSON.parse(raw) as Record<string, Object>
      const s: HealthSyncState = new HealthSyncState()
      s.lastSyncTs = (o['lastSyncTs'] ?? 0) as number
      s.lastSyncSteps = (o['lastSyncSteps'] ?? 0) as number
      s.lastSyncSleepH = (o['lastSyncSleepH'] ?? 0) as number
      s.lastSyncRestingHr = (o['lastSyncRestingHr'] ?? 0) as number
      s.lastSyncCalories = (o['lastSyncCalories'] ?? 0) as number
      s.autoSync = (o['autoSync'] ?? true) as boolean
      s.totalSyncCount = (o['totalSyncCount'] ?? 0) as number
      return s
    } catch (e) {
      return new HealthSyncState()
    }
  }

  saveHealthSyncState(state: HealthSyncState): void {
    this.putVal(KEY_HEALTH_SYNC, JSON.stringify(state))
  }

  /** ---------- AI 本周训练计划 ---------- */

  getAiWeekPlan(): AiWeekPlan | undefined {
    const raw: string = this.getStr(KEY_AI_WEEK_PLAN, '')
    if (raw === '') {
      return undefined
    }
    try {
      const o: Record<string, Object> = JSON.parse(raw) as Record<string, Object>
      const plan: AiWeekPlan = new AiWeekPlan()
      plan.requirement = (o['requirement'] ?? '') as string
      plan.goalWord = (o['goalWord'] ?? '') as string
      plan.generatedAt = (o['generatedAt'] ?? 0) as number
      const daysRaw: object[] = (o['days'] ?? []) as object[]
      for (let i = 0; i < daysRaw.length; i++) {
        const d: Record<string, Object> = daysRaw[i] as Record<string, Object>
        const day: AiWeekPlanDay = new AiWeekPlanDay()
        day.label = (d['label'] ?? '') as string
        day.dateKey = (d['dateKey'] ?? '') as string
        day.focus = (d['focus'] ?? '') as string
        day.rest = (d['rest'] ?? false) as boolean
        const movesRaw: object[] = (d['moves'] ?? []) as object[]
        for (let j = 0; j < movesRaw.length; j++) {
          const m: Record<string, Object> = movesRaw[j] as Record<string, Object>
          day.moves.push(GymMove.of((m['id'] ?? '') as string, (m['name'] ?? '') as string,
            (m['emoji'] ?? '🏋️') as string, (m['muscle'] ?? '') as string,
            (m['suggestSets'] ?? 3) as number, (m['suggestReps'] ?? 12) as number,
            (m['suggestWeightKg'] ?? 0) as number))
        }
        plan.days.push(day)
      }
      return plan
    } catch (e) {
      return undefined
    }
  }

  saveAiWeekPlan(plan: AiWeekPlan): void {
    this.putVal(KEY_AI_WEEK_PLAN, JSON.stringify(plan))
    this.flushStore()
  }

  /** ---------- 校园绑定 ---------- */

  getCampusInfo(): CampusInfo {
    const raw: string = this.getStr(KEY_CAMPUS, '')
    if (raw === '') {
      return new CampusInfo()
    }
    try {
      const o: Record<string, Object> = JSON.parse(raw) as Record<string, Object>
      const c: CampusInfo = new CampusInfo()
      c.school = (o['school'] ?? '') as string
      c.studentId = (o['studentId'] ?? '') as string
      c.studentName = (o['studentName'] ?? '') as string
      c.verified = (o['verified'] ?? false) as boolean
      c.boundTs = (o['boundTs'] ?? 0) as number
      return c
    } catch (e) {
      return new CampusInfo()
    }
  }

  saveCampusInfo(info: CampusInfo): void {
    this.putVal(KEY_CAMPUS, JSON.stringify(info))
  }

  flush(): void {
    this.flushStore()
  }
}
