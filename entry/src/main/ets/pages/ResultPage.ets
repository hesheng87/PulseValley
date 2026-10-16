/**
 * 脉动光谷 - 运动结果页
 * 运动摘要海报卡 + AI 深度分析报告 + 新解锁勋章 + 分布式成就同步 + 一键社交分享
 */
import { common } from '@kit.AbilityKit'
import { AiSportReport, BadgeDef, EnvSnapshot, SportRecord } from '../common/Types'
import { StoreService } from '../service/StoreService'
import { AchievementEngine } from '../service/AchievementEngine'
import { AiCoach } from '../service/AiCoach'
import { EnvService } from '../service/EnvService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'
import { ResultParams, ShareCardParams } from '../model/RouteParams'

@Entry
@Component
struct ResultPage {
  @State record: SportRecord = new SportRecord()
  @State newBadges: BadgeDef[] = []
  @State report: AiSportReport = new AiSportReport()
  @State motivateText: string = ''
  @State syncNote: string = ''
  @State loaded: boolean = false

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    const params = this.getUIContext().getRouter().getParams() as ResultParams
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
    const ids: string[] = (params.newBadges ?? '').split(',')
    for (let i = 0; i < ids.length; i++) {
      if (ids[i] === '') {
        continue
      }
      const def: BadgeDef | undefined = AchievementEngine.getById(ids[i])
      if (def !== undefined) {
        this.newBadges.push(def)
      }
    }

    // AI 大模型深度分析：专属恢复建议 + 下一步目标 + 个性化激励文案
    const stats = StoreService.getInstance().getUserStats()
    const env: EnvSnapshot = EnvService.getInstance().getSnapshot()
    this.report = AiCoach.analyzeFinish(this.record, stats, env)
    this.motivateText = AiCoach.motivate(this.record, stats)

