/**
 * 脉动光谷 - AI 大模型能力层（端侧推理演示版）
 * 能力一：智能路线推荐叙事（融合实时空气/天气/历史运动/身体状态生成个性化推荐语）
 * 能力二：赛后深度分析（专属恢复建议 + 下一步目标 + 个性化激励文案 + 分享文案）
 * 能力三：智能组队匹配（运动水平/时间偏好/目标三维匹配）
 * 能力四：AI 训练计划生成（把自然语言需求发给 AI，自动生成对应训练计划）
 * 生产版接入云端大模型（如盘古/端云协同推理），此处为端侧规则+模板等价实现
 */
import {
  AiChatMessage, AiChatReply, AiMateMatch, AiPlanResult, AiSportReport, AiWeekPlan,
  AiWeekPlanDay, CommunityUser, EnvSnapshot, GymMove, SportRecord, SportType, UserStats
} from '../common/Types'
import { FormatUtils } from '../common/FormatUtils'
import { EnvService } from './EnvService'
import { CommunityService } from './CommunityService'
import { GymService } from './GymService'

export class AiCoach {
  /** ---------- 能力一：智能路线推荐叙事 ---------- */

  /**
   * 大模型综合实时空气质量、天气、用户历史运动数据与当前身体状态，
   * 为打分引擎输出的最优路线生成个性化推荐叙事。
   */
  static narrateRoute(env: EnvSnapshot, historyKm: number, routeName: string): string {
    const aqiWord: string = env.aqi <= 50 ? '空气清透' : (env.aqi <= 100 ? '空气质量尚可' : '空气一般')
    const bodyWord: string = env.temp >= 24 ? '体感偏暖，注意补水' : (env.temp <= 14 ? '体感微凉，充分热身' : '体感舒适')
    const expWord: string = historyKm >= 50 ? '以你目前的跑量' : (historyKm >= 10 ? '结合你近期的运动积累' : '考虑到你刚开始建立运动习惯')
    const goalWord: string = historyKm >= 50 ? '可以尝试分段提速' : '建议保持匀速完成'
    return `AI 综合分析：当前${aqiWord}（AQI ${env.aqi}）、${env.temp}℃${bodyWord}，${expWord}，`
      + `推荐「${routeName}」，${goalWord}，尽情享受这段路线吧。`
  }

  /** ---------- 能力二：赛后深度分析 ---------- */

  /** 运动结束：大模型深度分析数据，生成专属恢复建议与下一步目标 */
  static analyzeFinish(record: SportRecord, stats: UserStats, env: EnvSnapshot): AiSportReport {
    const report: AiSportReport = new AiSportReport()
    const km: number = record.distanceM / 1000
    const avgPace: number = record.paceSecPerKm
    const minutes: number = Math.floor(record.durationS / 60)

    report.score = AiCoach.scoreOf(record, km)
    report.title = AiCoach.titleOf(km, record.type)
    report.summary = `本次${FormatUtils.sportNameOf(record.type)} ${FormatUtils.kmOf(record.distanceM)} 公里、`
      + `用时 ${FormatUtils.durationOf(record.durationS)}`
      + (avgPace > 0 ? `、平均配速 ${FormatUtils.paceOf(avgPace)}` : '')
      + `，消耗约 ${record.calorie} 千卡。`
      + (record.pointCount > 0 ? `轨迹由 ${record.pointCount} 个 GPS 采集点拟合。` : '本次以步数估算里程。')
      + `运动时 AQI ${env.aqi}（${EnvService.aqiLevelOf(env.aqi)}）。`

    report.recoveryTips = AiCoach.recoveryTipsOf(record, km, minutes)
    report.nextGoal = AiCoach.nextGoalOf(km, avgPace, stats)
    report.shareCopy = AiCoach.shareCopyOf(record, km)
    report.aiSummaryForPost = `AI 训练总结：${FormatUtils.kmOf(record.distanceM)}km 综合评分 ${report.score} 分，`
      + `处于${report.score >= 85 ? '极佳' : (report.score >= 70 ? '良好' : '稳定')}区间。`
      + `下一步目标——${report.nextGoal}`
    return report
  }

