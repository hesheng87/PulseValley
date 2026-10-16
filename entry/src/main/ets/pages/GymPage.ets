/**
 * 脉动光谷 - 健身房训练页（健身模块）
 * AI 本周训练计划（7 天视图 + 完成打勾）+ AI 计划制定（对话定制入口）
 * 今日计划快速生成：把需求发给 AI → 自动生成对应当日计划
 * 器械动作选择 + 组记录（次数/重量）+ 组间休息倒计时
 * 手表实时心率同步显示；训练结束生成训练档案（容量/卡路里）持久化
 */
import { common } from '@kit.AbilityKit'
import {
  AiPlanResult, AiWeekPlan, AiWeekPlanDay, GymMove, GymSetLog, GymWorkout, HealthSnapshot
} from '../common/Types'
import { StoreService } from '../service/StoreService'
import { GymService, REST_SECONDS, GymTotalStats } from '../service/GymService'
import { AiCoach } from '../service/AiCoach'
import { HealthService } from '../service/HealthService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'

const PLAN_PRESETS: string[] = ['增肌练胸', '减脂有氧', '30分钟快速练', '练腿日', '核心强化', '新手徒手入门']

/** 本周计划展示行（day + 完成态） */
interface AiWeekRow {
  label: string
  focus: string
  rest: boolean
  moveCount: number
  done: boolean
  today: boolean
}

