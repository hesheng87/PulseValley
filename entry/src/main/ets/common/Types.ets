/**
 * 脉动光谷 - 全局类型定义
 * 对应《详细设计文档》2.1 基础类型与枚举
 */

export enum SportType {
  RUN = 0,
  RIDE = 1,
  WALK = 2
}

export enum SessionStatus {
  IDLE = 0,
  PREPARING = 1,
  RECORDING = 2,
  PAUSED = 3,
  FINISHED = 4
}

export enum SyncState {
  LOCAL_ONLY = 0,
  SYNCED = 1
}

/** 单个轨迹点（仅内存使用，不入库） */
export interface SportPoint {
  ts: number
  lng: number
  lat: number
  accuracy: number
  speed: number
}

/** 一次完整运动记录 */
export class SportRecord {
  id: string = ''
  type: SportType = SportType.RUN
  startTs: number = 0
  endTs: number = 0
  distanceM: number = 0
  durationS: number = 0
  steps: number = 0
  avgHr: number = 0
  calorie: number = 0
  paceSecPerKm: number = 0
  pointCount: number = 0
  syncState: SyncState = SyncState.LOCAL_ONLY

  static of(id: string, type: SportType, startTs: number, endTs: number,
    distanceM: number, durationS: number, steps: number, calorie: number,
    paceSecPerKm: number, pointCount: number): SportRecord {
    const r: SportRecord = new SportRecord()
    r.id = id
    r.type = type
    r.startTs = startTs
    r.endTs = endTs
    r.distanceM = distanceM
    r.durationS = durationS
    r.steps = steps
    r.calorie = calorie
    r.paceSecPerKm = paceSecPerKm
    r.pointCount = pointCount
    return r
  }

  /** 结果页展示用：GPS 轨迹点描述 */
  gpsPointText(): string {
    if (this.pointCount > 0) {
      return `GPS 轨迹 ${this.pointCount} 个采集点 · 数据已本地保存`
    }
    return '本次以步数估算里程（无 GPS 信号）· 数据已本地保存'
  }
}

/** 环境快照（AQI/气象），对应概设 M2.1 */
export class EnvSnapshot {
  aqi: number = 50
  pm25: number = 20
  temp: number = 24
  humidity: number = 55
  uv: number = 3
  wind: number = 3
  source: string = 'campus-gateway'
  updatedAt: number = 0
  isStale: boolean = false
}

/** 校园路线库条目，对应概设 M2.3 */
export class CampusRoute {
  id: string = ''
  name: string = ''
  desc: string = ''
  baseKm: number = 0
  greenRate: number = 0
  awayTraffic: number = 0
  popularity: number = 0
  points: string = ''
}

/** 路线推荐结果 */
export class RouteRecommend {
  route: CampusRoute = new CampusRoute()
  score: number = 0
  reason: string = ''
  slot: string = ''
}

/** 环境安全判定结果 */
export enum EnvGuardResult {
  OK = 0,
  WARN = 1,
  BLOCK = 2
}

/** 挑战成员 */
export class ChallengeMember {
  name: string = ''
  avatar: string = '🏃'
  progressKm: number = 0
  isMe: boolean = false

  static of(name: string, avatar: string, progressKm: number, isMe: boolean): ChallengeMember {
    const m: ChallengeMember = new ChallengeMember()
    m.name = name
    m.avatar = avatar
    m.progressKm = progressKm
    m.isMe = isMe
    return m
  }
}

/** 组队挑战，对应概设 M3.1 */
export class Challenge {
  id: string = ''
  title: string = ''
  emoji: string = '🔥'
  typeDesc: string = '累计里程赛'
  targetKm: number = 0
  endDate: string = ''
  members: ChallengeMember[] = []
  joined: boolean = false

  static of(id: string, title: string, emoji: string, typeDesc: string,
    targetKm: number, endDate: string, members: ChallengeMember[], joined: boolean): Challenge {
    const c: Challenge = new Challenge()
    c.id = id
    c.title = title
    c.emoji = emoji
    c.typeDesc = typeDesc
    c.targetKm = targetKm
    c.endDate = endDate
    c.members = members
    c.joined = joined
    return c
  }
}

