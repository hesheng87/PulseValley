/**
 * 脉动光谷 - 手表端简化主页（wearable 专用）
 * 仅保留核心能力：
 * 1. 运动实时数据：心率 / 计时 / 运动时长 / 步数 / 卡路里
 * 2. 运动快捷启停（一键开始 / 一键结束）
 * 3. 消息提醒（手表消息中心 + 震动）
 * 4. 运动结束提醒（震动 + 结束弹窗汇总，记录保存并同步手机）
 * 5. 蓝牙快速连接手机 + 账号保存（回连免配对）
 */
import { common } from '@kit.AbilityKit'
import { Theme } from '../common/Theme'
import { SportRecord, SportType } from '../common/Types'
import { StoreService } from '../service/StoreService'
import { WatchLinkService, WatchLinkStatus, WatchMessage } from '../service/WatchLinkService'

const STEP_PER_LAP: number = 1300
const HR_ALERT_HIGH: number = 165
const HR_ALERT_THROTTLE_MS: number = 180000
const PHONE_MSG_RUNNING_TICK: number = 30
const PHONE_MSG_IDLE_TICK: number = 60

@Entry
@Component
struct WatchIndex {
  @State linkStatus: WatchLinkStatus = WatchLinkStatus.DISCONNECTED
  @State phoneName: string = ''
  @State accountNickname: string = ''
  @State accountInput: string = ''
  @State showAccountEditor: boolean = false
  @State running: boolean = false
  @State durationS: number = 0
  @State steps: number = 0
  @State calorieKcal: number = 0
  @State heartRate: number = 72
  @State messages: WatchMessage[] = []
  @State showEndDialog: boolean = false
  @State endDurationS: number = 0
  @State endSteps: number = 0
  @State endCalories: number = 0
  @State endAvgHr: number = 0
  @State endSaved: boolean = false
  private timerId: number = -1
  private calorieAcc: number = 0
  private hrSum: number = 0
  private hrCount: number = 0
  private lastLap: number = 0
  private lastHrAlertTs: number = 0
  private phoneMsgTick: number = 0
  private phoneMsgPool: string[] = [
    '阿凯：跑起来了？我在手机上看着你的数据呢 💪',
    '小曼：注意心率，别冲太猛！❤️',
    '运动提醒：今日目标还差 1 公里，加油！🎯',
    '老周：数据已同步到手机，随时查看轨迹 📱',
    '喝水提醒：运动中记得少量多次补水 💧'
  ]

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    const link = WatchLinkService.getInstance()
    link.init(context)
    this.linkStatus = link.getStatus()
    this.phoneName = link.getPairedPhone().name
    this.accountNickname = link.getAccount().nickname
    this.accountInput = link.getAccount().nickname
    this.messages = link.getMessages().slice()
    // 已保存配对手机：启动即蓝牙快速回连（免配对免登录）
    if (link.hasPairedPhone() && link.getPairedPhone().autoConnect) {
      link.scanAndConnect()
      link.pushMessage('🔗', `正在快速回连 ${link.getPairedPhone().name}...`)
      this.messages = link.getMessages().slice()
    }
    this.timerId = setInterval((): void => {
      this.tick()
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  /** 每秒刷新：蓝牙状态 / 实时数据模拟 / 阈值提醒 / 手机消息推送 */
  private tick(): void {
    const link = WatchLinkService.getInstance()
    this.linkStatus = link.getStatus()
    this.phoneName = link.getPairedPhone().name
    this.accountNickname = link.getAccount().nickname

    if (this.running) {
      this.durationS += 1
      this.steps += 2 + Math.floor(Math.random() * 3)
      this.calorieAcc += 0.12 + Math.random() * 0.08
      this.calorieKcal = Math.round(this.calorieAcc)
    }

    // 心率随机游走：运动态抬升至有氧区间，静息态回落
    const targetHr: number = this.running ? 148 + Math.round(Math.random() * 18) : 72 + Math.round(Math.random() * 8)
    const drift: number = Math.round((targetHr - this.heartRate) * 0.3) +
      (Math.random() > 0.5 ? 1 : -1)
    this.heartRate = Math.max(55, Math.min(this.heartRate + drift, 190))
    if (this.running) {
      this.hrSum += this.heartRate
      this.hrCount += 1
    }

    const now: number = Date.now()
    // 每整公里（按步数估算）庆祝提醒
    const lap: number = Math.floor(this.steps / STEP_PER_LAP)
    if (this.running && lap > this.lastLap) {
      this.lastLap = lap
      link.pushMessage('🎉', `完成第 ${lap} 公里！手表为你震动庆祝`)
    }
    // 心率过高提醒（3 分钟节流）
    if (this.running && this.heartRate > HR_ALERT_HIGH && now - this.lastHrAlertTs > HR_ALERT_THROTTLE_MS) {
      this.lastHrAlertTs = now
      link.pushMessage('❗', `心率 ${this.heartRate} 偏高，请放慢节奏调整呼吸`)
    }
    // 手机消息推送（蓝牙已连接时模拟接收）
    this.phoneMsgTick += 1
    const threshold: number = this.running ? PHONE_MSG_RUNNING_TICK : PHONE_MSG_IDLE_TICK
    if (link.isConnected() && this.phoneMsgTick >= threshold) {
      this.phoneMsgTick = 0
      const idx: number = Math.floor(Math.random() * this.phoneMsgPool.length)
      link.pushMessage('📱', this.phoneMsgPool[Math.min(idx, this.phoneMsgPool.length - 1)])
    }
    this.messages = link.getMessages().slice()
  }

  /** 运动快捷启动 */
  private startWorkout(): void {
    const link = WatchLinkService.getInstance()
    this.running = true
    this.durationS = 0
    this.steps = 0
    this.calorieAcc = 0
    this.calorieKcal = 0
    this.hrSum = this.heartRate
    this.hrCount = 1
    this.lastLap = 0
    this.lastHrAlertTs = 0
    this.phoneMsgTick = 0
    this.showEndDialog = false
    link.vibrate(300)
    link.pushMessage('🏃', '运动开始！实时数据采集中')
    this.messages = link.getMessages().slice()
  }

  /** 运动快捷结束：震动 + 结束提醒弹窗，记录保存并同步手机 */
  private stopWorkout(): void {
    const link = WatchLinkService.getInstance()
    this.running = false
    this.endDurationS = this.durationS
    this.endSteps = this.steps
    this.endCalories = this.calorieKcal
    this.endAvgHr = this.hrCount > 0 ? Math.round(this.hrSum / this.hrCount) : this.heartRate
    link.vibrate(600)
    link.pushMessage('🏁', `运动结束：${this.formatClock(this.endDurationS)} · ${this.endSteps} 步 · ${this.endCalories} 千卡`)

    // 保存运动记录（Local-First 落盘，蓝牙连接时同步至手机端）
    const distanceM: number = Math.round(this.endSteps * 0.7)
    const record: SportRecord = SportRecord.of(`watch_${Date.now()}`, SportType.RUN,
      Date.now() - this.endDurationS * 1000, Date.now(), distanceM, this.endDurationS,
      this.endSteps, this.endCalories,
      distanceM > 0 ? Math.round(this.endDurationS / (distanceM / 1000)) : 0, 0)
    StoreService.getInstance().saveRecord(record)
    this.endSaved = link.isConnected()
    this.showEndDialog = true
    this.messages = link.getMessages().slice()
  }

  private toggleWorkout(): void {
    if (this.running) {
      this.stopWorkout()
    } else {
      this.startWorkout()
    }
  }

  private formatClock(sec: number): string {
    const m: number = Math.floor(sec / 60)
    const s: number = sec % 60
    const mm: string = m < 10 ? `0${m}` : `${m}`
    const ss: string = s < 10 ? `0${s}` : `${s}`
    return `${mm}:${ss}`
  }

  private formatTime(ts: number): string {
    const d: Date = new Date(ts)
    const h: number = d.getHours()
    const mi: number = d.getMinutes()
    const hh: string = h < 10 ? `0${h}` : `${h}`
    const mss: string = mi < 10 ? `0${mi}` : `${mi}`
    return `${hh}:${mss}`
  }

  /** 快速连接手机 */
  private quickConnect(): void {
    const link = WatchLinkService.getInstance()
    link.scanAndConnect()
    link.pushMessage('🔍', '正在蓝牙扫描附近手机...')
    this.linkStatus = link.getStatus()
    this.messages = link.getMessages().slice()
  }

  private saveAccountEdit(): void {
    const name: string = this.accountInput.trim()
    if (name === '') {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '账号昵称不能为空' })
      } catch (e) {
        console.error('[WatchIndex] showToast failed')
      }
      return
    }
    const link = WatchLinkService.getInstance()
    link.saveAccount(name, link.getAccount().phoneNo)
    this.accountNickname = name
    this.showAccountEditor = false
    link.pushMessage('✅', `账号 ${name} 已保存，下次连接免登录`)
    this.messages = link.getMessages().slice()
  }

  @Builder
  linkCard() {
    Column({ space: 6 }) {
      if (this.linkStatus === WatchLinkStatus.CONNECTED) {
        Row({ space: 6 }) {
          Text('🟢')
            .fontSize(12)
          Text('蓝牙已连接')
            .fontSize(12)
            .fontColor(Theme.GREEN)
            .fontWeight(FontWeight.Bold)
        }
        Text(this.phoneName !== '' ? this.phoneName : '我的手机')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else if (this.linkStatus === WatchLinkStatus.SCANNING) {
        Text('🔍 蓝牙扫描手机中...')
          .fontSize(12)
          .fontColor(Theme.BLUE)
      } else {
        Button('🔗 快速连接手机')
          .fontSize(13)
          .fontColor(Theme.TEXT_MAIN)
          .backgroundColor(Theme.BLUE)
          .borderRadius(Theme.RADIUS_BTN)
          .width('100%')
          .onClick(() => {
            this.quickConnect()
          })
        if (this.phoneName !== '') {
          Text(`上次配对：${this.phoneName}（自动回连中）`)
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  accountCard() {
    Column({ space: 6 }) {
      if (this.showAccountEditor) {
        TextInput({ placeholder: '输入账号昵称', text: this.accountInput })
          .fontSize(13)
          .height(36)
          .backgroundColor('rgba(255,255,255,0.10)')
          .onChange((value: string) => {
            this.accountInput = value
          })
        Row({ space: 8 }) {
          Button('保存')
            .fontSize(12)
            .backgroundColor(Theme.GREEN)
            .borderRadius(Theme.RADIUS_BTN)
            .layoutWeight(1)
            .onClick(() => {
              this.saveAccountEdit()
            })
          Button('取消')
            .fontSize(12)
            .backgroundColor('rgba(255,255,255,0.15)')
            .fontColor(Theme.TEXT_MAIN)
            .borderRadius(Theme.RADIUS_BTN)
            .layoutWeight(1)
            .onClick(() => {
              this.showAccountEditor = false
              this.accountInput = this.accountNickname
            })
        }
        .width('100%')
      } else {
        Row({ space: 6 }) {
          Text('👤')
            .fontSize(13)
          Text(this.accountNickname !== '' ? this.accountNickname : '未保存账号')
            .fontSize(13)
            .fontColor(this.accountNickname !== '' ? Theme.TEXT_MAIN : Theme.TEXT_SUB)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('编辑')
            .fontSize(11)
            .fontColor(Theme.BLUE)
            .onClick(() => {
              this.accountInput = this.accountNickname
              this.showAccountEditor = true
            })
        }
        .width('100%')
        if (this.accountNickname !== '' && this.linkStatus === WatchLinkStatus.CONNECTED) {
          Text('账号已保存 · 蓝牙连接后自动同步手机')
            .fontSize(10)
            .fontColor(Theme.GREEN)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
  }

  @Builder
  realTimeCard() {
    Column({ space: 8 }) {
      Column({ space: 2 }) {
        Text(`${this.heartRate}`)
          .fontSize(40)
          .fontColor(Theme.RED)
          .fontWeight(FontWeight.Bold)
        Text('❤ 实时心率 bpm')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Column({ space: 2 }) {
        Text(this.formatClock(this.durationS))
          .fontSize(30)
          .fontColor(this.running ? Theme.GREEN : Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
        Text('⏱ 计时 · 运动时长')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Row() {
        Column({ space: 2 }) {
          Text(`${this.steps}`)
            .fontSize(18)
            .fontColor(Theme.ORANGE)
            .fontWeight(FontWeight.Bold)
          Text('步数')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 2 }) {
          Text(`${this.calorieKcal}`)
            .fontSize(18)
            .fontColor(Theme.PURPLE)
            .fontWeight(FontWeight.Bold)
          Text('千卡')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
  }

  @Builder
  messageCard() {
    Column({ space: 6 }) {
      Text('🔔 消息提醒')
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
      if (this.messages.length === 0) {
        Text('暂无消息')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      ForEach(this.messages, (m: WatchMessage) => {
        Row({ space: 6 }) {
          Text(m.emoji)
            .fontSize(11)
          Column({ space: 1 }) {
            Text(m.text)
              .fontSize(10)
              .fontColor(Theme.TEXT_MAIN)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.formatTime(m.ts))
              .fontSize(9)
              .fontColor(Theme.TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 6, right: 6, top: 4, bottom: 4 })
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(10)
      }, (m: WatchMessage) => `${m.id}`)
    }
    .width('100%')
    .padding(10)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  endDialogOverlay() {
    Column({ space: 10 }) {
      Text('🏁 运动结束')
        .fontSize(18)
        .fontColor(Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Bold)
      Text(this.formatClock(this.endDurationS))
        .fontSize(34)
        .fontColor(Theme.GREEN)
        .fontWeight(FontWeight.Bold)
      Column({ space: 4 }) {
        Text(`步数 ${this.endSteps} 步`)
          .fontSize(12)
          .fontColor(Theme.TEXT_MAIN)
        Text(`卡路里 ${this.endCalories} 千卡`)
          .fontSize(12)
          .fontColor(Theme.TEXT_MAIN)
        Text(`平均心率 ${this.endAvgHr} bpm`)
          .fontSize(12)
          .fontColor(Theme.TEXT_MAIN)
      }
      .alignItems(HorizontalAlign.Center)
      Text(this.endSaved ? '✅ 记录已保存并同步至手机' : '✅ 记录已本地保存')
        .fontSize(11)
        .fontColor(Theme.GREEN)
      Button('确定')
        .fontSize(13)
        .backgroundColor(Theme.GREEN)
        .borderRadius(Theme.RADIUS_BTN)
        .width('70%')
        .onClick(() => {
          this.showEndDialog = false
        })
    }
    .width('86%')
    .padding(18)
    .backgroundColor('#1B2440')
    .borderRadius(20)
    .border({ width: 1, color: Theme.CARD_STROKE })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 10 }) {
          this.linkCard()
          this.accountCard()
          this.realTimeCard()

          Button(this.running ? '⏹ 结束运动' : '▶ 开始运动')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.running ? Theme.RED : Theme.TEXT_MAIN)
            .backgroundColor(this.running ? 'rgba(232,64,74,0.25)' : Theme.GREEN)
            .borderRadius(28)
            .width('100%')
            .height(46)
            .onClick(() => {
              this.toggleWorkout()
            })

          this.messageCard()
        }
        .padding(12)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)

      if (this.showEndDialog) {
        Column() {
          this.endDialogOverlay()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .onClick(() => {
          this.showEndDialog = false
        })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[Theme.BG_TOP, 0.0], [Theme.BG_BOTTOM, 1.0]]
    })
  }
}