  private static scoreOf(record: SportRecord, km: number): number {
    let score: number = 62
    if (km >= 3) {
      score += 8
    }
    if (km >= 5) {
      score += 8
    }
    if (km >= 8) {
      score += 6
    }
    if (record.paceSecPerKm > 0 && record.paceSecPerKm <= 360) {
      score += 8
    } else if (record.paceSecPerKm > 0 && record.paceSecPerKm <= 420) {
      score += 5
    }
    if (record.pointCount > 20) {
      score += 4
    }
    return Math.min(score, 99)
  }

  private static titleOf(km: number, type: SportType): string {
    if (km >= 8) {
      return '🚀 长距离突破局'
    }
    if (km >= 5) {
      return '💪 高质量训练局'
    }
    if (km >= 3) {
      return '🏃 稳步提升局'
    }
    return type === SportType.WALK ? '🌿 轻松恢复局' : '🌱 热身启动局'
  }

  private static recoveryTipsOf(record: SportRecord, km: number, minutes: number): string[] {
    const tips: string[] = []
    tips.push(km >= 5 ? '训练量偏大：结束后 30 分钟内补充碳水和蛋白质，睡眠保证 7.5 小时以上'
      : '适量拉伸小腿与髂腰肌各 2 分钟，帮助肌肉放松')
    tips.push(minutes >= 30 ? '建议明天安排低强度交叉训练（游泳/骑行）主动恢复'
      : '明天可以安排一次稍长距离的慢跑巩固有氧基础')
    if (record.paceSecPerKm > 0 && record.paceSecPerKm < 300) {
      tips.push('配速偏快：注意观察晨起静息心率，若升高 8 次以上说明恢复不足')
    }
    tips.push('今天饮水目标 1.5 - 2L，晚间可用泡沫轴放松股四头肌')
    return tips
  }

  private static nextGoalOf(km: number, avgPace: number, stats: UserStats): string {
    if (km < 3) {
      return `下次尝试连续完成 3 公里（当前累计 ${stats.totalKm} km，循序渐进）`
    }
    if (avgPace > 420) {
      return '下次把平均配速压进 7\'00"，用呼吸节奏带动步频'
    }
    if (km < 5) {
      return '保持当前配速，下次挑战 5 公里不断速'
    }
    if (stats.streakDays < 3) {
      return `本周再完成 ${Math.max(3 - stats.streakDays, 1)} 次运动，解锁「三日不辍」勋章`
    }
    return '尝试法特莱克变速跑：快跑 1 分钟 + 慢跑 2 分钟 × 6 组'
  }

  /** 动态激励文案：AI 根据完成情况生成个性化鼓励语 */
  static motivate(record: SportRecord, stats: UserStats): string {
    const km: number = record.distanceM / 1000
    if (km >= 8) {
      return `${FormatUtils.kmOf(record.distanceM)} 公里长距离达成！你就是今晚光谷最靓的跑者，记得好好恢复 🌟`
    }
    if (km >= 3 && stats.streakDays >= 3) {
      return `连续打卡第 ${stats.streakDays} 天，习惯的力量正在你身上发生 ✨`
    }
    if (km >= 3) {
      return `3 公里关卡已拿下！大模型预测：保持这个节奏，两周内你将迎来质的飞跃 🚀`
    }
    return '万事开头难，今天迈出的每一步都算数，明天继续 💪'
  }