/** 勋章定义，对应详设 M4.1 规则 DSL 的端侧等价物 */
export class BadgeDef {
  id: string = ''
  name: string = ''
  emoji: string = ''
  desc: string = ''

  static of(id: string, name: string, emoji: string, desc: string): BadgeDef {
    const b: BadgeDef = new BadgeDef()
    b.id = id
    b.name = name
    b.emoji = emoji
    b.desc = desc
    return b
  }
}

/** 用户累计统计与等级，对应详设 6.3 */
export class UserStats {
  totalKm: number = 0
  totalTimes: number = 0
  totalMinutes: number = 0
  totalPoints: number = 0
  level: number = 1
  streakDays: number = 0
  lastSportDate: string = ''
}

/** 校园社区用户（跑友），对应概设 M5 社交 */
export class CommunityUser {
  id: string = ''
  name: string = ''
  avatar: string = '🏃'
  bio: string = ''
  level: number = 1
  weeklyKm: number = 0
  isFriend: boolean = false
  isMe: boolean = false

  static of(id: string, name: string, avatar: string, bio: string,
    level: number, weeklyKm: number, isMe: boolean): CommunityUser {
    const u: CommunityUser = new CommunityUser()
    u.id = id
    u.name = name
    u.avatar = avatar
    u.bio = bio
    u.level = level
    u.weeklyKm = weeklyKm
    u.isMe = isMe
    return u
  }
}

/** 社区动态：一条可点赞/转发的运动记录分享 */
export class CommunityPost {
  id: string = ''
  authorId: string = ''
  authorName: string = ''
  authorAvatar: string = '🏃'
  isMe: boolean = false
  content: string = ''
  sportType: SportType = SportType.RUN
  distanceM: number = 0
  durationS: number = 0
  paceSecPerKm: number = 0
  calorie: number = 0
  startTs: number = 0
  baseLikes: number = 0
  baseForwards: number = 0
  likes: number = 0
  forwards: number = 0
  likedByMe: boolean = false
  forwardedByMe: boolean = false
  fromMyRecord: boolean = false
  repostOf: string = ''
  /** 动态类型：record=运动记录分享 / moment=微博式发布的图文动态 */
  kind: string = 'record'
  /** 图文动态附带的图片 URI 列表 */
  images: string[] = []

  static of(id: string, author: CommunityUser, content: string, record: SportRecord): CommunityPost {
    const p: CommunityPost = new CommunityPost()
    p.id = id
    p.authorId = author.id
    p.authorName = author.name
    p.authorAvatar = author.avatar
    p.isMe = author.isMe
    p.content = content
    p.sportType = record.type
    p.distanceM = record.distanceM
    p.durationS = record.durationS
    p.paceSecPerKm = record.paceSecPerKm
    p.calorie = record.calorie
    p.startTs = record.startTs
    return p
  }
}

/** 分布式数据对象源（软总线跨设备同步），对应详设 10.2 DDO Schema */
export class SportSyncSource {
  sessionId: string = ''
  status: number = SessionStatus.IDLE
  distanceM: number = 0
  paceSecPerKm: number = 0
  steps: number = 0
  heartRate: number = 0
  cadence: number = 0
  lapKm: number = 0
  lastBeatTs: number = 0
}

/** AI 赛后分析报告（大模型端侧推理演示版） */
export class AiSportReport {
  title: string = ''
  summary: string = ''
  recoveryTips: string[] = []
  nextGoal: string = ''
  score: number = 0
  shareCopy: string = ''
  aiSummaryForPost: string = ''
}

/** AI 智能组队匹配结果 */
export class AiMateMatch {
  user: CommunityUser = new CommunityUser()
  matchScore: number = 0
  reason: string = ''

  static of(user: CommunityUser, matchScore: number, reason: string): AiMateMatch {
    const m: AiMateMatch = new AiMateMatch()
    m.user = user
    m.matchScore = matchScore
    m.reason = reason
    return m
  }
}

