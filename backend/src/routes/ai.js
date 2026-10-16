/**
 * AI 域（对应端侧 AiCoach，云端大模型等价实现：规则+模板）：
 *   POST /v1/ai/route-narrate   智能路线推荐叙事 {aqi, temp, historyKm, routeName}
 *   POST /v1/ai/finish-analyze  赛后深度分析 {record:{type,distanceM,durationS,paceSecPerKm,calorie,pointCount}, env:{aqi,temp}, stats:{totalKm}}
 *   POST /v1/ai/plan-generate   AI 训练计划生成 {requirement}（自然语言需求 → 训练计划）
 *   POST /v1/ai/week-plan      AI 一周训练计划生成（对话定制） {requirement}
 *   GET  /v1/ai/mate-match      智能组队匹配（运动水平/时间偏好/目标三维匹配）
 * 生产环境替换为盘古大模型 / 端云协同推理。
 */
import { ok, fail, readBody } from '../response.js'
import { getDb } from '../store.js'

const SPORT_NAMES = ['跑步', '健走', '骑行', '游泳']

function aqiLevelOf(aqi) {
  if (aqi <= 50) {
    return '优'
  }
  if (aqi <= 100) {
    return '良'
  }
  if (aqi <= 150) {
    return '轻度污染'
  }
  return '污染'
}

function fmtKm(m) {
  return (m / 1000).toFixed(2).replace(/\.?0+$/, '')
}

function fmtDuration(s) {
  const min = Math.floor(s / 60)
  const sec = s % 60
  return `${min}分${sec.toString().padStart(2, '0')}秒`
}

function fmtPace(secPerKm) {
  const min = Math.floor(secPerKm / 60)
  const sec = secPerKm % 60
  return `${min}'${sec.toString().padStart(2, '0')}"`
}

function requireUid(res, uid) {
  if (!uid) {
    fail(res, 4010, 'unauthorized: token missing or invalid')
    return false
  }
  return true
}

export async function routeNarrate(req, res) {
  const body = await readBody(req)
  const aqi = Number(body.aqi || 0)
  const temp = Number(body.temp || 20)
  const historyKm = Number(body.historyKm || 0)
  const routeName = String(body.routeName || '').trim()
  if (!routeName) {
    fail(res, 4001, 'routeName is required')
    return
  }
  const aqiWord = aqi <= 50 ? '空气清透' : (aqi <= 100 ? '空气质量尚可' : '空气一般')
  const bodyWord = temp >= 24 ? '体感偏暖，注意补水' : (temp <= 14 ? '体感微凉，充分热身' : '体感舒适')
  const expWord = historyKm >= 50 ? '以你目前的跑量' : (historyKm >= 10 ? '结合你近期的运动积累' : '考虑到你刚开始建立运动习惯')
  const goalWord = historyKm >= 50 ? '可以尝试分段提速' : '建议保持匀速完成'
  ok(res, {
    narration: `AI 综合分析：当前${aqiWord}（AQI ${aqi}）、${temp}℃${bodyWord}，${expWord}，`
      + `推荐「${routeName}」，${goalWord}，尽情享受这段路线吧。`
  })
}