  /** 社交分享文案：AI 生成趣味分享语 */
  static shareCopyOf(record: SportRecord, km: number): string {
    const templates: string[] = [
      `刚刚用 ${FormatUtils.durationOf(record.durationS)} 跑完 ${FormatUtils.kmOf(record.distanceM)}km，`
        + `AI 教练说我的表现超过了校园 ${65 + Math.floor(Math.random() * 25)}% 的跑者，不服来战！`,
      `今晚在光谷刷了 ${FormatUtils.kmOf(record.distanceM)} 公里，配速 ${FormatUtils.paceOf(record.paceSecPerKm)}，`
        + `消耗 ${record.calorie} 千卡 ≈ ${Math.max(1, Math.round(record.calorie / 200))} 碗热干面 🍜 谁要接力？`,
      `第 ${Math.max(1, Math.floor(km))} 次把路线踩在脚下！AI 帮我生成了专属训练报告，`
        + `下一个目标已锁定，评论区抓个搭子一起跑 🏃`
    ]
    const idx: number = Math.floor(Math.random() * templates.length)
    return templates[Math.min(idx, templates.length - 1)]
  }

  /** ---------- 能力三：智能组队匹配 ---------- */

  /** 赛事大屏：下一次活动建议（平板端 AI 总结底部文案） */
  static nextGoalHint(): string {
    const hints: string[] = [
      '赛后 48 小时内安排低强度恢复跑，巩固有氧基础',
      '下期可发起「宿舍步数 PK」，扩大参与面',
      '根据本次配速分布，建议增加一次间歇训练',
      '天气窗口良好，推荐环湖 5 公里接力路线'
    ]
    const idx: number = Math.floor(Math.random() * hints.length)
    return hints[Math.min(idx, hints.length - 1)]
  }

  /**
   * 大模型智能匹配队友/对手：综合运动水平相近度、时间偏好重合度、目标一致性三维打分
   * myStats: 我的累计统计；hour: 当前时段（用于时间偏好匹配）
   */
  static matchTeammates(myStats: UserStats, hour: number): AiMateMatch[] {
    const candidates: CommunityUser[] = CommunityService.listRunners()
    const matches: AiMateMatch[] = []
    for (let i = 0; i < candidates.length; i++) {
      const u: CommunityUser = candidates[i]
      const levelGap: number = Math.abs(u.level - myStats.level)
      const kmGap: number = Math.abs(u.weeklyKm - myStats.totalKm % 30)
      let score: number = 88 - levelGap * 9 - Math.min(kmGap, 20)
      const slotWord: string = hour >= 6 && hour < 11 ? '清晨' : (hour >= 17 ? '傍晚' : '午后')
      if ((hour >= 17 && u.id === 'u_kaikai') || (hour >= 6 && hour < 11 && u.id === 'u_laozhou')) {
        score += 6
      }
      score = Math.max(58, Math.min(score, 98))
      const reason: string = `水平相近（Lv.${u.level}）· 常在${slotWord}出没 · 目标一致率 ${Math.round(score)}%`
      matches.push(AiMateMatch.of(u, Math.round(score), reason))
    }
    matches.sort((a: AiMateMatch, b: AiMateMatch): number => b.matchScore - a.matchScore)
    return matches.slice(0, 3)
  }

  /** ---------- 能力四：AI 训练计划生成（需求 → 计划） ---------- */

