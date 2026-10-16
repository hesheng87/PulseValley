/**
 * 脉动光谷 - 运动页（Tab2）
 * 运动类型选择 + 开始入口 + 最近记录 + 本周目标
 */
import { SportType, SportRecord } from '../common/Types'
import { StoreService } from '../service/StoreService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'
import { RunningParams } from '../model/RouteParams'

@Component
export struct SportTab {
  @State selectedType: SportType = SportType.RUN
  @State records: SportRecord[] = []

  aboutToAppear(): void {
    this.records = StoreService.getInstance().getRecords()
  }

  private goRunning(): void {
    const p: RunningParams = { type: this.selectedType }
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/RunningPage', params: p })
    } catch (e) {
      console.error('[SportTab] goRunning failed')
    }
  }

  @Builder
  typeCard(name: string, emoji: string, type: SportType) {
    Column({ space: 8 }) {
      Text(emoji)
        .fontSize(30)
      Text(name)
        .fontSize(13)
        .fontColor(this.selectedType === type ? Theme.GREEN : Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(this.selectedType === type ? 'rgba(52,199,123,0.16)' : Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .border({
      width: 1,
      color: this.selectedType === type ? Theme.GREEN : Theme.CARD_STROKE
    })
    .onClick(() => {
      this.selectedType = type
    })
  }

  @Builder
  recordRow(record: SportRecord) {
    Row({ space: 12 }) {
      Column() {
        Text(FormatUtils.sportNameOf(record.type))
          .fontSize(14)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Medium)
        Text(`${FormatUtils.dateKeyOf(record.startTs)} ${FormatUtils.timeOf(record.startTs)}`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Column({ space: 2 }) {
        Text(`${FormatUtils.kmOf(record.distanceM)} km`)
          .fontSize(15)
          .fontColor(Theme.GREEN)
          .fontWeight(FontWeight.Bold)
        Text(`${FormatUtils.paceOf(record.paceSecPerKm)} /km · ${record.calorie} kcal`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('开始运动')
          .fontSize(22)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Row({ space: 10 }) {
          this.typeCard('跑步', '🏃', SportType.RUN)
          this.typeCard('骑行', '🚴', SportType.RIDE)
          this.typeCard('健走', '🚶', SportType.WALK)
        }
        .width('100%')

        Column({ space: 6 }) {
          Text('开启后手机与手表自动组网，运动数据毫秒级互同步')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
          Text('无 GPS 信号时自动切换步数估算模式，记录不中断')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Button(`开始${FormatUtils.sportNameOf(this.selectedType)}`)
          .width('100%')
          .height(54)
          .backgroundColor(Theme.GREEN)
          .fontColor('#06281A')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .borderRadius(Theme.RADIUS_BTN)
          .onClick(() => {
            this.goRunning()
          })

        // 健身房模块入口
        Row({ space: 12 }) {
          Text('🏋️')
            .fontSize(30)
          Column({ space: 3 }) {
            Text('健身房训练')
              .fontSize(14)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Text('AI 今日计划 · 组数/重量记录 · 组间休息计时 · 手表心率同步')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('›')
            .fontSize(18)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/GymPage' })
        })

        // 多设备演示厅入口
        Row({ space: 12 }) {
          Text('📡')
            .fontSize(30)
          Column({ space: 3 }) {
            Text('多设备演示厅')
              .fontSize(14)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Text('手机 + 手表 + 平板同时启动 · 分布式软总线毫秒级同步')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('›')
            .fontSize(18)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/DeviceSimPage' })
        })

        Row() {
          Text('最近记录')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(`共 ${this.records.length} 次`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')

        if (this.records.length === 0) {
          Text('还没有运动记录，去完成第一次打卡吧')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .padding({ top: 20, bottom: 20 })
        }
        ForEach(this.records, (record: SportRecord) => {
          this.recordRow(record)
        }, (record: SportRecord) => record.id)
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