export async function finishAnalyze(req, res) {
  const body = await readBody(req)
  const r = body.record || {}
  const env = body.env || {}
  const stats = body.stats || {}
  const distanceM = Number(r.distanceM || 0)
  const durationS = Number(r.durationS || 0)
  if (distanceM <= 0 || durationS <= 0) {
    fail(res, 4001, 'record.distanceM/durationS are required and must be positive')
    return
  }
  const type = Number(r.type || 0)
  const km = distanceM / 1000
  const avgPace = Number(r.paceSecPerKm || 0)
  const aqi = Number(env.aqi || 0)
  const totalKm = Number(stats.totalKm || 0)
  const pointCount = Number(r.pointCount || 0)

  // 综合评分（与端侧打分口径一致，保证端云等价）
  let score = 62
  if (km >= 3) {
    score += 8
  }
  if (km >= 5) {
    score += 8
  }
  if (km >= 8) {
    score += 6
  }
  if (avgPace > 0 && avgPace <= 360) {
    score += 8
  } else if (avgPace > 0 && avgPace <= 420) {
    score += 5
  }
  if (pointCount > 20) {
    score += 4
  }
  score = Math.min(score, 99)

  const sportName = SPORT_NAMES[type] || '运动'
  const title = km >= 8 ? `${sportName}长距离挑战达成` : (km >= 3 ? `${sportName}表现稳健` : '轻量活动完成')

  const recoveryTips = []
  if (km >= 5) {
    recoveryTips.push('运动后 30 分钟内补充碳水和蛋白质，帮助肌肉恢复')
  }
  if (avgPace > 0 && avgPace <= 360) {
    recoveryTips.push('配速较快，注意拉伸股四头肌与小腿，避免延迟性酸痛')
  }
  if (aqi > 100) {
    recoveryTips.push('当前空气一般，回到室内后再摘下口罩并及时补水')
  }
  if (recoveryTips.length === 0) {
    recoveryTips.push('适当步行放松，保持水分摄入即可')
  }

  let nextGoal = ''
  if (totalKm < 10) {
    nextGoal = `本周再完成 2 次 3km ${sportName}，向累计 10 公里里程碑进发`
  } else if (km < 5) {
    nextGoal = '下次尝试 5 公里，配速保持当前水平即可'
  } else if (avgPace === 0 || avgPace > 420) {
    nextGoal = '尝试在 5 公里内把平均配速压进 7 分钟'
  } else {
    nextGoal = `尝试 ${Math.min(Math.round((km + 2) * 10) / 10, 15)} 公里，配速再提升 10 秒`
  }

  const summary = `本次${sportName} ${fmtKm(distanceM)} 公里、用时 ${fmtDuration(durationS)}`
    + (avgPace > 0 ? `、平均配速 ${fmtPace(avgPace)}` : '')
    + `，消耗约 ${Number(r.calorie || 0)} 千卡。`
    + (pointCount > 0 ? `轨迹由 ${pointCount} 个 GPS 采集点拟合。` : '本次以步数估算里程。')
    + `运动时 AQI ${aqi}（${aqiLevelOf(aqi)}）。`

  const shareCopy = `我刚用脉动光谷完成 ${fmtKm(distanceM)} 公里${sportName}，`
    + (avgPace > 0 ? `配速 ${fmtPace(avgPace)}，` : '')
    + `AI 评分 ${score} 分，快来一起动起来！`

  ok(res, {
    title,
    summary,
    score,
    recoveryTips,
    nextGoal,
    shareCopy,
    aiSummaryForPost: `AI 训练总结：${fmtKm(distanceM)}km 综合评分 ${score} 分，`
      + `处于${score >= 85 ? '极佳' : (score >= 70 ? '良好' : '稳定')}区间。`
      + `下一步目标——${nextGoal}`
  })
}

export async function mateMatch(res, uid) {  if (!requireUid(res, uid)) {
    return
  }
  const d = getDb()
  const me = d.users[uid]
  if (!me) {
    fail(res, 4010, 'user not found')
    return
  }
  const myKm = me.weeklyKm || 0
  const friends = d.friends[uid] || []
  const matches = d.communityUsers
    .filter((u) => !friends.includes(u.id))
    .map((u) => {
      // 三维匹配：运动水平（周里程差）为主，等级与目标为辅
      const kmGap = Math.abs(u.weeklyKm - myKm)
      const levelGap = Math.abs(u.level - (me.level || 1))
      const score = Math.max(40, Math.round(95 - kmGap * 1.2 - levelGap * 4))
      const reason = kmGap <= 5
        ? `周里程相近（${u.weeklyKm}km），配速习惯大概率合拍`
        : (u.weeklyKm > myKm ? `${u.name} 跑量更大，可以带你进阶` : `${u.name} 与你水平互补，适合互相打卡督促`)
      return { user: u, matchScore: score, reason }
    })
    .sort((a, b) => b.matchScore - a.matchScore)
  ok(res, { matches })
}

/**
 * AI 训练计划生成：把自然语言需求发给 AI，自动生成对应训练计划。
 * 需求解析维度与端侧 AiCoach.generateTrainingPlan 保持一致（端云评分口径一致）：
 * 目标（增肌/减脂）、部位（胸/腿/背/手臂/核心/有氧）、时长、器械（徒手）、水平（新手/进阶）。
 */