  /**
   * 把自然语言训练需求发给 AI，自动生成对应训练计划：
   * 解析目标（增肌/减脂）、部位（胸/腿/背/手臂/核心/有氧/全身）、
   * 时长（如"30分钟"）、器械（徒手/无器械）、水平（新手/进阶）五个维度，
   * 从器械动作库挑选动作并调整组数/次数/重量，输出计划与训练提示。
   * requirement 为空时生成全身均衡默认计划。
   */
  static generateTrainingPlan(requirement: string): AiPlanResult {
    const req: string = requirement.trim()
    const goalBuild: boolean = req.indexOf('增肌') >= 0 || req.indexOf('力量') >= 0
    const goalBurn: boolean = !goalBuild &&
      (req.indexOf('减脂') >= 0 || req.indexOf('减肥') >= 0 || req.indexOf('瘦身') >= 0 || req.indexOf('塑形') >= 0)
    const partChest: boolean = req.indexOf('胸') >= 0
    const partLeg: boolean = req.indexOf('腿') >= 0 || req.indexOf('臀') >= 0 || req.indexOf('下肢') >= 0
    const partBack: boolean = req.indexOf('背') >= 0
    const partArm: boolean = req.indexOf('手臂') >= 0 || req.indexOf('二头') >= 0 || req.indexOf('弯举') >= 0
    const partCore: boolean = req.indexOf('核心') >= 0 || req.indexOf('腹') >= 0 || req.indexOf('腰') >= 0
    const partCardio: boolean = req.indexOf('有氧') >= 0 || req.indexOf('心肺') >= 0 || req.indexOf('跑步机') >= 0
    const bodyweightOnly: boolean = req.indexOf('徒手') >= 0 || req.indexOf('无器械') >= 0 || req.indexOf('自重') >= 0
    const isBeginner: boolean = req.indexOf('新手') >= 0 || req.indexOf('入门') >= 0 || req.indexOf('初级') >= 0
    const isAdvanced: boolean = req.indexOf('进阶') >= 0 || req.indexOf('高强度') >= 0 || req.indexOf('挑战') >= 0
    const minutes: number = AiCoach.parseMinutes(req)

    // ---- 动作挑选：按部位 → 动作 id，未指定部位则全身均衡 ----
    const moveIds: string[] = AiCoach.pickMoveIds(
      partChest, partLeg, partBack, partArm, partCore, partCardio)

    // ---- 生成动作副本并按目标/水平调整参数 ----
    const moves: GymMove[] = []
    for (let i = 0; i < moveIds.length; i++) {
      const src: GymMove | undefined = GymService.getMoveById(moveIds[i])
      if (src === undefined) {
        continue
      }
      moves.push(AiCoach.tuneMove(src, goalBuild, goalBurn, bodyweightOnly, isBeginner, isAdvanced, minutes))
    }

    // ---- 时长约束：每组约 2 分钟（含休息），超预算则裁剪组数/动作 ----
    const budgetSets: number = minutes > 0 ? Math.max(4, Math.floor(minutes / 2)) : 0
    if (budgetSets > 0) {
      let used: number = 0
      for (let i = 0; i < moves.length; i++) {
        if (used + moves[i].suggestSets > budgetSets && used >= budgetSets * 0.7) {
          moves.splice(i)
          break
        }
        if (used + moves[i].suggestSets > budgetSets) {
          moves[i].suggestSets = Math.max(2, budgetSets - used)
        }
        used += moves[i].suggestSets
      }
    }

    const result: AiPlanResult = new AiPlanResult()
    result.title = AiCoach.planTitleOf(goalBuild, goalBurn,
      partChest, partLeg, partBack, partArm, partCore, partCardio)
    result.moves = moves
    result.note = AiCoach.planNoteOf(req, moves, goalBuild, goalBurn, minutes, bodyweightOnly, isBeginner)
    result.tips = AiCoach.planTipsOf(goalBuild, goalBurn, bodyweightOnly, isBeginner, moves)
    return result
  }

  /** 解析时长需求："30分钟 / 45 min / 半小时"，未提及返回 0 */
  private static parseMinutes(req: string): number {
    if (req.indexOf('半小时') >= 0) {
      return 30
    }
    const reg: RegExp = new RegExp('(\\d+)\\s*(分钟|min)', 'i')
    const m: RegExpMatchArray | null = req.match(reg)
    if (m !== null && m.length > 1) {
      const n: number = Number(m[1])
      if (n > 0 && n <= 180) {
        return n
      }
    }
    return 0
  }

