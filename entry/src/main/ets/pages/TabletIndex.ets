/**
 * 脉动光谷 - 平板端主页面（三 Tab：看板 / 动态 / 我的）
 * 看板：赛事驾驶舱大屏；动态：好友动态流（与手机端一致）
 * 我的：设备绑定卡 + 账号/画像/隐私（与手机端一致）
 */
import { abilityAccessCtrl, Permissions, PermissionRequestResult, common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Theme } from '../common/Theme'
import { StoreService } from '../service/StoreService'
import { HealthService } from '../service/HealthService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { DeviceBindService } from '../service/DeviceBindService'
import { TabletDashboard } from '../components/TabletDashboard'
import { CommunityTab } from '../components/CommunityTab'
import { ProfileTab } from '../components/ProfileTab'
import { TabletBindCard } from '../components/TabletBindCard'

interface TabletTabMeta {
  label: string
  icon: string
}

const TABLET_TABS: TabletTabMeta[] = [
  { label: '看板', icon: '📊' },
  { label: '动态', icon: '💬' },
  { label: '我的', icon: '👤' }
]

@Entry
@Component
struct TabletIndex {
  @State currentTab: number = 0

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    DeviceBindService.getInstance().init(context)
    this.requestCorePermissions()
    // 纯软件演示：启动即拉起虚拟手表 + 手机/平板组网在线
    DeviceFlowService.getInstance().startAllDevices()
    HealthService.getInstance().startWatch()
  }

  private async requestCorePermissions(): Promise<void> {
    const perms: Array<Permissions> = [
      'ohos.permission.LOCATION',
      'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.ACTIVITY_MOTION',
      'ohos.permission.DISTRIBUTED_DATASYNC'
    ]
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      const atManager = abilityAccessCtrl.createAtManager()
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(context, perms)
      console.info(`[TabletIndex] permission granted: ${JSON.stringify(result.authResults)}`)
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[TabletIndex] permission request failed: ${err.code}`)
    }
  }

  @Builder
  tabBarBuilder(meta: TabletTabMeta, index: number) {
    Column({ space: 3 }) {
      Text(meta.icon)
        .fontSize(22)
      Text(meta.label)
        .fontSize(11)
        .fontColor(this.currentTab === index ? Theme.GREEN : Theme.TEXT_SUB)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index
    })
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          TabletDashboard()
        }
        .tabBar(this.tabBarBuilder(TABLET_TABS[0], 0))

        TabContent() {
          CommunityTab()
        }
        .tabBar(this.tabBarBuilder(TABLET_TABS[1], 1))

        TabContent() {
          Column() {
            TabletBindCard()
            ProfileTab()
              .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
        }
        .tabBar(this.tabBarBuilder(TABLET_TABS[2], 2))
      }
      .barHeight(60)
      .onChange((index: number) => {
        this.currentTab = index
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