const PLAN_MOVE_SETS = {
  cardio: ['g_treadmill', 'g_row', 'g_crunch'],
  chest: ['g_bench', 'g_curl', 'g_crunch'],
  leg: ['g_squat', 'g_deadlift', 'g_crunch'],
  back: ['g_pullup', 'g_row', 'g_crunch'],
  arm: ['g_curl', 'g_bench', 'g_pullup'],
  core: ['g_crunch', 'g_row', 'g_squat'],
  full: ['g_bench', 'g_squat', 'g_row', 'g_crunch']
}

function parseMinutes(req) {
  if (req.includes('半小时')) {
    return 30
  }
  const m = req.match(/(\d+)\s*(分钟|min)/i)
  if (m && Number(m[1]) > 0 && Number(m[1]) <= 180) {
    return Number(m[1])
  }
  return 0
}

export async function planGenerate(req, res) {
  const d = getDb()
  const body = await readBody(req)
  const req0 = String(body.requirement || '').trim()
  const goalBuild = req0.includes('增肌') || req0.includes('力量')
  const goalBurn = !goalBuild &&
    (req0.includes('减脂') || req0.includes('减肥') || req0.includes('瘦身') || req0.includes('塑形'))
  const minutes = parseMinutes(req0)
  const bodyweightOnly = req0.includes('徒手') || req0.includes('无器械') || req0.includes('自重')
  const isBeginner = req0.includes('新手') || req0.includes('入门') || req0.includes('初级')
  const isAdvanced = req0.includes('进阶') || req0.includes('高强度') || req0.includes('挑战')

  let key = 'full'
  if (req0.includes('有氧') || req0.includes('心肺') || req0.includes('跑步机')) {
    key = 'cardio'
  } else if (req0.includes('胸')) {
    key = 'chest'
  } else if (req0.includes('腿') || req0.includes('臀') || req0.includes('下肢')) {
    key = 'leg'
  } else if (req0.includes('背')) {
    key = 'back'
  } else if (req0.includes('手臂') || req0.includes('二头') || req0.includes('弯举')) {
    key = 'arm'
  } else if (req0.includes('核心') || req0.includes('腹') || req0.includes('腰')) {
    key = 'core'
  }

  const moves = PLAN_MOVE_SETS[key]
    .map((id) => d.gymMoves.find((m) => m.id === id))
    .filter((m) => m)
    .map((src) => {
      let sets = src.sets
      let reps = src.reps
      let suggestKg = src.suggestKg
      if (goalBuild) {
        reps = Math.max(6, reps - 2)
        sets = Math.min(5, sets + 1)
        suggestKg = Math.round(suggestKg * 1.1)
      } else if (goalBurn) {
        reps = reps + 4
        sets = Math.max(3, sets - 1)
        suggestKg = Math.round(suggestKg * 0.6)
      }
      if (bodyweightOnly) {
        suggestKg = 0
        reps = reps + 4
      }
      if (isBeginner) {
        suggestKg = Math.round(suggestKg * 0.6)
        sets = Math.max(2, sets - 1)
      }
      if (isAdvanced) {
        suggestKg = suggestKg + 5
        sets = Math.min(5, sets + 1)
      }
      if (minutes > 0 && minutes <= 20) {
        sets = Math.min(sets, 3)
      }
      return {
        id: src.id, name: src.name, emoji: src.emoji, muscle: src.muscle,
        sets, reps, suggestKg
      }
    })

  // 时长约束：每组约 2 分钟（含休息），超预算则裁剪
  if (minutes > 0) {
    const budgetSets = Math.max(4, Math.floor(minutes / 2))
    let used = 0
    for (let i = 0; i < moves.length; i++) {
      if (used + moves[i].sets > budgetSets && used >= budgetSets * 0.7) {
        moves.splice(i)
        break
      }
      if (used + moves[i].sets > budgetSets) {
        moves[i].sets = Math.max(2, budgetSets - used)
      }
      used += moves[i].sets
    }
  }

  const goalWord = goalBuild ? '增肌' : (goalBurn ? '减脂' : '均衡')
  const partWord = {
    cardio: '有氧燃动', chest: '胸臂推力', leg: '腿臀力量',
    back: '背部拉力', arm: '手臂雕刻', core: '核心强化', full: '全身循环'
  }[key]
  const title = `${goalWord} · ${partWord}`

  const totalSets = moves.reduce((acc, m) => acc + m.sets, 0)
  const understood = []
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

  const noteParts = []
  noteParts.push(req0 === '' ? 'AI 未收到具体需求，已生成全身均衡计划' : `AI 已解析你的需求「${req0}」`)
  if (understood.length > 0) {
    noteParts.push(`识别到：${understood.join(' · ')}`)
  }
  noteParts.push(`生成 ${moves.length} 个动作共 ${totalSets} 组，预计用时 ~${Math.max(15, totalSets * 2)} 分钟`)

  const tips = [
    '训练前动态热身 5 分钟：肩绕环、髋屈伸、开合跳各 1 组',
    goalBuild ? '组间休息 90 秒，保证大重量下的动作质量'
      : (goalBurn ? '组间休息控制在 45 秒内，保持心率区间燃脂' : '组间休息 60 秒，节奏张弛有度'),
    '训练后 30 分钟内补充蛋白质（约 20g），并做好目标肌群静态拉伸'
  ]

  ok(res, { title, moves, tips, note: noteParts.join('；') }, 'training plan generated')
}