  /** 部位 → 动作组合（未指定部位时全身均衡四动作） */
  private static pickMoveIds(partChest: boolean, partLeg: boolean, partBack: boolean,
    partArm: boolean, partCore: boolean, partCardio: boolean): string[] {
    if (partCardio) {
      return ['g_treadmill', 'g_row', 'g_crunch']
    }
    if (partChest) {
      return ['g_bench', 'g_curl', 'g_crunch']
    }
    if (partLeg) {
      return ['g_squat', 'g_deadlift', 'g_crunch']
    }
    if (partBack) {
      return ['g_pullup', 'g_row', 'g_crunch']
    }
    if (partArm) {
      return ['g_curl', 'g_bench', 'g_pullup']
    }
    if (partCore) {
      return ['g_crunch', 'g_row', 'g_squat']
    }
    return ['g_bench', 'g_squat', 'g_row', 'g_crunch']
  }

  /** 按目标/器械/水平调整动作参数（返回副本，不污染动作库） */
  private static tuneMove(src: GymMove, goalBuild: boolean, goalBurn: boolean,
    bodyweightOnly: boolean, isBeginner: boolean, isAdvanced: boolean,
    minutes: number): GymMove {
    let sets: number = src.suggestSets
    let reps: number = src.suggestReps
    let weight: number = src.suggestWeightKg
    if (goalBuild) {
      reps = Math.max(6, reps - 2)
      sets = Math.min(5, sets + 1)
      weight = Math.round(weight * 1.1)
    } else if (goalBurn) {
      reps = reps + 4
      sets = Math.max(3, sets - 1)
      weight = Math.round(weight * 0.6)
    }
    if (bodyweightOnly) {
      weight = 0
      reps = reps + 4
    }
    if (isBeginner) {
      weight = Math.round(weight * 0.6)
      sets = Math.max(2, sets - 1)
    }
    if (isAdvanced) {
      weight = weight + 5
      sets = Math.min(5, sets + 1)
    }
    if (minutes > 0 && minutes <= 20) {
      sets = Math.min(sets, 3)
    }
    return GymMove.of(src.id, src.name, src.emoji, src.muscle, sets, reps, weight)
  }

  private static planTitleOf(goalBuild: boolean, goalBurn: boolean, partChest: boolean,
    partLeg: boolean, partBack: boolean, partArm: boolean, partCore: boolean,
    partCardio: boolean): string {
    const goalWord: string = goalBuild ? '增肌' : (goalBurn ? '减脂' : '均衡')
    let partWord: string = '全身循环'
    if (partCardio) {
      partWord = '有氧燃动'
    } else if (partChest) {
      partWord = '胸臂推力'
    } else if (partLeg) {
      partWord = '腿臀力量'
    } else if (partBack) {
      partWord = '背部拉力'
    } else if (partArm) {
      partWord = '手臂雕刻'
    } else if (partCore) {
      partWord = '核心强化'
    }
    return `${goalWord} · ${partWord}`
  }

  /** AI 生成说明：把需求解析结果翻译成"AI 听懂了什么" */
  private static planNoteOf(req: string, moves: GymMove[], goalBuild: boolean, goalBurn: boolean,
    minutes: number, bodyweightOnly: boolean, isBeginner: boolean): string {
    const parts: string[] = []
    parts.push(req === '' ? 'AI 未收到具体需求，已为你生成全身均衡计划'
      : `AI 已解析你的需求「${req}」`)
    const understood: string[] = []
    if (goalBuild) {
      understood.push('增肌目标')
    } else if (goalBurn) {
      understood.push('减脂目标')
    }
    if (minutes > 0) {
      understood.push(`${minutes} 分钟时长`)
    }
    if (bodyweightOnly) {
      understood.push('徒手训练')
    }
    if (isBeginner) {
      understood.push('新手友好强度')
    }
    if (understood.length > 0) {
      parts.push(`识别到：${understood.join(' · ')}`)
    }
    let totalSets: number = 0
    for (let i = 0; i < moves.length; i++) {
      totalSets += moves[i].suggestSets
    }
    parts.push(`生成 ${moves.length} 个动作共 ${totalSets} 组，预计用时 ~${Math.max(15, totalSets * 2)} 分钟`)
    return parts.join('；')
  }