    // 分布式成就与排行榜：已广播到所有组网设备
    const synced: boolean = DeviceFlowService.getInstance().broadcastAchievements()
    const onlineCount: number = DeviceFlowService.getInstance().onlineCount() + 1
    this.syncNote = synced || onlineCount > 1
      ? `成就与排行已通过分布式软总线同步至 ${onlineCount} 台设备（手机 / 平板 / 手表）`
      : '当前仅本机在线，恢复组网后成就将自动同步到平板与手表'
    this.loaded = true
  }

  @Builder
  badgeRow(b: BadgeDef) {
    Row({ space: 12 }) {
      Text(b.emoji)
        .fontSize(30)
      Column({ space: 3 }) {
        Text(b.name)
          .fontSize(15)
          .fontColor(Theme.ORANGE)
          .fontWeight(FontWeight.Bold)
        Text(b.desc)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('rgba(245,166,35,0.10)')
    .borderRadius(14)
  }

  build() {
    Column({ space: 14 }) {
      Text('🎉 运动完成')
        .fontSize(24)
        .fontColor(Theme.GREEN)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 24 })

      if (this.loaded) {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 12 }) {
              Row() {
                Text(`${FormatUtils.dateKeyOf(this.record.startTs)} ${FormatUtils.timeOf(this.record.startTs)}`)
                  .fontSize(12)
                  .fontColor(Theme.TEXT_SUB)
                Blank()
                Text(FormatUtils.sportNameOf(this.record.type))
                  .fontSize(12)
                  .fontColor(Theme.GREEN)
              }
              .width('100%')

              Text(`${FormatUtils.kmOf(this.record.distanceM)} 公里`)
                .fontSize(44)
                .fontColor(Theme.TEXT_MAIN)
                .fontWeight(FontWeight.Bold)

              Row() {
                Column({ space: 4 }) {
                  Text(FormatUtils.durationOf(this.record.durationS))
                    .fontSize(16)
                    .fontColor(Theme.TEXT_MAIN)
                    .fontWeight(FontWeight.Medium)
                  Text('时长')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
                Column({ space: 4 }) {
                  Text(FormatUtils.paceOf(this.record.paceSecPerKm))
                    .fontSize(16)
                    .fontColor(Theme.TEXT_MAIN)
                    .fontWeight(FontWeight.Medium)
                  Text('平均配速')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
                Column({ space: 4 }) {
                  Text(`${this.record.calorie}`)
                    .fontSize(16)
                    .fontColor(Theme.TEXT_MAIN)
                    .fontWeight(FontWeight.Medium)
                  Text('千卡')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
                Column({ space: 4 }) {
                  Text(`${this.record.steps}`)
                    .fontSize(16)
                    .fontColor(Theme.TEXT_MAIN)
                    .fontWeight(FontWeight.Medium)
                  Text('步数')
                    .fontSize(11)
                    .fontColor(Theme.TEXT_SUB)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }
              .width('100%')

              Text(this.record.gpsPointText())
                .fontSize(11)
                .fontColor(Theme.TEXT_SUB)
            }
            .padding(18)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
            .width('100%')

            // AI 深度分析报告
            Column({ space: 10 }) {
              Row() {
                Text('🤖 AI 训练分析报告')
                  .fontSize(15)
                  .fontColor(Theme.TEXT_MAIN)
                  .fontWeight(FontWeight.Bold)
                  .layoutWeight(1)
                Text(`${this.report.score} 分`)
                  .fontSize(18)
                  .fontColor(Theme.GREEN)
                  .fontWeight(FontWeight.Bold)
              }
              .width('100%')

              Text(this.report.title)
                .fontSize(13)
                .fontColor(Theme.PURPLE)
                .fontWeight(FontWeight.Medium)
                .width('100%')

              Text(this.report.summary)
                .fontSize(12)
                .fontColor(Theme.TEXT_MAIN)
                .width('100%')
                .lineHeight(19)

              Text('恢复建议')
                .fontSize(12)
                .fontColor(Theme.BLUE)
                .fontWeight(FontWeight.Medium)
                .width('100%')
              ForEach(this.report.recoveryTips, (tip: string, idx: number) => {
                Text(`${idx + 1}. ${tip}`)
                  .fontSize(12)
                  .fontColor(Theme.TEXT_SUB)
                  .width('100%')
                  .lineHeight(18)
              }, (tip: string) => tip)

              Row({ space: 8 }) {
                Text('🎯 下一步目标')
                  .fontSize(12)
                  .fontColor(Theme.ORANGE)
                  .fontWeight(FontWeight.Medium)
                Text(this.report.nextGoal)
                  .fontSize(12)
                  .fontColor(Theme.TEXT_MAIN)
                  .layoutWeight(1)
              }
              .width('100%')

              Text(this.motivateText)
                .fontSize(13)
                .fontColor(Theme.GREEN)
                .width('100%')
                .lineHeight(20)
                .padding({ top: 6 })
                .backgroundColor('rgba(52,199,123,0.08)')
                .borderRadius(10)
            }
            .padding(16)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
            .width('100%')

            if (this.newBadges.length > 0) {
              Text('🏅 解锁新成就')
                .fontSize(15)
                .fontColor(Theme.TEXT_MAIN)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              ForEach(this.newBadges, (b: BadgeDef) => {
                this.badgeRow(b)
              }, (b: BadgeDef) => b.id)
            } else {
              Text('本次未解锁新勋章，继续加油')
                .fontSize(12)
                .fontColor(Theme.TEXT_SUB)
            }

            Text(`🤝 里程已同步进你加入的组队挑战\n📡 ${this.syncNote}`)
              .fontSize(12)
              .fontColor(Theme.BLUE)
              .margin({ top: 4, bottom: 8 })

            Button('🎴 一键生成分享卡片')
              .width('100%')
              .height(50)
              .backgroundColor(Theme.PURPLE)
              .fontColor('#FFFFFF')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(Theme.RADIUS_BTN)
              .margin({ bottom: 20 })
              .onClick(() => {
                const p: ShareCardParams = { recordId: this.record.id }
                this.getUIContext().getRouter().pushUrl({ url: 'pages/ShareCardPage', params: p })
              })
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
      }

      Button('完成')
        .width('100%')
        .height(52)
        .backgroundColor(Theme.GREEN)
        .fontColor('#06281A')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
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