/**
 * AI 一周训练计划生成（对话定制）：解析目标/天数/指定日/器械/水平，
 * 生成 7 天计划（含休息日），每天动作参数按需求调整。
 * 与端侧 AiCoach.generateWeekPlan 逻辑保持一致（端云口径一致）。
 */
const WEEK_LABELS = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
const WEEK_ROTATION = {
  build: ['chest', 'back', 'leg', 'core', 'chest', 'back', 'full'],
  burn: ['cardio', 'core', 'cardio', 'full', 'cardio', 'leg', 'cardio'],
  balance: ['chest', 'back', 'leg', 'core', 'cardio', 'full', 'core']
}
const WEEK_FOCUS = {
  cardio: '有氧燃动', chest: '胸臂推力', leg: '腿臀力量',
  back: '背部拉力', arm: '手臂雕刻', core: '核心强化', full: '全身循环'
}

function parseTrainDays(req) {
  const patterns = [/练\s*(\d+)\s*天/, /一周\s*(\d+)\s*练/, /(\d+)\s*练/]
  for (let i = 0; i < patterns.length; i++) {
    const m = req.match(patterns[i])
    if (m && Number(m[1]) >= 2 && Number(m[1]) <= 7) {
      return Number(m[1])
    }
  }
  return 5
}

function partKeyOfWindow(win) {
  if (win.includes('有氧') || win.includes('心肺') || win.includes('跑步机')) {
    return 'cardio'
  }
  if (win.includes('胸')) {
    return 'chest'
  }
  if (win.includes('腿') || win.includes('臀') || win.includes('下肢')) {
    return 'leg'
  }
  if (win.includes('背')) {
    return 'back'
  }
  if (win.includes('手臂') || win.includes('二头') || win.includes('弯举')) {
    return 'arm'
  }
  if (win.includes('核心') || win.includes('腹') || win.includes('腰')) {
    return 'core'
  }
  return null
}

function tuneWeekMove(src, goalBuild, goalBurn, bodyweightOnly, isBeginner, isAdvanced) {
  let sets = src.sets
  let reps = src.reps
  let suggestKg = src.suggestKg
  if (goalBuild) {
    reps = Math.max(6, reps - 2)
    sets = Math.min(5, sets + 1)
    suggestKg = Math.round(suggestKg * 1.1)
  } else if (goalBurn) {
    reps = reps + 4
    sets = Math.max(3, sets - 1)
    suggestKg = Math.round(suggestKg * 0.6)
  }
  if (bodyweightOnly) {
    suggestKg = 0
    reps = reps + 4
  }
  if (isBeginner) {
    suggestKg = Math.round(suggestKg * 0.6)
    sets = Math.max(2, sets - 1)
  }
  if (isAdvanced) {
    suggestKg = suggestKg + 5
    sets = Math.min(5, sets + 1)
  }
  return { id: src.id, name: src.name, emoji: src.emoji, muscle: src.muscle, sets, reps, suggestKg }
}