  private static planTipsOf(goalBuild: boolean, goalBurn: boolean, bodyweightOnly: boolean,
    isBeginner: boolean, moves: GymMove[]): string[] {
    const tips: string[] = []
    tips.push('训练前动态热身 5 分钟：肩绕环、髋屈伸、开合跳各 1 组')
    tips.push(goalBuild ? '组间休息 90 秒，保证大重量下的动作质量'
      : (goalBurn ? '组间休息控制在 45 秒内，保持心率区间燃脂'
        : '组间休息 60 秒，节奏张弛有度'))
    if (bodyweightOnly) {
      tips.push('徒手训练以慢速离心控制代替负重，感受目标肌肉发力')
    }
    if (isBeginner) {
      tips.push('前两周以动作为主、重量为辅，把每个动作的轨迹练标准')
    }
    tips.push('训练后 30 分钟内补充蛋白质（约 20g），并做好目标肌群静态拉伸')
    return tips
  }

  /** ---------- 能力五：AI 对话定制一周训练计划 ---------- */

  /** 周一 0 点时间戳（本周起点） */
  static mondayTs(): number {
    const now: Date = new Date()
    const day: number = now.getDay() === 0 ? 7 : now.getDay()
    return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() - (day - 1) * 86400000
  }

  /** 今天在本周的序号：0=周一 … 6=周日 */
  static todayIndexOfWeek(): number {
    return (new Date().getDay() + 6) % 7
  }

  /** AI 计划对话开场白 */
  static greetWeekPlan(): AiChatMessage {
    return AiChatMessage.of('ai',
      '你好！我是你的 AI 健身教练 🤖\n告诉我这周的目标和安排（比如「增肌，一周练5天」「减脂，多安排有氧」「周三练核心」「新手徒手」），我立刻为你定制一周训练计划，并自动保存到「我的」页的 AI 本周训练计划里，完成的训练日会自动打勾 ✅',
      Date.now())
  }

  /**
   * AI 对话回复：理解用户输入的自然语言需求，生成/调整一周训练计划。
   * 问候/用法类问题返回纯文本；需求类输入返回本周计划摘要并携带计划。
   */
  static weekPlanChatReply(input: string): AiChatReply {
    const req: string = input.trim()
    const reply: AiChatReply = new AiChatReply()
    if (req === '') {
      reply.text = '说说你的训练需求吧，比如「增肌，一周练5天」或「减脂，多安排有氧」'
      return reply
    }
    if (req.indexOf('你好') >= 0 || req.indexOf('怎么用') >= 0 || req.indexOf('你能') >= 0
      || req.indexOf('你是谁') >= 0 || req.indexOf('帮助') >= 0) {
      reply.text = '我可以根据你的目标（增肌/减脂）、想练的部位、一周训练天数、器械条件和水平，'
        + '为你定制一周训练计划 🗓️\n直接说出需求即可，例如「减脂，一周练4天，多安排有氧」。'
        + '也可以指定某一天，比如「周五练核心」「周日休息」。'
      return reply
    }
    const plan: AiWeekPlan = AiCoach.generateWeekPlan(req)
    reply.plan = plan
    reply.text = AiCoach.weekPlanSummaryOf(plan)
    return reply
  }

