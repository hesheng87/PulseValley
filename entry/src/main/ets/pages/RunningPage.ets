/**
 * 脉动光谷 - 运动中页
 * 实时面板：时长/里程/配速/步数 + GPS/分布式同步状态 + 暂停/继续/结束
 * 数据链路：Location Kit 轨迹 + 计步传感器 + DDO 软总线同步（详设 3.1-3.4）
 * 跨设备流转：手表震动提醒（配速/心率/整公里） + 队友实时数据 + 语音加油弹幕
 */
import { common } from '@kit.AbilityKit'
import {
  CheerMessage, DeviceAlertEvent, LivePanelState, SessionStatus, SportRecord, SportType, EnvSnapshot
} from '../common/Types'
import { SportSession } from '../service/SportSession'
import { StoreService } from '../service/StoreService'
import { AchievementEngine } from '../service/AchievementEngine'
import { ChallengeService } from '../service/ChallengeService'
import { EnvService } from '../service/EnvService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { HealthService } from '../service/HealthService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'
import { RunningParams, ResultParams } from '../model/RouteParams'

@Entry
@Component
struct RunningPage {
  @State panel: LivePanelState = new LivePanelState()
  @State sportName: string = '跑步'
  @State alertEvent: DeviceAlertEvent = new DeviceAlertEvent()
  @State cheer: CheerMessage = new CheerMessage()
  @State liveMateKm: number = 0
  @State flowOnline: number = 0
  private recordSaved: boolean = false
  private liveMateTimer: number = -1

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as RunningParams
    let type: SportType = SportType.RUN
    if (params !== undefined && params.type === SportType.RIDE) {
      type = SportType.RIDE
    } else if (params !== undefined && params.type === SportType.WALK) {
      type = SportType.WALK
    }
    this.sportName = FormatUtils.sportNameOf(type)
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)

    // 分布式社交组网：成就/排行榜跨设备同步通道
    DeviceFlowService.getInstance().openSocialSync(context)
    // 手机 + 手表同时使用：拉起虚拟手表，心率/步频实时写入软总线同步至本页面板
    DeviceFlowService.getInstance().startAllDevices()
    HealthService.getInstance().startWatch()

    SportSession.getInstance().start(context, type,
      (panel: LivePanelState): void => {
        this.panel = panel
        this.evaluateWatch(panel)
      },
      (record: SportRecord): void => {
        this.onFinished(record)
      })

    // 语音加油实时流（模拟经软总线从队友设备推送）
    DeviceFlowService.getInstance().startCheerFeed((cheer: CheerMessage): void => {
      this.cheer = cheer
    })
    // 队友实时数据（软总线 DDO 拉取队友端里程，演示版定时模拟增量）
    this.liveMateTimer = setInterval((): void => {
      this.liveMateKm = Math.round((this.liveMateKm + 0.04 + Math.random() * 0.08) * 100) / 100
    }, 15000)
    this.flowOnline = DeviceFlowService.getInstance().onlineCount()
  }

  aboutToDisappear(): void {
    // 页面销毁时若仍在运动（异常退出路径），保留会话供恢复（详设 3.1.3）
    if (this.liveMateTimer >= 0) {
      clearInterval(this.liveMateTimer)
      this.liveMateTimer = -1
    }
    DeviceFlowService.getInstance().stopCheerFeed()
  }

  /** 手表端跨设备流转提醒：配速偏慢/心率偏高/整公里庆祝，本机震动同步演示 */
  private evaluateWatch(panel: LivePanelState): void {
    const alert: DeviceAlertEvent = DeviceFlowService.getInstance().evaluateWatchAlert(panel)
    if (alert.text !== '') {
      this.alertEvent = alert
    }
  }

  onBackPress(): boolean {
    if (SportSession.getInstance().isRunning()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '运动进行中，请先结束运动' })
      } catch (e) {
        console.error('[RunningPage] showToast failed')
      }
      return true
    }
    return false
  }

  private onFinished(record: SportRecord): void {
    if (this.recordSaved) {
      return
    }
    this.recordSaved = true
    DeviceFlowService.getInstance().onSessionEnd()
    if (this.liveMateTimer >= 0) {
      clearInterval(this.liveMateTimer)
      this.liveMateTimer = -1
    }
    const store: StoreService = StoreService.getInstance()
    const stats = store.saveRecord(record)
    const env: EnvSnapshot = EnvService.getInstance().getSnapshot()
    const badges = AchievementEngine.evaluateOnFinish(record, stats.totalKm, stats.streakDays, env)
    ChallengeService.applyRecordProgress(record)
    store.flush()
    // 分布式成就与排行榜：任意设备完成挑战，成就与排名立即同步到所有组网设备
    DeviceFlowService.getInstance().broadcastAchievements()

    const badgeIds: string[] = []
    for (let i = 0; i < badges.length; i++) {
      badgeIds.push(badges[i].id)
    }
    const p: ResultParams = { recordId: record.id, newBadges: badgeIds.join(',') }
    try {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/ResultPage', params: p })
    } catch (e) {
      console.error('[RunningPage] replaceUrl failed')
    }
  }

  private doFinish(): void {
    SportSession.getInstance().finish()
  }

  /** 倒计时阶段取消运动 */
  private cancelCountdown(): void {
    SportSession.getInstance().finish()
    this.getUIContext().getRouter().back()
  }

  /** 我向队友发送语音加油（广播到所有队友设备） */
  private sendCheer(): void {
    const texts: string[] = ['我也在跑，一起冲！💪', '看我的配速，跟上来！🔥', '完赛奶茶我请！🧋']
    const idx: number = Math.floor(Math.random() * texts.length)
    const cheer: CheerMessage = DeviceFlowService.getInstance().sendCheer('我', '📣',
      texts[Math.min(idx, texts.length - 1)])
    this.cheer = cheer
    try {
      this.getUIContext().getPromptAction().showToast({ message: `语音加油已广播：${cheer.text}` })
    } catch (e) {
      console.error('[RunningPage] showToast failed')
    }
  }

  @Builder
  metricCell(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(17)
        .fontColor(Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
      Text(label)
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  statusChip(text: string, color: string) {
    Text(text)
      .fontSize(11)
      .fontColor(color)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(Theme.CARD_BG)
      .borderRadius(12)
  }

  @Builder
  alertBanner() {
    if (this.alertEvent.text !== '') {
      Text(this.alertEvent.text)
        .fontSize(12)
        .fontColor(Theme.ORANGE)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('rgba(245,166,35,0.14)')
        .borderRadius(12)
        .width('100%')
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.alertEvent = new DeviceAlertEvent()
        })
    }
  }

  @Builder
  cheerBanner() {
    if (this.cheer.text !== '') {
      Row({ space: 8 }) {
        Text(this.cheer.avatar)
          .fontSize(14)
        Text(`${this.cheer.from} 为你语音加油：${this.cheer.text}`)
          .fontSize(12)
          .fontColor(Theme.BLUE)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('rgba(77,141,255,0.14)')
      .borderRadius(12)
      .onClick(() => {
        this.cheer = new CheerMessage()
      })
    }
  }

  @Builder
  countdownView() {
    Column({ space: 18 }) {
      Text('准备开始')
        .fontSize(15)
        .fontColor(Theme.TEXT_SUB)
      Stack() {
        Progress({ value: 3 - this.panel.countdownNum, total: 3, type: ProgressType.Ring })
          .width(150)
          .height(150)
          .color(Theme.GREEN)
          .style({ strokeWidth: 6 })
        Text(`${this.panel.countdownNum}`)
          .fontSize(64)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
      }
      .width(150)
      .height(150)
      Text(`${this.sportName}即将开始 · 手表与平板已就绪`)
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
      Button('取消')
        .height(38)
        .fontSize(13)
        .backgroundColor(Theme.CARD_BG)
        .fontColor(Theme.TEXT_SUB)
        .borderRadius(19)
        .padding({ left: 24, right: 24 })
        .onClick(() => {
          this.cancelCountdown()
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        this.statusChip(this.panel.gpsMode ? `GPS · ${this.panel.gpsFixCount} 点` : '步数估算模式',
          this.panel.gpsMode ? Theme.GREEN : Theme.ORANGE)
        this.statusChip(this.panel.syncOnline ? '分布式同步 · 已组网' : '分布式同步 · 仅本机',
          this.panel.syncOnline ? Theme.GREEN : Theme.TEXT_SUB)
        this.statusChip(`${this.flowOnline} 端协同`, Theme.PURPLE)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      this.alertBanner()
      this.cheerBanner()

      if (this.panel.status === SessionStatus.PREPARING) {
        this.countdownView()
      } else {
        Column({ space: 6 }) {
          Text(this.sportName)
            .fontSize(14)
            .fontColor(Theme.TEXT_SUB)
          Text(FormatUtils.durationOf(this.panel.durationS))
            .fontSize(56)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text(this.panel.status === SessionStatus.PAUSED ? '已暂停' : '进行中')
            .fontSize(13)
            .fontColor(this.panel.status === SessionStatus.PAUSED ? Theme.ORANGE : Theme.GREEN)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 10 })

        Column({ space: 4 }) {
          Text(`${FormatUtils.kmOf(this.panel.distanceM)}`)
            .fontSize(42)
            .fontColor(Theme.GREEN)
            .fontWeight(FontWeight.Bold)
          Text('公里')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Row() {
          this.metricCell(FormatUtils.paceOf(this.panel.paceSecPerKm), '配速/km')
          this.metricCell(this.panel.bestPaceSecPerKm > 0 ? FormatUtils.paceOf(this.panel.bestPaceSecPerKm) : '--',
            '最佳配速')
          this.metricCell(`${this.panel.steps}`, '步数')
          this.metricCell(`${this.panel.cadence}`, '步频')
          this.metricCell(`${this.panel.heartRate > 0 ? this.panel.heartRate : '--'}`, '心率·手表')
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .margin({ left: 16, right: 16 })

        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text(`🏃 阿凯 ${this.liveMateKm} km`)
              .fontSize(12)
              .fontColor(Theme.TEXT_MAIN)
            Text('队友实时里程 · 平板看板同步中')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('📣 加油')
            .height(34)
            .fontSize(12)
            .backgroundColor('rgba(139,92,246,0.20)')
            .fontColor(Theme.PURPLE)
            .borderRadius(17)
            .onClick(() => {
              this.sendCheer()
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .margin({ left: 16, right: 16 })

        Blank()

        Row({ space: 14 }) {
          Button(this.panel.status === SessionStatus.PAUSED ? '继续' : '暂停')
            .width(110)
            .height(52)
            .backgroundColor(Theme.CARD_BG)
            .fontColor(Theme.TEXT_MAIN)
            .fontSize(16)
            .borderRadius(Theme.RADIUS_BTN)
            .onClick(() => {
              if (this.panel.status === SessionStatus.PAUSED) {
                SportSession.getInstance().resume()
              } else {
                SportSession.getInstance().pause()
              }
            })

          Button('结束')
            .width(150)
            .height(52)
            .backgroundColor(Theme.GREEN)
            .fontColor('#06281A')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .borderRadius(Theme.RADIUS_BTN)
            .onClick(() => {
              this.doFinish()
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 40 })
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .linearGradient({
      angle: 160,
      colors: [[Theme.BG_TOP, 0.0], [Theme.BG_BOTTOM, 1.0]]
    })
  }
}