function buildWeekMoves(key, d, goalBuild, goalBurn, bodyweightOnly, isBeginner, isAdvanced) {
  return PLAN_MOVE_SETS[key]
    .map((id) => d.gymMoves.find((m) => m.id === id))
    .filter((m) => m)
    .map((src) => tuneWeekMove(src, goalBuild, goalBurn, bodyweightOnly, isBeginner, isAdvanced))
}

export async function weekPlanGenerate(req, res) {
  const d = getDb()
  const body = await readBody(req)
  const req0 = String(body.requirement || '').trim()
  const goalBuild = req0.includes('增肌') || req0.includes('力量')
  const goalBurn = !goalBuild &&
    (req0.includes('减脂') || req0.includes('减肥') || req0.includes('瘦身') || req0.includes('塑形'))
  const bodyweightOnly = req0.includes('徒手') || req0.includes('无器械') || req0.includes('自重')
  const isBeginner = req0.includes('新手') || req0.includes('入门') || req0.includes('初级')
  const isAdvanced = req0.includes('进阶') || req0.includes('高强度') || req0.includes('挑战')
  const trainDays = parseTrainDays(req0)
  const rotation = goalBuild ? WEEK_ROTATION.build : (goalBurn ? WEEK_ROTATION.burn : WEEK_ROTATION.balance)

  // 指定日解析：「周X练Y部位」覆盖轮换，「周X休息」强制休息
  const partOverrides = new Array(7).fill(null)
  const restOverrides = new Array(7).fill(false)
  for (let i = 0; i < WEEK_LABELS.length; i++) {
    const pos = req0.indexOf(WEEK_LABELS[i])
    if (pos < 0) {
      continue
    }
    const win = req0.substring(pos, Math.min(pos + 8, req0.length))
    if (win.includes('休')) {
      restOverrides[i] = true
      continue
    }
    const key = partKeyOfWindow(win)
    if (key) {
      partOverrides[i] = key
    }
  }

  // 本周一 0 点为周计划起点
  const now = new Date()
  const dayOfWeek = now.getDay() === 0 ? 7 : now.getDay()
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime() - (dayOfWeek - 1) * 86400000

  const days = []
  let rotIdx = 0
  let scheduled = 0
  for (let i = 0; i < 7; i++) {
    const date = new Date(monday + i * 86400000)
    const dateKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
    const day = { label: WEEK_LABELS[i], dateKey, rest: true, focus: '休息', moves: [] }
    if (restOverrides[i]) {
      day.rest = true
      day.focus = '休息'
    } else if (partOverrides[i]) {
      day.rest = false
      day.focus = WEEK_FOCUS[partOverrides[i]]
      day.moves = buildWeekMoves(partOverrides[i], d, goalBuild, goalBurn, bodyweightOnly, isBeginner, isAdvanced)
    } else if (scheduled < trainDays) {
      scheduled += 1
      const key = rotation[rotIdx % rotation.length]
      rotIdx += 1
      day.rest = false
      day.focus = WEEK_FOCUS[key]
      day.moves = buildWeekMoves(key, d, goalBuild, goalBurn, bodyweightOnly, isBeginner, isAdvanced)
    }
    days.push(day)
  }

  const goalWord = goalBuild ? '增肌' : (goalBurn ? '减脂' : '均衡')
  const trainCount = days.filter((x) => !x.rest).length
  const summaryLines = [`收到！已按「${req0 === '' ? '均衡安排' : req0}」为你定制本周计划（${goalWord}）：`]
  for (const day of days) {
    summaryLines.push(day.rest ? `${day.label} 🛌 休息` : `${day.label} ${day.focus}（${day.moves.length} 个动作）`)
  }
  summaryLines.push(`本周共 ${trainCount} 天训练，已保存到「我的」页与健身页的 AI 本周训练计划`)

  ok(res, { requirement: req0, goalWord, generatedAt: Date.now(), days, summary: summaryLines.join('\n') },
    'week plan generated')
}