  /**
   * 生成一周训练计划：解析目标/天数/部位指定/器械/水平，
   * 按训练分化轮换排布 7 天（含休息日），每天动作参数按需求调整。
   */
  static generateWeekPlan(requirement: string): AiWeekPlan {
    const req: string = requirement.trim()
    const goalBuild: boolean = req.indexOf('增肌') >= 0 || req.indexOf('力量') >= 0
    const goalBurn: boolean = !goalBuild &&
      (req.indexOf('减脂') >= 0 || req.indexOf('减肥') >= 0 || req.indexOf('瘦身') >= 0 || req.indexOf('塑形') >= 0)
    const bodyweightOnly: boolean = req.indexOf('徒手') >= 0 || req.indexOf('无器械') >= 0 || req.indexOf('自重') >= 0
    const isBeginner: boolean = req.indexOf('新手') >= 0 || req.indexOf('入门') >= 0 || req.indexOf('初级') >= 0
    const isAdvanced: boolean = req.indexOf('进阶') >= 0 || req.indexOf('高强度') >= 0 || req.indexOf('挑战') >= 0
    const trainDays: number = AiCoach.parseTrainDays(req)

    // 训练分化轮换（按目标）
    const rotation: string[] = goalBuild
      ? ['chest', 'back', 'leg', 'core', 'chest', 'back', 'full']
      : (goalBurn
        ? ['cardio', 'core', 'cardio', 'full', 'cardio', 'leg', 'cardio']
        : ['chest', 'back', 'leg', 'core', 'cardio', 'full', 'core'])

    // 指定日解析：「周三练腿」「周日休息」
    const labels: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
    const partOverrides: (string | undefined)[] = [undefined, undefined, undefined,
      undefined, undefined, undefined, undefined]
    const restOverrides: boolean[] = [false, false, false, false, false, false, false]
    for (let i = 0; i < labels.length; i++) {
      const pos: number = req.indexOf(labels[i])
      if (pos < 0) {
        continue
      }
      const window: string = req.substring(pos, Math.min(pos + 8, req.length))
      if (window.indexOf('休') >= 0) {
        restOverrides[i] = true
        continue
      }
      const key: string | undefined = AiCoach.partKeyOf(window)
      if (key !== undefined) {
        partOverrides[i] = key
      }
    }

    const plan: AiWeekPlan = new AiWeekPlan()
    plan.requirement = req
    plan.goalWord = goalBuild ? '增肌' : (goalBurn ? '减脂' : '均衡')
    plan.generatedAt = Date.now()
    const monday: number = AiCoach.mondayTs()
    let rotIdx: number = 0
    let scheduled: number = 0
    for (let i = 0; i < 7; i++) {
      const day: AiWeekPlanDay = new AiWeekPlanDay()
      day.label = labels[i]
      day.dateKey = FormatUtils.dateKeyOf(monday + i * 86400000)
      const override: string | undefined = partOverrides[i]
      if (restOverrides[i]) {
        day.rest = true
        day.focus = '休息'
      } else if (override !== undefined) {
        day.rest = false
        day.focus = AiCoach.focusTitleOf(override)
        day.moves = AiCoach.buildFocusMoves(override, goalBuild, goalBurn,
          bodyweightOnly, isBeginner, isAdvanced)
      } else if (scheduled < trainDays) {
        scheduled += 1
        const key: string = rotation[rotIdx % rotation.length]
        rotIdx += 1
        day.rest = false
        day.focus = AiCoach.focusTitleOf(key)
        day.moves = AiCoach.buildFocusMoves(key, goalBuild, goalBurn,
          bodyweightOnly, isBeginner, isAdvanced)
      } else {
        day.rest = true
        day.focus = '休息'
      }
      plan.days.push(day)
    }
    return plan
  }

  /** 解析一周训练天数：「练4天 / 一周5练 / 3练」，默认 5，范围 2-7 */
  private static parseTrainDays(req: string): number {
    const patterns: RegExp[] = [
      new RegExp('练\\s*(\\d+)\\s*天'),
      new RegExp('一周\\s*(\\d+)\\s*练'),
      new RegExp('(\\d+)\\s*练')
    ]
    for (let i = 0; i < patterns.length; i++) {
      const m: RegExpMatchArray | null = req.match(patterns[i])
      if (m !== null && m.length > 1) {
        const n: number = Number(m[1])
        if (n >= 2 && n <= 7) {
          return n
        }
      }
    }
    return 5
  }

