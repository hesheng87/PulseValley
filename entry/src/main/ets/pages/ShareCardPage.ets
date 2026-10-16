/**
 * 脉动光谷 - 分享卡片页
 * 完成挑战后一键生成分享卡片：AI 文案 + 路线地图 + 解锁勋章 + 多设备同步标识
 * 支持保存到相册（模拟）与一键分享进校园社区
 */
import { common } from '@kit.AbilityKit'
import { BadgeDef, SportRecord } from '../common/Types'
import { StoreService } from '../service/StoreService'
import { AchievementEngine } from '../service/AchievementEngine'
import { AiCoach } from '../service/AiCoach'
import { CommunityService } from '../service/CommunityService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'
import { ShareCardParams } from '../model/RouteParams'

@Entry
@Component
struct ShareCardPage {
  @State record: SportRecord = new SportRecord()
  @State badgeNames: string[] = []
  @State shareCopy: string = ''
  @State loaded: boolean = false
  @State shared: boolean = false

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    const params = this.getUIContext().getRouter().getParams() as ShareCardParams
    if (params === undefined || params.recordId === undefined) {
      return
    }
    const records: SportRecord[] = StoreService.getInstance().getRecords()
    for (let i = 0; i < records.length; i++) {
      if (records[i].id === params.recordId) {
        this.record = records[i]
        break
      }
    }
    if (this.record.id === '') {
      return
    }
    // AI 生成个性化分享文案
    this.shareCopy = AiCoach.shareCopyOf(this.record, this.record.distanceM / 1000)
    // 已解锁勋章名（最多展示 3 枚）
    const unlocked: string[] = StoreService.getInstance().getUnlockedBadgeIds()
    for (let i = 0; i < unlocked.length && this.badgeNames.length < 3; i++) {
      const def: BadgeDef | undefined = AchievementEngine.getById(unlocked[i])
      if (def !== undefined) {
        this.badgeNames.push(`${def.emoji} ${def.name}`)
      }
    }
    this.shared = CommunityService.isRecordShared(this.record.id)
    this.loaded = true
  }

  private doShare(): void {
    CommunityService.shareMyRecord(this.record.id, `🤖 ${this.shareCopy}`)
    this.shared = true
    try {
      this.getUIContext().getPromptAction().showToast({ message: '已生成 AI 动态并分享到校园社区 🎉' })
    } catch (e) {
      console.error('[ShareCardPage] showToast failed')
    }
  }

  @Builder
  posterCard() {
    Column({ space: 14 }) {
      Row() {
        Text('🏃 脉动光谷 · 运动战报')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
        Blank()
        Text(`${FormatUtils.dateKeyOf(this.record.startTs)}`)
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')

      Column({ space: 4 }) {
        Text(`${FormatUtils.kmOf(this.record.distanceM)}`)
          .fontSize(52)
          .fontColor(Theme.GREEN)
          .fontWeight(FontWeight.Bold)
        Text('公里')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Row() {
        Column({ space: 4 }) {
          Text(FormatUtils.durationOf(this.record.durationS))
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('时长')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text(FormatUtils.paceOf(this.record.paceSecPerKm))
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('配速')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text(`${this.record.calorie}`)
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('千卡')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 4 }) {
          Text(`${this.record.steps}`)
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text('步数')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      // 路线地图卡（演示版示意；生产版渲染真实轨迹 Canvas）
      Column({ space: 6 }) {
        Text('📍 路线轨迹地图')
          .fontSize(12)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Medium)
        Text(this.record.pointCount > 0
          ? `${this.record.pointCount} 个 GPS 轨迹点已绘制 · 轨迹已同步至平板看板`
          : '本次轨迹以步数估算生成')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
        Row({ space: 8 }) {
          Text('📱 手机记录')
            .fontSize(10)
            .fontColor(Theme.BLUE)
          Text('›')
            .fontSize(10)
            .fontColor(Theme.BLUE)
          Text('📲 平板看板')
            .fontSize(10)
            .fontColor(Theme.BLUE)
          Text('›')
            .fontSize(10)
            .fontColor(Theme.BLUE)
          Text('⌚ 手表提醒')
            .fontSize(10)
            .fontColor(Theme.BLUE)
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor('rgba(77,141,255,0.10)')
      .borderRadius(12)
      .alignItems(HorizontalAlign.Center)

      Text(this.shareCopy)
        .fontSize(13)
        .fontColor(Theme.ORANGE)
        .width('100%')
        .lineHeight(20)

      if (this.badgeNames.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.badgeNames, (name: string) => {
            Text(name)
              .fontSize(11)
              .fontColor(Theme.TEXT_MAIN)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('rgba(245,166,35,0.14)')
              .borderRadius(12)
              .margin({ right: 6, bottom: 6 })
          }, (name: string) => name)
        }
        .width('100%')
      }

      Row() {
        Text('鸿蒙分布式 · 数据已多端同步')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
        Blank()
        Text('脉动光谷大学')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')
    }
    .padding(18)
    .backgroundColor('rgba(255,255,255,0.05)')
    .borderRadius(24)
    .border({ width: 1, color: Theme.CARD_STROKE })
    .width('100%')
  }

  build() {
    Column({ space: 16 }) {
      Text('🎴 分享卡片')
        .fontSize(22)
        .fontColor(Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24 })

      Text('AI 已为你生成专属分享卡片，快去带动小伙伴一起运动吧')
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)

      if (this.loaded) {
        Scroll() {
          Column({ space: 16 }) {
            this.posterCard()

            Row({ space: 14 }) {
              Button('保存图片')
                .layoutWeight(1)
                .height(48)
                .backgroundColor(Theme.CARD_BG)
                .fontColor(Theme.TEXT_MAIN)
                .fontSize(15)
                .borderRadius(Theme.RADIUS_BTN)
                .onClick(() => {
                  this.getUIContext().getPromptAction().showToast({ message: '分享卡片已保存到相册 🖼️' })
                })
              Button(this.shared ? '已分享到社区' : '一键分享到社区')
                .layoutWeight(1)
                .height(48)
                .backgroundColor(Theme.GREEN)
                .fontColor('#06281A')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .borderRadius(Theme.RADIUS_BTN)
                .onClick(() => {
                  this.doShare()
                })
            }
            .width('100%')

            Text(`当前 ${DeviceFlowService.getInstance().onlineCount() + 1} 台设备组网在线 · 成就与排行已实时同步`)
              .fontSize(11)
              .fontColor(Theme.BLUE)
              .margin({ bottom: 20 })
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
      }

      Button('返回')
        .width('100%')
        .height(48)
        .backgroundColor(Theme.CARD_BG)
        .fontColor(Theme.TEXT_MAIN)
        .fontSize(15)
        .borderRadius(Theme.RADIUS_BTN)
        .margin({ left: 16, right: 16, bottom: 20 })
        .onClick(() => {
          this.getUIContext().getRouter().back()
        })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[Theme.BG_TOP, 0.0], [Theme.BG_BOTTOM, 1.0]]
    })
  }
}
