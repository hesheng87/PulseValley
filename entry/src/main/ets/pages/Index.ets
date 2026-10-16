/**
 * 脉动光谷 - 主页面（Tab 框架）
 * 首页 / 运动 / 挑战 / 动态 / 我的（对齐需求文档 6.1 五 Tab 结构）
 * 启动时统一申请运动所需权限（定位/传感器/分布式同步）
 */
import { abilityAccessCtrl, Permissions, PermissionRequestResult, common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Theme } from '../common/Theme'
import { StoreService } from '../service/StoreService'
import { HealthService } from '../service/HealthService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { HomeTab } from '../components/HomeTab'
import { SportTab } from '../components/SportTab'
import { ChallengeTab } from '../components/ChallengeTab'
import { CommunityTab } from '../components/CommunityTab'
import { ProfileTab } from '../components/ProfileTab'

interface TabMeta {
  label: string
  icon: string
}

const TABS: TabMeta[] = [
  { label: '首页', icon: '🏠' },
  { label: '运动', icon: '🏃' },
  { label: '挑战', icon: '🤝' },
  { label: '动态', icon: '💬' },
  { label: '我的', icon: '👤' }
]

@Entry
@Component
struct Index {
  @State currentTab: number = 0

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    this.requestCorePermissions()
    // 纯软件演示：启动即拉起虚拟手表（实时健康采集）+ 平板/手表组网在线
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
      console.info(`[Index] permission granted: ${JSON.stringify(result.authResults)}`)
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[Index] permission request failed: ${err.code}`)
    }
  }

  @Builder
  tabBarBuilder(meta: TabMeta, index: number) {
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
          HomeTab()
        }
        .tabBar(this.tabBarBuilder(TABS[0], 0))

        TabContent() {
          SportTab()
        }
        .tabBar(this.tabBarBuilder(TABS[1], 1))

        TabContent() {
          ChallengeTab()
        }
        .tabBar(this.tabBarBuilder(TABS[2], 2))

        TabContent() {
          CommunityTab()
        }
        .tabBar(this.tabBarBuilder(TABS[3], 3))

        TabContent() {
          ProfileTab()
        }
        .tabBar(this.tabBarBuilder(TABS[4], 4))
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