  /** 需求片段 → 部位键 */
  private static partKeyOf(window: string): string | undefined {
    if (window.indexOf('有氧') >= 0 || window.indexOf('心肺') >= 0 || window.indexOf('跑步机') >= 0) {
      return 'cardio'
    }
    if (window.indexOf('胸') >= 0) {
      return 'chest'
    }
    if (window.indexOf('腿') >= 0 || window.indexOf('臀') >= 0 || window.indexOf('下肢') >= 0) {
      return 'leg'
    }
    if (window.indexOf('背') >= 0) {
      return 'back'
    }
    if (window.indexOf('手臂') >= 0 || window.indexOf('二头') >= 0 || window.indexOf('弯举') >= 0) {
      return 'arm'
    }
    if (window.indexOf('核心') >= 0 || window.indexOf('腹') >= 0 || window.indexOf('腰') >= 0) {
      return 'core'
    }
    return undefined
  }

  private static focusTitleOf(key: string): string {
    if (key === 'chest') {
      return '胸臂推力'
    }
    if (key === 'leg') {
      return '腿臀力量'
    }
    if (key === 'back') {
      return '背部拉力'
    }
    if (key === 'arm') {
      return '手臂雕刻'
    }
    if (key === 'core') {
      return '核心强化'
    }
    if (key === 'cardio') {
      return '有氧燃动'
    }
    return '全身循环'
  }

  private static focusMoveIdsOf(key: string): string[] {
    if (key === 'chest') {
      return ['g_bench', 'g_curl', 'g_crunch']
    }
    if (key === 'leg') {
      return ['g_squat', 'g_deadlift', 'g_crunch']
    }
    if (key === 'back') {
      return ['g_pullup', 'g_row', 'g_crunch']
    }
    if (key === 'arm') {
      return ['g_curl', 'g_bench', 'g_pullup']
    }
    if (key === 'core') {
      return ['g_crunch', 'g_row', 'g_squat']
    }
    if (key === 'cardio') {
      return ['g_treadmill', 'g_row', 'g_crunch']
    }
    return ['g_bench', 'g_squat', 'g_row', 'g_crunch']
  }

  /** 按部位键构建当日动作（参数按目标/器械/水平调整） */
  private static buildFocusMoves(key: string, goalBuild: boolean, goalBurn: boolean,
    bodyweightOnly: boolean, isBeginner: boolean, isAdvanced: boolean): GymMove[] {
    const ids: string[] = AiCoach.focusMoveIdsOf(key)
    const moves: GymMove[] = []
    for (let i = 0; i < ids.length; i++) {
      const src: GymMove | undefined = GymService.getMoveById(ids[i])
      if (src === undefined) {
        continue
      }
      moves.push(AiCoach.tuneMove(src, goalBuild, goalBurn, bodyweightOnly, isBeginner, isAdvanced, 0))
    }
    return moves
  }

  /** 周计划对话摘要文案 */
  private static weekPlanSummaryOf(plan: AiWeekPlan): string {
    const lines: string[] = []
    const head: string = plan.requirement === '' ? '均衡安排' : plan.requirement
    lines.push(`收到！已按「${head}」为你定制本周计划（${plan.goalWord}）：`)
    let trainCount: number = 0
    for (let i = 0; i < plan.days.length; i++) {
      const d: AiWeekPlanDay = plan.days[i]
      if (d.rest) {
        lines.push(`${d.label} 🛌 休息`)
      } else {
        trainCount += 1
        lines.push(`${d.label} ${d.focus}（${d.moves.length} 个动作）`)
      }
    }
    lines.push(`本周共 ${trainCount} 天训练，已保存到「我的」页与健身页的 AI 本周训练计划 ✅`)
    lines.push('继续对话可随时调整，比如说「改成一周练4天」「周五练核心」。')
    return lines.join('\n')
  }
}
