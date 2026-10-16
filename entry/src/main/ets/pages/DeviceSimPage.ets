/**
 * 脉动光谷 - 多设备演示厅（纯软件演示）
 * 手机 + 手表 + 平板可同时启动组网：
 * - 手表面板：虚拟手表实时采集心率/血氧/压力/步数并经软总线上报
 * - 平板看板：实时大屏展示手机端运动数据（里程/配速/心率/队友排行）
 * - 数据链路：手表写 heartRate/cadence → 手机运动页实时显示；手机写 distance/pace → 平板看板实时显示
 * 单机即可完整演示"多设备同时使用、数据毫秒级同步"
 */
import { common } from '@kit.AbilityKit'
import {
  AiPlanResult, Challenge, ChallengeMember as ChallengeMember2, FlowDevice, GymMove,
  HealthSnapshot, SportSyncSource, SessionStatus
} from '../common/Types'
import { StoreService } from '../service/StoreService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { HealthService } from '../service/HealthService'
import { ChallengeService } from '../service/ChallengeService'
import { GymService } from '../service/GymService'
import { AiCoach } from '../service/AiCoach'
import { SyncChannel } from '../service/SyncChannel'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'

@Entry
@Component
struct DeviceSimPage {
  @State devices: FlowDevice[] = []
  @State health: HealthSnapshot = new HealthSnapshot()
  @State sync: SportSyncSource = new SportSyncSource()
  @State challenges: Challenge[] = []
  @State planMoves: GymMove[] = []
  @State planTitle: string = ''
  @State refreshId: number = 0
  private timerId: number = -1

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    DeviceFlowService.getInstance().openSocialSync(context)
    this.devices = DeviceFlowService.getInstance().listDevices()
    this.challenges = ChallengeService.list()
    // 健身计划由 AI 生成（沿用已应用计划，否则生成默认全身均衡计划）
    if (GymService.getActivePlan().length > 0) {
      this.planMoves = GymService.getActivePlan()
      this.planTitle = GymService.getPlanTitle()
    } else {
      const plan: AiPlanResult = AiCoach.generateTrainingPlan('')
      GymService.applyPlan(plan.moves, plan.title)
      this.planMoves = plan.moves
      this.planTitle = plan.title
    }
    // 演示厅打开即自动拉起全部设备，展示"多端同时使用"
    DeviceFlowService.getInstance().startAllDevices()
    this.refreshTick()
    this.timerId = setInterval((): void => {
      this.refreshTick()
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private refreshTick(): void {
    this.health = HealthService.getInstance().getSnapshot()
    this.sync = SyncChannel.getInstance().getSource()
    this.devices = DeviceFlowService.getInstance().listDevices().slice()
    this.challenges = ChallengeService.list()
    this.refreshId += 1
  }

  private toggle(id: string): void {
    const online: boolean = DeviceFlowService.getInstance().toggleDevice(id)
    const name: string = id === 'dev_watch' ? '手表' : (id === 'dev_pad' ? '平板' : '手机')
    try {
      this.getUIContext().getPromptAction()
        .showToast({ message: online ? `${name}已启动并加入组网` : `${name}已停止` })
    } catch (e) {
      console.error('[DeviceSimPage] showToast failed')
    }
    this.devices = DeviceFlowService.getInstance().listDevices().slice()
  }

  @Builder
  deviceCard(d: FlowDevice) {
    Row({ space: 12 }) {
      Text(d.emoji)
        .fontSize(26)
      Column({ space: 3 }) {
        Text(d.name)
          .fontSize(14)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
        Text(d.role)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Blank()
      if (d.id === 'dev_phone') {
        Text('🟢 本机运行中')
          .fontSize(12)
          .fontColor(Theme.GREEN)
      } else {
        Toggle({ type: ToggleType.Switch, isOn: d.online })
          .selectedColor(Theme.GREEN)
          .onChange((isOn: boolean) => {
            this.toggle(d.id)
          })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .border({ width: 1, color: d.online ? 'rgba(52,199,123,0.4)' : Theme.CARD_STROKE })
  }

  /** 模拟手表表盘面板：实时健康数据（手表端视角） */
  @Builder
  watchPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('⌚ 手表端 · 实时健康采集')
          .fontSize(14)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(DeviceFlowService.getInstance().isDeviceOnline('dev_watch') ? '🟢 采集中' : '⚪ 已停止')
          .fontSize(11)
          .fontColor(DeviceFlowService.getInstance().isDeviceOnline('dev_watch') ? Theme.GREEN : Theme.TEXT_SUB)
      }
      .width('100%')

      Column({ space: 4 }) {
        Text(`${this.health.heartRate > 0 ? this.health.heartRate : '--'}`)
          .fontSize(46)
          .fontColor(Theme.RED)
          .fontWeight(FontWeight.Bold)
        Text('实时心率 bpm')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Row() {
        Column({ space: 3 }) {
          Text(`${this.health.spo2}`)
            .fontSize(16)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('血氧 %')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 3 }) {
          Text(`${this.health.stress}`)
            .fontSize(16)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('压力指数')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 3 }) {
          Text(`${this.health.steps}`)
            .fontSize(16)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('今日步数')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 3 }) {
          Text(`${this.health.calories}`)
            .fontSize(16)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('千卡')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      Text(`睡眠 ${HealthService.sleepBaseline()} h · 静息心率 ${this.health.restingHr} bpm · 已上报手机端 ♻️`)
        .fontSize(10)
        .fontColor(Theme.BLUE)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .padding(14)
    .backgroundColor('rgba(232,64,74,0.08)')
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  /** 模拟平板大屏看板：实时展示手机端运动数据（平板端视角） */
  @Builder
  padPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('📲 平板端 · 大屏数据看板')
          .fontSize(14)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(DeviceFlowService.getInstance().isDeviceOnline('dev_pad') ? '🟢 看板在线' : '⚪ 已停止')
          .fontSize(11)
          .fontColor(DeviceFlowService.getInstance().isDeviceOnline('dev_pad') ? Theme.GREEN : Theme.TEXT_SUB)
      }
      .width('100%')

      Row() {
        Column({ space: 4 }) {
          Text(FormatUtils.kmOf(this.sync.distanceM))
            .fontSize(30)
            .fontColor(Theme.GREEN)
            .fontWeight(FontWeight.Bold)
          Text('里程 km')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text(FormatUtils.paceOf(this.sync.paceSecPerKm))
            .fontSize(30)
            .fontColor(Theme.BLUE)
            .fontWeight(FontWeight.Bold)
          Text('配速/km')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text(`${this.sync.heartRate > 0 ? this.sync.heartRate : '--'}`)
            .fontSize(30)
            .fontColor(Theme.RED)
            .fontWeight(FontWeight.Bold)
          Text('心率(手表)')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text(`${this.sync.steps}`)
            .fontSize(30)
            .fontColor(Theme.ORANGE)
            .fontWeight(FontWeight.Bold)
          Text('步数')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      Row({ space: 8 }) {
        Text(this.sync.status === SessionStatus.RECORDING ? '🏃 手机端运动进行中' : '⏸ 手机端空闲/暂停')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .layoutWeight(1)
        Text(`已跑 ${this.sync.lapKm} 整公里`)
          .fontSize(11)
          .fontColor(Theme.PURPLE)
      }
      .width('100%')

      if (this.challenges.length > 0) {
        Divider()
          .color(Theme.CARD_STROKE)
        Text('组队挑战排行（实时同步）')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
        ForEach(this.challenges[0].members, (m: ChallengeMember2) => {
          Row({ space: 8 }) {
            Text(m.avatar)
              .fontSize(13)
            Text(m.name + (m.isMe ? '（我）' : ''))
              .fontSize(12)
              .fontColor(m.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
              .layoutWeight(1)
            Text(`${m.progressKm} km`)
              .fontSize(12)
              .fontColor(Theme.TEXT_MAIN)
          }
          .width('100%')
        }, (m: ChallengeMember2) => `${this.refreshId}_${m.name}_${m.progressKm}`)
      }
    }
    .padding(14)
    .backgroundColor('rgba(77,141,255,0.08)')
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 4 }) {
          Text('📡 多设备演示厅')
            .fontSize(22)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text('手机 / 手表 / 平板同时启动 · 分布式软总线毫秒级同步')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 20 })

        ForEach(this.devices, (d: FlowDevice) => {
          this.deviceCard(d)
        }, (d: FlowDevice) => `${d.id}_${d.online}`)

        Row({ space: 10 }) {
          Text('🔗 流转链路：')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
          Text('手表写心率 → 手机面板显示；手机写里程/配速 → 平板看板显示')
            .fontSize(11)
            .fontColor(Theme.PURPLE)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(12)

        this.watchPanel()
        this.padPanel()

        Column({ space: 6 }) {
          Text('🏋️ 手表同步健身计划（AI 生成）')
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          Text(`AI ${this.planTitle}：`)
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
          ForEach(this.planMoves, (m: GymMove) => {
            Text(`${m.emoji} ${m.name} · ${m.suggestSets}组×${m.suggestReps}次` +
              (m.suggestWeightKg > 0 ? ` · ${m.suggestWeightKg}kg` : ' · 自重'))
              .fontSize(11)
              .fontColor(Theme.TEXT_MAIN)
              .width('100%')
          }, (m: GymMove) => m.id)
        }
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
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
}