/** AI 按需求生成的训练计划 */
export class AiPlanResult {
  /** 计划标题（如"增肌 · 胸臂强化"） */
  title: string = ''
  /** 计划动作（含 AI 调整后的组数/次数/建议重量） */
  moves: GymMove[] = []
  /** 训练提示（热身/组间休息/恢复建议） */
  tips: string[] = []
  /** AI 生成说明（如何理解并响应了用户需求） */
  note: string = ''
}

/** AI 计划对话消息（周计划定制对话） */
export class AiChatMessage {
  /** 发送方：'user' | 'ai' */
  role: string = 'ai'
  text: string = ''
  ts: number = 0

  static of(role: string, text: string, ts: number): AiChatMessage {
    const m: AiChatMessage = new AiChatMessage()
    m.role = role
    m.text = text
    m.ts = ts
    return m
  }
}

/** AI 对话回复（可携带生成的一周计划） */
export class AiChatReply {
  text: string = ''
  plan: AiWeekPlan | undefined = undefined
}

/** AI 周计划中的一天 */
export class AiWeekPlanDay {
  /** 星期标签：周一 ~ 周日 */
  label: string = ''
  /** 日期键（YYYY-MM-DD，用于完成打卡比对） */
  dateKey: string = ''
  /** 训练重点标题（休息日为"休息"） */
  focus: string = ''
  /** 是否休息日 */
  rest: boolean = false
  /** 当日动作（含调整后的组数/次数/重量） */
  moves: GymMove[] = []
}

/** AI 生成的一周训练计划 */
export class AiWeekPlan {
  /** 对话中的定制需求原文 */
  requirement: string = ''
  /** 目标：增肌 / 减脂 / 均衡 */
  goalWord: string = ''
  generatedAt: number = 0
  days: AiWeekPlanDay[] = []
}

/** 语音加油消息（挑战内实时互动） */
export class CheerMessage {
  from: string = ''
  avatar: string = '📣'
  text: string = ''
  ts: number = 0

  static of(from: string, avatar: string, text: string, ts: number): CheerMessage {
    const c: CheerMessage = new CheerMessage()
    c.from = from
    c.avatar = avatar
    c.text = text
    c.ts = ts
    return c
  }
}

/** 排行榜条目（好友榜 / 全校榜） */
export class LeaderEntry {
  name: string = ''
  avatar: string = '🏃'
  km: number = 0
  dept: string = ''
  isMe: boolean = false

  static of(name: string, avatar: string, km: number, dept: string, isMe: boolean): LeaderEntry {
    const e: LeaderEntry = new LeaderEntry()
    e.name = name
    e.avatar = avatar
    e.km = km
    e.dept = dept
    e.isMe = isMe
    return e
  }
}

/** 跨设备流转设备节点（分布式软总线组网设备） */
export class FlowDevice {
  id: string = ''
  name: string = ''
  emoji: string = '📱'
  role: string = ''
  online: boolean = false
  flowDesc: string = ''
  lastSyncText: string = ''

  static of(id: string, name: string, emoji: string, role: string,
    online: boolean, flowDesc: string, lastSyncText: string): FlowDevice {
    const d: FlowDevice = new FlowDevice()
    d.id = id
    d.name = name
    d.emoji = emoji
    d.role = role
    d.online = online
    d.flowDesc = flowDesc
    d.lastSyncText = lastSyncText
    return d
  }
}

/** 手表/平板端实时提醒事件（跨设备流转通知） */
export class DeviceAlertEvent {
  text: string = ''
  fromDevice: string = '⌚ 手表'
  ts: number = 0
  kind: string = 'pace'

  static of(text: string, fromDevice: string, ts: number, kind: string): DeviceAlertEvent {
    const e: DeviceAlertEvent = new DeviceAlertEvent()
    e.text = text
    e.fromDevice = fromDevice
    e.ts = ts
    e.kind = kind
    return e
  }
}

/** 分布式社交数据对象源（成就/排行榜跨设备同步） */
export class SocialSyncSource {
  deviceName: string = '我的手机'
  badgeCsv: string = ''
  totalKm: number = 0
  level: number = 1
  lastUpdateTs: number = 0
}

/** 手表实时健康快照（心率/血氧/压力/睡眠/卡路里） */
export class HealthSnapshot {
  heartRate: number = 0
  spo2: number = 0
  stress: number = 0
  sleepHours: number = 0
  calories: number = 0
  steps: number = 0
  restingHr: number = 0
  updatedTs: number = 0
}