@Entry
@Component
struct GymPage {
  @State active: boolean = false
  @State planTitle: string = ''
  @State planMoves: GymMove[] = []
  @State planTips: string[] = []
  @State planNote: string = ''
  @State requirement: string = ''
  @State allMoves: GymMove[] = []
  @State currentMoveId: string = ''
  @State reps: number = 12
  @State weightKg: number = 20
  @State setLogs: GymSetLog[] = []
  @State restLeft: number = 0
  @State health: HealthSnapshot = new HealthSnapshot()
  @State history: GymWorkout[] = []
  @State totals: GymTotalStats = new GymTotalStats()
  @State weekRows: AiWeekRow[] = []
  @State weekGoal: string = ''
  @State weekDoneCount: number = 0
  private todayOverridden: boolean = false
  private restTimer: number = -1
  private tickTimer: number = -1

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    this.allMoves = GymService.getMoves()
    this.refreshWeekPlan()
    this.history = GymService.history()
    this.totals = GymService.totalStats()
    // 训练中展示手表实时心率：自动拉起虚拟手表
    if (GymService.isActive()) {
      this.active = true
      DeviceFlowService.getInstance().startAllDevices()
    }
    this.currentMoveId = GymService.getCurrentMoveId() !== ''
      ? GymService.getCurrentMoveId() : (this.planMoves.length > 0 ? this.planMoves[0].id : '')
    this.syncMoveSuggest(this.currentMoveId)
    this.setLogs = GymService.getSetLogs()
    this.tickTimer = setInterval((): void => {
      this.health = HealthService.getInstance().getSnapshot()
      this.setLogs = GymService.getSetLogs()
      if (GymService.isActive()) {
        this.active = true
      }
    }, 1000)
  }

  /** 从对话定制页返回时刷新本周计划与完成状态 */
  onPageShow(): void {
    if (StoreService.getInstance().isInited()) {
      this.refreshWeekPlan()
      this.history = GymService.history()
      this.totals = GymService.totalStats()
    }
  }

  /**
   * 加载（或按需初始化）AI 本周训练计划：
   * 1. 无计划或计划不属于本周 → AI 生成默认均衡周计划并保存
   * 2. 按训练档案计算各天完成态（当天有训练记录 = 已完成 ✓）
   * 3. 今日计划默认取自本周计划当天（可用"快速生成"覆盖）
   */
  private refreshWeekPlan(): void {
    const mondayKey: string = FormatUtils.dateKeyOf(AiCoach.mondayTs())
    let plan: AiWeekPlan | undefined = StoreService.getInstance().getAiWeekPlan()
    if (plan === undefined || plan.days.length !== 7 || plan.days[0].dateKey !== mondayKey) {
      plan = AiCoach.generateWeekPlan('')
      StoreService.getInstance().saveAiWeekPlan(plan)
    }
    this.weekGoal = plan.goalWord
    // 完成态：训练档案中当天有记录即视为完成
    const doneKeys: string[] = []
    const workouts: GymWorkout[] = GymService.history()
    for (let i = 0; i < workouts.length; i++) {
      const key: string = FormatUtils.dateKeyOf(workouts[i].startTs)
      if (doneKeys.indexOf(key) < 0) {
        doneKeys.push(key)
      }
    }
    const todayIdx: number = AiCoach.todayIndexOfWeek()
    const rows: AiWeekRow[] = []
    let doneCount: number = 0
    for (let i = 0; i < plan.days.length; i++) {
      const d: AiWeekPlanDay = plan.days[i]
      const done: boolean = !d.rest && doneKeys.indexOf(d.dateKey) >= 0
      if (done) {
        doneCount += 1
      }
      const row: AiWeekRow = {
        label: d.label,
        focus: d.rest ? '休息' : d.focus,
        rest: d.rest,
        moveCount: d.moves.length,
        done: done,
        today: i === todayIdx
      }
      rows.push(row)
    }
    this.weekRows = rows
    this.weekDoneCount = doneCount
    // 今日计划默认取自本周计划当天（未被快速生成覆盖时）
    if (!this.active && !this.todayOverridden) {
      const today: AiWeekPlanDay | undefined = plan.days[todayIdx]
      if (today !== undefined && !today.rest && today.moves.length > 0) {
        this.planTitle = today.focus
        this.planMoves = today.moves
        this.planTips = []
        this.planNote = `来自 AI 本周计划 · ${today.label}（可在下方按需求快速重新生成，或进入对话定制整周）`
        GymService.applyPlan(today.moves, today.focus)
        this.currentMoveId = today.moves[0].id
        this.syncMoveSuggest(this.currentMoveId)
      } else if (today !== undefined && today.rest) {
        this.planNote = `今天是休息日 🛌 可用下方快速生成自由训练，或进入 AI 对话重新定制本周计划`
      }
    }
  }

  aboutToDisappear(): void {
    if (this.restTimer >= 0) {
      clearInterval(this.restTimer)
      this.restTimer = -1
    }
    if (this.tickTimer >= 0) {
      clearInterval(this.tickTimer)
      this.tickTimer = -1
    }
  }

  private syncMoveSuggest(moveId: string): void {
    const m: GymMove | undefined = GymService.getMoveById(moveId)
    if (m !== undefined) {
      this.reps = m.suggestReps
      this.weightKg = m.suggestWeightKg
    }
  }

  /** 应用 AI 生成的计划到页面与训练服务 */
  private applyAiPlan(plan: AiPlanResult): void {
    this.planTitle = plan.title
    this.planMoves = plan.moves
    this.planTips = plan.tips
    this.planNote = plan.note
    GymService.applyPlan(plan.moves, plan.title)
    if (!this.active && plan.moves.length > 0) {
      this.currentMoveId = plan.moves[0].id
      this.syncMoveSuggest(this.currentMoveId)
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (e) {
      console.error('[GymPage] showToast failed')
    }
  }

  /** 把需求发给 AI，快速生成今日训练计划（覆盖本周计划中的当天安排） */
  private generatePlan(): void {
    const plan: AiPlanResult = AiCoach.generateTrainingPlan(this.requirement)
    this.applyAiPlan(plan)
    this.todayOverridden = true
    this.toast(`AI 已生成「${plan.title}」今日计划 🤖`)
  }

  private startWorkout(): void {
    GymService.startWorkout()
    this.active = true
    this.currentMoveId = GymService.getCurrentMoveId()
    this.syncMoveSuggest(this.currentMoveId)
    // 拉起虚拟手表：训练中实时心率经软总线同步显示
    DeviceFlowService.getInstance().startAllDevices()
    this.toast('训练开始！手表已连接，实时心率同步中 ⌚')
  }

  private finishSet(): void {
    if (!this.active) {
      return
    }
    GymService.logSet(this.currentMoveId, this.reps, this.weightKg)
    this.setLogs = GymService.getSetLogs()
    // 组间休息倒计时
    this.startRest(REST_SECONDS)
    // 休息提示经手表震动
    this.toast(`完成一组！手表震动提醒：休息 ${REST_SECONDS} 秒 ⌚`)
  }

  private startRest(seconds: number): void {
    if (this.restTimer >= 0) {
      clearInterval(this.restTimer)
    }
    this.restLeft = seconds
    this.restTimer = setInterval((): void => {
      this.restLeft -= 1
      if (this.restLeft <= 0) {
        this.restLeft = 0
        if (this.restTimer >= 0) {
          clearInterval(this.restTimer)
          this.restTimer = -1
        }
      }
    }, 1000)
  }

  private finishWorkout(): void {
    const workout: GymWorkout | undefined = GymService.finishWorkout()
    this.active = false
    if (workout === undefined) {
      this.toast('本次未记录训练组')
      this.getUIContext().getRouter().back()
      return
    }
    this.history = GymService.history()
    this.totals = GymService.totalStats()
    // 训练成果同步进分布式成就
    DeviceFlowService.getInstance().broadcastAchievements()
    this.toast(`训练完成！${workout.totalSets} 组 · 容量 ${workout.volumeKg}kg · ${workout.calories} 千卡 💪`)
  }

  @Builder
  moveChip(m: GymMove) {
    Column({ space: 4 }) {
      Text(m.emoji)
        .fontSize(22)
      Text(m.name)
        .fontSize(11)
        .fontColor(this.currentMoveId === m.id ? Theme.GREEN : Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Medium)
      Text(`${m.suggestSets}×${m.suggestReps}`)
        .fontSize(9)
        .fontColor(Theme.TEXT_SUB)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(this.currentMoveId === m.id ? 'rgba(52,199,123,0.16)' : Theme.CARD_BG)
    .borderRadius(12)
    .border({ width: 1, color: this.currentMoveId === m.id ? Theme.GREEN : Theme.CARD_STROKE })
    .onClick(() => {
      if (!this.active) {
        this.getUIContext().getPromptAction().showToast({ message: '先开始训练，再选择动作' })
        return
      }
      GymService.selectMove(m.id)
      this.currentMoveId = m.id
      this.syncMoveSuggest(m.id)
    })
  }

  @Builder
  stepperCell(label: string, value: number, step: number, min: number, max: number) {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .layoutWeight(1)
      Button('−')
        .width(34)
        .height(34)
        .fontSize(16)
        .backgroundColor(Theme.CARD_BG)
        .fontColor(Theme.TEXT_MAIN)
        .borderRadius(17)
        .onClick(() => {
          const next: number = Math.max(min, value - step)
          this.applyStep(label, next)
        })
      Text(`${value}`)
        .fontSize(18)
        .fontColor(Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Bold)
        .width(48)
        .textAlign(TextAlign.Center)
      Button('+')
        .width(34)
        .height(34)
        .fontSize(16)
        .backgroundColor(Theme.CARD_BG)
        .fontColor(Theme.TEXT_MAIN)
        .borderRadius(17)
        .onClick(() => {
          const next: number = Math.min(max, value + step)
          this.applyStep(label, next)
        })
    }
    .width('100%')
  }

  private applyStep(label: string, next: number): void {
    if (label === '次数') {
      this.reps = next
    } else {
      this.weightKg = next
    }
  }

  @Builder
  setLogRow(log: GymSetLog) {
    Row({ space: 8 }) {
      Text(log.moveEmoji)
        .fontSize(13)
      Text(log.moveName)
        .fontSize(12)
        .fontColor(Theme.TEXT_MAIN)
        .layoutWeight(1)
      Text(`第${log.setIndex}组 · ${log.reps}次 × ${log.weightKg}kg`)
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
    }
    .width('100%')
    .padding({ top: 5, bottom: 5 })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text('🏋️ 健身房训练')
              .fontSize(22)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Text(`AI 训练计划 · ${this.planTitle}`)
              .fontSize(12)
              .fontColor(Theme.PURPLE)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Blank()
          Text(`${this.health.heartRate > 0 ? `❤️ ${this.health.heartRate}` : '⌚ --'}`)
            .fontSize(16)
            .fontColor(Theme.RED)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .margin({ top: 16 })

        // AI 本周训练计划（7 天视图，完成的训练日自动打勾）
        Column({ space: 10 }) {
          Row() {
            Text('🗓️ AI 本周训练计划')
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
            Blank()
            Text(`目标 ${this.weekGoal} · 已完成 ${this.weekDoneCount} 天`)
              .fontSize(11)
              .fontColor(Theme.GREEN)
          }
          .width('100%')
          ForEach(this.weekRows, (row: AiWeekRow) => {
            Row({ space: 8 }) {
              Text(row.label)
                .fontSize(12)
                .fontColor(row.today ? Theme.PURPLE : Theme.TEXT_MAIN)
                .fontWeight(row.today ? FontWeight.Bold : FontWeight.Normal)
              Text(row.rest ? '🛌 休息日' : `${row.focus} · ${row.moveCount} 个动作`)
                .fontSize(11)
                .fontColor(row.rest ? Theme.TEXT_SUB : Theme.TEXT_MAIN)
                .layoutWeight(1)
              if (row.done) {
                Text('✓ 已完成')
                  .fontSize(10)
                  .fontColor(Theme.GREEN)
              } else if (row.today) {
                Text('今天')
                  .fontSize(10)
                  .fontColor(Theme.PURPLE)
              }
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor(row.today ? 'rgba(139,92,246,0.12)' : Theme.BG_TOP)
            .borderRadius(10)
            .border({ width: row.today ? 1 : 0, color: Theme.PURPLE })
          }, (row: AiWeekRow) => `${row.label}_${row.done}_${row.today}_${row.moveCount}`)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.CARD_STROKE })

        // AI 计划制定入口：对话定制整周计划
        Button('💬 AI 计划制定 · 和 AI 对话定制本周计划')
          .width('100%')
          .height(42)
          .backgroundColor('rgba(139,92,246,0.18)')
          .fontColor(Theme.PURPLE)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .borderRadius(Theme.RADIUS_BTN)
          .border({ width: 1, color: Theme.PURPLE })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/WeekPlanChatPage' })
          })

        // 今日计划快速生成：把需求发给 AI，覆盖本周计划中的当天安排
        Column({ space: 10 }) {
          Text('⚡ 今日计划 · 按需求快速生成')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
          TextInput({ placeholder: '例如：增肌练胸 / 减脂有氧 / 30分钟徒手核心 / 新手入门', text: this.requirement })
            .onChange((value: string) => {
              this.requirement = value
            })
            .fontSize(13)
            .height(42)
            .backgroundColor(Theme.BG_TOP)
            .borderRadius(12)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(PLAN_PRESETS, (preset: string) => {
              Text(preset)
                .fontSize(11)
                .fontColor(this.requirement === preset ? Theme.PURPLE : Theme.TEXT_SUB)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(this.requirement === preset ? 'rgba(139,92,246,0.20)' : Theme.BG_TOP)
                .borderRadius(11)
                .border({
                  width: 1,
                  color: this.requirement === preset ? Theme.PURPLE : Theme.CARD_STROKE
                })
                .margin({ right: 6, bottom: 6 })
                .onClick(() => {
                  this.requirement = preset
                })
            }, (preset: string) => preset)
          }
          .width('100%')
          Button('✨ AI 快速生成今日计划')
            .width('100%')
            .height(44)
            .backgroundColor(Theme.PURPLE)
            .fontColor('#FFFFFF')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .borderRadius(Theme.RADIUS_BTN)
            .onClick(() => {
              this.generatePlan()
            })
          if (this.planNote !== '') {
            Text(`💬 ${this.planNote}`)
              .fontSize(11)
              .fontColor(Theme.PURPLE)
              .width('100%')
              .lineHeight(16)
          }
          Row({ space: 8 }) {
            ForEach(this.planMoves, (m: GymMove) => {
              Column({ space: 3 }) {
                Text(`${m.emoji}${m.name}`)
                  .fontSize(11)
                  .fontColor(Theme.TEXT_MAIN)
                  .fontWeight(FontWeight.Medium)
                Text(`${m.suggestSets}组×${m.suggestReps}次` +
                  (m.suggestWeightKg > 0 ? `·${m.suggestWeightKg}kg` : '·自重'))
                  .fontSize(9)
                  .fontColor(Theme.TEXT_SUB)
              }
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .backgroundColor('rgba(139,92,246,0.14)')
              .borderRadius(10)
              .margin({ bottom: 6 })
            }, (m: GymMove) => `${m.id}_${m.suggestSets}_${m.suggestReps}_${m.suggestWeightKg}`)
          }
          .width('100%')
          if (this.planTips.length > 0) {
            Column({ space: 3 }) {
              ForEach(this.planTips, (tip: string) => {
                Text(`· ${tip}`)
                  .fontSize(10.5)
                  .fontColor(Theme.TEXT_SUB)
                  .width('100%')
                  .lineHeight(15)
              }, (tip: string) => tip)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .padding(12)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (!this.active) {
          Button('开始训练')
            .width('100%')
            .height(52)
            .backgroundColor(Theme.GREEN)
            .fontColor('#06281A')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .borderRadius(Theme.RADIUS_BTN)
            .onClick(() => {
              this.startWorkout()
            })
        } else {
          // 训练中：器械动作选择
          Text('选择当前动作')
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.allMoves, (m: GymMove) => {
              Column() {
                this.moveChip(m)
              }
              .padding({ right: 6, bottom: 6 })
              .width('25%')
            }, (m: GymMove) => `${m.id}_${this.currentMoveId}`)
          }
          .width('100%')

          // 组记录面板
          Column({ space: 12 }) {
            this.stepperCell('次数', this.reps, 1, 1, 100)
            this.stepperCell('重量 kg', this.weightKg, 2.5, 0, 300)
            Button(`✅ 完成一组（本动作第 ${GymService.doneSetsOf(this.currentMoveId) + 1} 组）`)
              .width('100%')
              .height(46)
              .backgroundColor(Theme.BLUE)
              .fontColor('#FFFFFF')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .borderRadius(Theme.RADIUS_BTN)
              .onClick(() => {
                this.finishSet()
              })
          }
          .padding(14)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)
          .width('100%')

          // 组间休息倒计时
          if (this.restLeft > 0) {
            Column({ space: 6 }) {
              Text('⏳ 组间休息')
                .fontSize(12)
                .fontColor(Theme.TEXT_SUB)
              Text(`${this.restLeft}s`)
                .fontSize(34)
                .fontColor(Theme.ORANGE)
                .fontWeight(FontWeight.Bold)
              Progress({ value: REST_SECONDS - this.restLeft, total: REST_SECONDS, type: ProgressType.Linear })
                .width('100%')
                .color(Theme.ORANGE)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('rgba(245,166,35,0.10)')
            .borderRadius(Theme.RADIUS_CARD)
            .alignItems(HorizontalAlign.Center)
          }

          // 已完成组
          if (this.setLogs.length > 0) {
            Column({ space: 2 }) {
              Text(`已完成 ${this.setLogs.length} 组`)
                .fontSize(12)
                .fontColor(Theme.GREEN)
                .fontWeight(FontWeight.Medium)
                .width('100%')
              ForEach(this.setLogs, (log: GymSetLog) => {
                this.setLogRow(log)
              }, (log: GymSetLog) => `${log.ts}_${log.reps}_${log.weightKg}`)
            }
            .padding(12)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          Button('结束训练')
            .width('100%')
            .height(50)
            .backgroundColor(Theme.RED)
            .fontColor('#FFFFFF')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .borderRadius(Theme.RADIUS_BTN)
            .onClick(() => {
              this.finishWorkout()
            })
        }

        // 累计健身统计 + 历史
        Row() {
          this.gymStatCell(`${this.totals.times}`, '训练次数')
          this.gymStatCell(`${this.totals.sets}`, '累计组数')
          this.gymStatCell(`${this.totals.volumeKg}`, '总容量 kg')
          this.gymStatCell(`${this.totals.calories}`, '总千卡')
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)

        if (this.history.length > 0) {
          Text('训练档案')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          ForEach(this.history, (w: GymWorkout) => {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(`${FormatUtils.dateKeyOf(w.startTs)} ${FormatUtils.timeOf(w.startTs)}`)
                  .fontSize(12)
                  .fontColor(Theme.TEXT_MAIN)
                  .fontWeight(FontWeight.Medium)
                Text(`共 ${w.totalSets} 组 · 容量 ${w.volumeKg}kg`)
                  .fontSize(10)
                  .fontColor(Theme.TEXT_SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(`${w.calories} kcal`)
                .fontSize(13)
                .fontColor(Theme.GREEN)
                .fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
          }, (w: GymWorkout) => w.id)
        }

        Text('训练中手表实时采集心率/血氧，数据经分布式软总线同步显示 ⌚')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .margin({ bottom: 24 })
      }
      .padding(16)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
    .linearGradient({
      angle: 160,
      colors: [[Theme.BG_TOP, 0.0], [Theme.BG_BOTTOM, 1.0]]
    })
  }

  @Builder
  gymStatCell(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(18)
        .fontColor(Theme.GREEN)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
