/**
 * 脉动光谷 - 首页（Tab1，对齐需求文档 8.1）
 * 顶部问候 + 今日步数环(真实计步) + AQI 环境卡(安全红线) + 智能路线推荐(七维打分+AI叙事)
 * + 进行中挑战 + 好友动态预览 + 多设备协同组网卡
 */
import { common } from '@kit.AbilityKit'
import { Challenge, CommunityPost, EnvSnapshot, FlowDevice, RouteRecommend, EnvGuardResult } from '../common/Types'
import { EnvService } from '../service/EnvService'
import { RouteScorer } from '../service/RouteScorer'
import { StepService } from '../service/StepService'
import { ChallengeService } from '../service/ChallengeService'
import { CommunityService } from '../service/CommunityService'
import { StoreService } from '../service/StoreService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { AiCoach } from '../service/AiCoach'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'
import { RunningParams, RouteDetailParams } from '../model/RouteParams'

interface TabEntry {
  label: string
  icon: string
}

@Component
export struct HomeTab {
  @State todaySteps: number = 0
  @State stepAvailable: boolean = false
  @State snap: EnvSnapshot = new EnvSnapshot()
  @State recList: RouteRecommend[] = []
  @State myChallenge: Challenge | undefined = undefined
  @State devices: FlowDevice[] = []
  @State feedPreview: CommunityPost[] = []
  private stepBase: number = -1

  aboutToAppear(): void {
    const store: StoreService = StoreService.getInstance()
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    store.init(context)
    DeviceFlowService.getInstance().openSocialSync(context)
    this.stepAvailable = StepService.getInstance().subscribe((total: number): void => {
      if (this.stepBase < 0) {
        this.stepBase = total
      }
      this.todaySteps = Math.max(0, total - this.stepBase)
    })
    this.refreshEnv()
  }

  aboutToDisappear(): void {
    StepService.getInstance().unsubscribe()
  }

  refreshEnv(): void {
    this.snap = EnvService.getInstance().getSnapshot()
    const statsKm: number = store2()
    this.recList = RouteScorer.recommend(this.snap, statsKm)
    this.devices = DeviceFlowService.getInstance().listDevices()
    this.feedPreview = CommunityService.listPosts().slice(0, 3)
    const list: Challenge[] = ChallengeService.list()
    for (let i = 0; i < list.length; i++) {
      if (list[i].joined) {
        this.myChallenge = list[i]
        break
      }
    }
  }

