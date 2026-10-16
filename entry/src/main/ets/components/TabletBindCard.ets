/**
 * 脉动光谷 - 平板"我的"页设备绑定卡
 * 绑定流程：扫码/搜索发现手机 → 确认绑定 → 分布式 KV 端端同步账号与运动数据
 * 演示兜底：单设备环境下降级为模拟扫码，绑定状态经 Preferences 持久化
 */
import { BindState, DeviceBindService } from '../service/DeviceBindService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'

@Component
export struct TabletBindCard {
  @State bindState: BindState = BindState.UNBOUND
  @State deviceName: string = ''
  @State lastSyncTs: number = 0
  @State boundAt: number = 0

  aboutToAppear(): void {
    this.refresh()
    DeviceBindService.getInstance().setListener((): void => {
      this.refresh()
    })
  }

  aboutToDisappear(): void {
    DeviceBindService.getInstance().setListener((): void => {
    })
  }

  private refresh(): void {
    const svc: DeviceBindService = DeviceBindService.getInstance()
    this.bindState = svc.getState()
    this.deviceName = svc.getDeviceName()
    this.lastSyncTs = svc.getLastSyncTs()
    this.boundAt = svc.getBoundAt()
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (e) {
      console.error('[TabletBindCard] showToast failed')
    }
  }

  private doSync(): void {
    const count: number = DeviceBindService.getInstance().syncNow()
    if (count > 0) {
      this.toast(`已与 ${count} 台可信设备端端同步（分布式软总线）✅`)
    } else {
      this.toast('组网内暂无其他可信设备，已保持本地数据一致（演示环境）📡')
    }
  }

  private doUnbind(): void {
    DeviceBindService.getInstance().unbind()
    this.toast('已解除绑定')
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('🔗 设备绑定')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('分布式软总线 · 华为账号可信组网')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')

      if (this.bindState === BindState.UNBOUND) {
        Row({ space: 14 }) {
          Text('📱')
            .fontSize(34)
          Column({ space: 4 }) {
            Text('尚未绑定手机')
              .fontSize(14)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Medium)
            Text('绑定后平板与手机共享账号、运动记录、动态与成就，大屏数据实时同步')
              .fontSize(11)
              .fontColor(Theme.TEXT_SUB)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('扫码绑定手机')
            .height(36)
            .fontSize(12)
            .backgroundColor(Theme.BLUE)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .borderRadius(18)
            .onClick(() => {
              DeviceBindService.getInstance().startScan()
            })
        }
        .width('100%')
      } else if (this.bindState === BindState.SCANNING) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(Theme.BLUE)
          Text('正在搜索附近可绑定的手机…（扫码 / 碰一碰）')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      } else {
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Text('📱')
              .fontSize(30)
            Column({ space: 3 }) {
              Text(`${this.deviceName} · ${DeviceFlowService.getInstance().isDeviceOnline('dev_phone') ? '🟢 在线' : '⚪ 离线'}`)
                .fontSize(14)
                .fontColor(Theme.TEXT_MAIN)
                .fontWeight(FontWeight.Bold)
              Text(this.boundAt > 0 ? `绑定于 ${FormatUtils.dateKeyOf(this.boundAt)} ${FormatUtils.timeOf(this.boundAt)}` : '')
                .fontSize(11)
                .fontColor(Theme.TEXT_SUB)
              Text(this.lastSyncTs > 0 ? `上次同步 ${FormatUtils.dateKeyOf(this.lastSyncTs)} ${FormatUtils.timeOf(this.lastSyncTs)}` : '尚未同步')
                .fontSize(11)
                .fontColor(Theme.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')

          Row({ space: 10 }) {
            Button('🔄 立即同步')
              .layoutWeight(1)
              .height(38)
              .fontSize(13)
              .backgroundColor(Theme.GREEN)
              .fontColor('#06281A')
              .fontWeight(FontWeight.Medium)
              .borderRadius(19)
              .onClick(() => {
                this.doSync()
              })
            Button('解除绑定')
              .layoutWeight(1)
              .height(38)
              .fontSize(13)
              .backgroundColor(Theme.CARD_BG)
              .fontColor(Theme.TEXT_SUB)
              .borderRadius(19)
              .onClick(() => {
                this.doUnbind()
              })
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }
}