/** 健身器械动作定义 */
export class GymMove {
  id: string = ''
  name: string = ''
  emoji: string = '🏋️'
  muscle: string = ''
  suggestSets: number = 4
  suggestReps: number = 12
  suggestWeightKg: number = 20

  static of(id: string, name: string, emoji: string, muscle: string,
    sets: number, reps: number, weightKg: number): GymMove {
    const m: GymMove = new GymMove()
    m.id = id
    m.name = name
    m.emoji = emoji
    m.muscle = muscle
    m.suggestSets = sets
    m.suggestReps = reps
    m.suggestWeightKg = weightKg
    return m
  }
}

/** 一组训练记录（动作 × 组序 × 次数 × 重量） */
export class GymSetLog {
  moveName: string = ''
  moveEmoji: string = '🏋️'
  setIndex: number = 0
  reps: number = 0
  weightKg: number = 0
  ts: number = 0

  static of(moveName: string, moveEmoji: string, setIndex: number,
    reps: number, weightKg: number, ts: number): GymSetLog {
    const l: GymSetLog = new GymSetLog()
    l.moveName = moveName
    l.moveEmoji = moveEmoji
    l.setIndex = setIndex
    l.reps = reps
    l.weightKg = weightKg
    l.ts = ts
    return l
  }
}

/** 一次完整健身房训练 */
export class GymWorkout {
  id: string = ''
  startTs: number = 0
  endTs: number = 0
  setLogs: GymSetLog[] = []
  totalSets: number = 0
  calories: number = 0
  volumeKg: number = 0

  static of(id: string, startTs: number, endTs: number, setLogs: GymSetLog[],
    calories: number, volumeKg: number): GymWorkout {
    const w: GymWorkout = new GymWorkout()
    w.id = id
    w.startTs = startTs
    w.endTs = endTs
    w.setLogs = setLogs
    w.totalSets = setLogs.length
    w.calories = calories
    w.volumeKg = volumeKg
    return w
  }
}

/** 校园绑定信息 */
export class CampusInfo {
  school: string = ''
  studentId: string = ''
  studentName: string = ''
  verified: boolean = false
  boundTs: number = 0
}

/** 校友（同校/跨校校友圈成员） */
export class AlumniUser {
  id: string = ''
  name: string = ''
  avatar: string = '🏃'
  school: string = ''
  dept: string = ''
  weeklyKm: number = 0
  isMe: boolean = false

  static of(id: string, name: string, avatar: string, school: string,
    dept: string, weeklyKm: number, isMe: boolean): AlumniUser {
    const a: AlumniUser = new AlumniUser()
    a.id = id
    a.name = name
    a.avatar = avatar
    a.school = school
    a.dept = dept
    a.weeklyKm = weeklyKm
    a.isMe = isMe
    return a
  }
}

/** 华为运动健康同步状态 */
export class HealthSyncState {
  lastSyncTs: number = 0
  lastSyncSteps: number = 0
  lastSyncSleepH: number = 0
  lastSyncRestingHr: number = 0
  lastSyncCalories: number = 0
  autoSync: boolean = true
  totalSyncCount: number = 0
}

/** 运动中实时面板状态（供 UI 观测的快照） */
export class LivePanelState {
  status: SessionStatus = SessionStatus.PREPARING
  /** 3-2-1 倒计时剩余秒数（PREPARING 阶段） */
  countdownNum: number = 3
  durationS: number = 0
  distanceM: number = 0
  paceSecPerKm: number = 0
  /** 本次运动出现的最佳配速（秒/公里，0=尚无有效配速） */
  bestPaceSecPerKm: number = 0
  steps: number = 0
  cadence: number = 0
  heartRate: number = 0
  gpsFixCount: number = 0
  gpsMode: boolean = true
  syncOnline: boolean = false
  deviceAlert: DeviceAlertEvent = new DeviceAlertEvent()
  latestCheer: CheerMessage = new CheerMessage()
  flowOnlineCount: number = 0
  lapKm: number = 0
}