  /** 进入路线详情页（地图模拟 / 安全提示 / 一键开始） */
  private openRouteDetail(rec: RouteRecommend): void {
    const p: RouteDetailParams = { routeId: rec.route.id }
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/RouteDetailPage', params: p })
    } catch (e) {
      console.error('[HomeTab] openRouteDetail failed')
    }
  }

  /** AI 大模型推荐叙事：融合实时空气/天气/历史运动/身体状态 */
  private aiNarrative(rec: RouteRecommend): string {
    return AiCoach.narrateRoute(this.snap, store2(), rec.route.name)
  }

  startRun(): void {
    const guard: EnvGuardResult = EnvService.safetyCheck(this.snap)
    if (guard === EnvGuardResult.BLOCK) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: EnvService.indoorAdvice() })
      } catch (e) {
        console.error('[HomeTab] showToast failed')
      }
      return
    }
    const p: RunningParams = { type: 0 }
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/RunningPage', params: p })
    } catch (e) {
      console.error('[HomeTab] startRun failed')
    }
  }

  @Builder
  deviceCard() {
    Column({ space: 10 }) {
      Row() {
        Text('📡 多设备协同 · 分布式软总线')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
          .layoutWeight(1)
        Text(`${DeviceFlowService.getInstance().onlineCount() + 1} 端在线`)
          .fontSize(12)
          .fontColor(Theme.GREEN)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Text(DeviceFlowService.getInstance().flowChainText())
        .fontSize(12)
        .fontColor(Theme.PURPLE)
        .width('100%')

      ForEach(this.devices, (d: FlowDevice) => {
        Row({ space: 10 }) {
          Text(d.emoji)
            .fontSize(20)
          Column({ space: 2 }) {
            Text(`${d.name} · ${d.role}`)
              .fontSize(12)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Medium)
            Text(d.flowDesc)
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text(d.online ? `🟢 ${d.lastSyncText}` : '⚪ 离线')
            .fontSize(10)
            .fontColor(d.online ? Theme.GREEN : Theme.TEXT_SUB)
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      }, (d: FlowDevice) => `${d.id}_${d.online}`)

      Button('进入多设备演示厅 ›')
        .width('100%')
        .height(38)
        .fontSize(13)
        .backgroundColor('rgba(139,92,246,0.18)')
        .fontColor(Theme.PURPLE)
        .fontWeight(FontWeight.Medium)
        .borderRadius(19)
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/DeviceSimPage' })
        })
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  aqiCard() {
    Column({ space: 6 }) {
      Row() {
        Text('🌿 校园环境实况')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
        Blank()
        Text(`${EnvService.aqiLevelOf(this.snap.aqi)}`)
          .fontSize(13)
          .fontColor(EnvService.aqiColorOf(this.snap.aqi))
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      Row({ space: 16 }) {
        Column() {
          Text(`${this.snap.aqi}`)
            .fontSize(34)
            .fontColor(EnvService.aqiColorOf(this.snap.aqi))
            .fontWeight(FontWeight.Bold)
          Text('AQI')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Center)
        Column({ space: 3 }) {
          Text(`PM2.5 ${this.snap.pm25}  ·  风${this.snap.wind}级`)
            .fontSize(12)
            .fontColor(Theme.TEXT_MAIN)
          Text(`${this.snap.temp}℃  湿度${this.snap.humidity}%  UV${this.snap.uv}`)
            .fontSize(12)
            .fontColor(Theme.TEXT_MAIN)
          Text(`更新于 ${FormatUtils.timeOf(this.snap.updatedAt)} · ${this.snap.source}`)
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  stepsCard() {
    Row({ space: 16 }) {
      Progress({ value: Math.min(this.todaySteps, 8000), total: 8000, type: ProgressType.Ring })
        .width(64)
        .height(64)
        .color(Theme.GREEN)
        .style({ strokeWidth: 8 })
      Column({ space: 4 }) {
        Row() {
          if (this.stepAvailable) {
            Text(`${this.todaySteps}`)
              .fontSize(26)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
          } else {
            Text('--')
              .fontSize(26)
              .fontColor(Theme.TEXT_SUB)
              .fontWeight(FontWeight.Bold)
          }
          Text(' 步')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(VerticalAlign.Bottom)
        Text(this.stepAvailable ? '今日步数 · 传感器实时统计' : '计步传感器不可用，真机体验实时步数')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  routeCard(rec: RouteRecommend) {
    Column({ space: 8 }) {
      Row() {
        Text(`📍 ${rec.route.name}`)
          .fontSize(16)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(`${rec.score} 分`)
          .fontSize(15)
          .fontColor(Theme.GREEN)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      Text(rec.route.desc)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(rec.reason)
        .fontSize(11)
        .fontColor(Theme.BLUE)
      Text(this.aiNarrative(rec))
        .fontSize(11)
        .fontColor(Theme.PURPLE)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row() {
        Text(`全程 ${rec.route.baseKm} km · ${rec.slot}`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
        Blank()
        Text('去开跑 ›')
          .fontSize(12)
          .fontColor(Theme.GREEN)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
    .onClick(() => {
      this.openRouteDetail(rec)
    })
  }

  @Builder
  feedRow(post: CommunityPost) {
    Row({ space: 10 }) {
      Text(post.authorAvatar)
        .fontSize(22)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(post.authorName)
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text(postDistanceOf(post))
            .fontSize(11)
            .fontColor(Theme.GREEN)
        }
        Text(post.content)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('👍')
        .fontSize(16)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  challengeCard() {
    if (this.myChallenge !== undefined) {
      Column({ space: 8 }) {
        Row() {
          Text(`${this.myChallenge.emoji} ${this.myChallenge.title}`)
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(`截止 ${this.myChallenge.endDate}`)
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        Progress({ value: myProgressOf(this.myChallenge), total: this.myChallenge.targetKm, type: ProgressType.Linear })
          .width('100%')
          .color(Theme.ORANGE)
        Text(`我的进度 ${myProgressOf(this.myChallenge)} / ${this.myChallenge.targetKm} km`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .padding(14)
      .backgroundColor(Theme.CARD_BG)
      .borderRadius(Theme.RADIUS_CARD)
      .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Column() {
            Text('脉动光谷')
              .fontSize(22)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Text('校园运动 · 环境 · 社交全生态')
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('🏃')
            .fontSize(28)
        }
        .width('100%')

        this.aqiCard()
        this.stepsCard()
        this.deviceCard()

        Text('🧭 今晚智能路线推荐')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        ForEach(this.recList, (rec: RouteRecommend) => {
          this.routeCard(rec)
        }, (rec: RouteRecommend) => rec.route.id)

        if (this.myChallenge !== undefined) {
          Text('🤝 进行中的挑战')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          this.challengeCard()
        }

        if (this.feedPreview.length > 0) {
          Text('💬 好友动态')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Column({ space: 4 }) {
            ForEach(this.feedPreview, (post: CommunityPost) => {
              this.feedRow(post)
            }, (post: CommunityPost) => post.id)
          }
          .padding(12)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)
          .width('100%')
        }

        Button('立即开跑')
          .width('100%')
          .height(52)
          .backgroundColor(Theme.GREEN)
          .fontColor('#06281A')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .borderRadius(Theme.RADIUS_BTN)
          .margin({ top: 6, bottom: 24 })
          .onClick(() => {
            this.startRun()
          })
      }
      .padding(16)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }
}

/** 挑战卡片读取"我"的进度 */
function myProgressOf(c: Challenge): number {
  for (let i = 0; i < c.members.length; i++) {
    if (c.members[i].isMe) {
      return c.members[i].progressKm
    }
  }
  return 0
}

/** 首页读取累计里程（推荐偏好特征输入） */
function store2(): number {
  return StoreService.getInstance().getUserStats().totalKm
}

/** 好友动态预览的运动数据摘要 */
function postDistanceOf(post: CommunityPost): string {
  if (post.distanceM > 0) {
    return `${FormatUtils.kmOf(post.distanceM)} km · ${FormatUtils.paceOf(post.paceSecPerKm)}`
  }
  return FormatUtils.timeOf(post.startTs)
}
