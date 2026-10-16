/**
 * 脉动光谷 - 我的页（Tab5）
 * 账号（注册/登录/退出，手机号或华为账号）+ 头像/个性签名 + 身体数据（体重/体脂率）
 * + 累计统计 + 手表实时健康 + 华为运动健康同步 + 校园绑定 + 学期报告 + 隐私安全
 */
import { AiWeekPlan, AiWeekPlanDay, CampusInfo, GymMove, HealthSnapshot, HealthSyncState, UserStats } from '../common/Types'
import { StoreService } from '../service/StoreService'
import { HealthService } from '../service/HealthService'
import { HealthSyncService } from '../service/HealthSyncService'
import { CampusService } from '../service/CampusService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { UserService, BodyMetric, RegisterType, UserAccount } from '../service/UserService'
import { AccountSyncService } from '../service/AccountSyncService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'
import { common } from '@kit.AbilityKit'

const AVATAR_POOL: string[] = ['🏃', '🧘', '🚴', '🎧', '💪', '🤸', '🏊', '⚽', '🎮', '📷']

/** AI 本周训练计划（跑步主题，按当前日期高亮今天） */
interface PlanDay {
  dayLabel: string
  title: string
  desc: string
  /** 0=低强度 1=中强度 2=高强度 3=休息日 */
  intensity: number
}

const WEEK_PLAN: PlanDay[] = [
  { dayLabel: '周一', title: '操场轻松跑', desc: '4 km · 配速 6\'40" · 唤醒身体', intensity: 0 },
  { dayLabel: '周二', title: '间歇训练', desc: '800m × 4 组 · 组间慢跑 400m', intensity: 2 },
  { dayLabel: '周三', title: '恢复慢跑', desc: '3 km · 保持心率 140 以下', intensity: 0 },
  { dayLabel: '周四', title: '汤逊湖环线', desc: '6 km · 中等配速 · 注意补水', intensity: 1 },
  { dayLabel: '周五', title: '核心力量', desc: '平板支撑 + 卷腹 + 深蹲各 3 组', intensity: 1 },
  { dayLabel: '周六', title: '长距离拉练', desc: '8-10 km · 按体感分配配速', intensity: 2 },
  { dayLabel: '周日', title: '休息拉伸', desc: '泡沫轴放松 · 补足睡眠', intensity: 3 }
]

@Component
export struct ProfileTab {
  @State stats: UserStats = new UserStats()
  @State fuzzEnabled: boolean = true
  @State nightGuardEnabled: boolean = true
  @State health: HealthSnapshot = new HealthSnapshot()
  @State watchOn: boolean = false
  @State syncState: HealthSyncState = new HealthSyncState()
  @State campusInfo: CampusInfo = new CampusInfo()
  // AI 对话定制的一周训练计划（未定制时为 undefined，展示默认模板）
  @State aiPlan: AiWeekPlan | undefined = undefined
  // 账号状态
  @State accExists: boolean = false
  @State accLoggedIn: boolean = false
  @State accNickname: string = ''
  @State accAvatar: string = '🏃'
  @State accSignature: string = ''
  @State accIsHuawei: boolean = false
  // 面板开关
  @State showAuthPanel: boolean = false
  @State showAvatarPanel: boolean = false
  @State showSignPanel: boolean = false
  @State showBodyPanel: boolean = false
  // 输入框
  @State authTab: number = 0
  @State authMode: number = 0 // 0=登录 1=注册新账号
  @State localAccounts: UserAccount[] = []
  @State nicknameInput: string = ''
  @State phoneInput: string = ''
  @State codeInput: string = ''
  @State signInput: string = ''
  @State weightInput: string = ''
  @State fatInput: string = ''
  // 身体数据
  @State metrics: BodyMetric[] = []
  @State weightDelta: number = 0
  // 跨设备同步
  @State deviceSyncTs: number = 0
  @State deviceSyncCount: number = 0
  @State deviceMergedCount: number = 0
  private tickTimer: number = -1

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    UserService.getInstance().init(context)
    AccountSyncService.getInstance().init(context,
      (json: string): boolean => UserService.getInstance().applyRemoteAccountJson(json),
      (): void => {
        this.refreshAccount()
        this.refreshMetrics()
        this.stats = StoreService.getInstance().getUserStats()
        this.toast('已收到其他设备同步的账号数据 📲')
      })
    this.refreshAccount()
    this.refreshMetrics()
    this.refreshAiPlan()
    this.stats = StoreService.getInstance().getUserStats()
    this.syncState = HealthSyncService.getState()
    this.campusInfo = CampusService.getInfo()
    this.watchOn = HealthService.getInstance().isWatchRunning()
    this.health = HealthService.getInstance().getSnapshot()
    this.tickTimer = setInterval((): void => {
      this.health = HealthService.getInstance().getSnapshot()
      this.watchOn = HealthService.getInstance().isWatchRunning()
      // 从 AI 对话页返回后，自动刷新「AI 本周训练计划」卡片
      this.refreshAiPlan()
    }, 2000)
  }

  aboutToDisappear(): void {
    if (this.tickTimer >= 0) {
      clearInterval(this.tickTimer)
      this.tickTimer = -1
    }
  }

  private refreshAccount(): void {
    const svc = UserService.getInstance()
    const acc = svc.getAccount()
    this.localAccounts = svc.getLocalAccounts().slice()
    this.accExists = svc.hasAccount()
    this.accLoggedIn = svc.isLoggedIn()
    this.accNickname = acc.nickname
    this.accAvatar = acc.avatar
    this.accSignature = acc.signature
    this.accIsHuawei = acc.registerType === RegisterType.HUAWEI
    this.authTab = 0
    this.authMode = this.accExists ? 0 : 1
  }

  private refreshMetrics(): void {
    const svc = UserService.getInstance()
    this.metrics = svc.getBodyMetrics().slice()
    this.weightDelta = svc.weightDeltaKg()
  }

  /** 拉取 AI 对话定制的本周训练计划（仅在计划更新时刷新状态，避免重渲染） */
  private refreshAiPlan(): void {
    const plan: AiWeekPlan | undefined = StoreService.getInstance().getAiWeekPlan()
    if (plan === undefined) {
      if (this.aiPlan !== undefined) {
        this.aiPlan = undefined
      }
      return
    }
    if (this.aiPlan === undefined || this.aiPlan.generatedAt !== plan.generatedAt) {
      this.aiPlan = plan
    }
  }

  /** 进入 AI 对话，定制一周训练计划 */
  private openAiChat(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/WeekPlanChatPage' })
    } catch (e) {
      console.error('[ProfileTab] openAiChat failed')
    }
  }

  /** AI 计划的天列表（供 ForEach 渲染） */
  private aiDays(): AiWeekPlanDay[] {
    return this.aiPlan !== undefined ? this.aiPlan.days : []
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (e) {
      console.error('[ProfileTab] showToast failed')
    }
  }

  /** 打开登录/注册面板，并从组网设备拉取账号（平板上也能登录手机上注册的账号） */
  private openAuthPanel(): void {
    this.showAuthPanel = true
    UserService.getInstance().syncNow()
  }

  /** 获取验证码（演示：固定 123456） */
  private sendVerifyCode(): void {
    if (this.authMode === 1 && this.authTab === 0 && this.nicknameInput.trim() === '') {
      this.toast('请先填写昵称')
      return
    }
    this.toast('验证码已发送（演示验证码 123456）')
  }

  private submitAuth(): void {
    const svc = UserService.getInstance()
    let err: string = ''
    const isRegister: boolean = this.authMode === 1
    if (isRegister) {
      // 注册模式：同一设备可注册多个账号
      if (this.authTab === 0) {
        err = svc.registerWithPhone(this.nicknameInput, this.phoneInput, this.codeInput)
      } else {
        err = svc.registerWithHuawei()
      }
    } else {
      // 登录模式：本机任意已注册账号
      if (this.authTab === 0) {
        err = svc.loginByPhone(this.phoneInput, this.codeInput)
      } else {
        err = svc.loginByHuawei()
      }
    }
    if (err !== '') {
      this.toast(err)
      return
    }
    this.showAuthPanel = false
    this.phoneInput = ''
    this.codeInput = ''
    this.nicknameInput = ''
    this.refreshAccount()
    this.refreshMetrics()
    this.toast(isRegister ? '注册成功并已自动登录 🎉' : '登录成功，欢迎回来 👋')
    // 登录后拉取其他设备上该账号的最新数据
    UserService.getInstance().syncNow()
  }

  /** 快选本机已注册账号直接登录 */
  private quickLogin(acc: UserAccount): void {
    const err: string = UserService.getInstance().quickLogin(acc.uid)
    if (err !== '') {
      this.toast(err)
      return
    }
    this.showAuthPanel = false
    this.phoneInput = ''
    this.codeInput = ''
    this.nicknameInput = ''
    this.refreshAccount()
    this.refreshMetrics()
    this.toast(`已切换到 ${acc.nickname} 👋`)
    UserService.getInstance().syncNow()
  }

  private doLogout(): void {
    UserService.getInstance().logout()
    this.refreshAccount()
    this.refreshMetrics()
    this.toast('已退出登录，可用本机任意账号再次登录')
  }

  private pickAvatar(emoji: string): void {
    UserService.getInstance().updateAvatar(emoji)
    this.showAvatarPanel = false
    this.refreshAccount()
    this.toast('头像已更换')
  }

  private saveSignature(): void {
    const text: string = this.signInput.trim()
    if (text === '') {
      this.toast('个性签名不能为空')
      return
    }
    UserService.getInstance().updateSignature(text)
    this.showSignPanel = false
    this.refreshAccount()
    this.toast('个性签名已保存 ✍️')
  }

  private saveBodyMetric(): void {
    if (!this.accLoggedIn) {
      this.showBodyPanel = false
      this.openAuthPanel()
      return
    }
    const weight: number = Number(this.weightInput)
    const fat: number = Number(this.fatInput)
    const err: string = UserService.getInstance().addBodyMetric(weight, fat)
    if (err !== '') {
      this.toast(err)
      return
    }
    this.showBodyPanel = false
    this.weightInput = ''
    this.fatInput = ''
    this.refreshMetrics()
    this.toast('身体数据已记录 💪')
  }

  /** 启停虚拟手表（实时健康采集） */
  private toggleWatch(): void {
    if (HealthService.getInstance().isWatchRunning()) {
      HealthService.getInstance().stopWatch()
      this.toast('手表已停止采集 ⌚')
    } else {
      HealthService.getInstance().startWatch()
      this.toast('手表已连接，实时健康采集中 ⌚')
    }
    this.watchOn = HealthService.getInstance().isWatchRunning()
  }

  private doHealthSync(): void {
    this.syncState = HealthSyncService.syncNow()
    this.toast('已与华为运动健康完成同步 🔄')
  }

  /** 跨设备端端同步：推送本端账号数据并拉取组网设备数据 */
  private doDeviceSync(): void {
    const svc = UserService.getInstance()
    const deviceCount: number = svc.syncNow()
    const sync = AccountSyncService.getInstance()
    this.deviceSyncTs = sync.getLastSyncTs()
    this.deviceSyncCount = sync.getLastSyncDeviceCount()
    this.deviceMergedCount = sync.getRemoteMergedCount()
    if (!sync.isReady()) {
      this.toast(sync.getLastError() !== '' ? sync.getLastError() : '分布式数据库尚未就绪，请稍后重试')
      return
    }
    if (deviceCount === 0) {
      this.toast(sync.getLastError() !== ''
        ? sync.getLastError()
        : '组网内暂无其他设备（两台设备需登录同一华为账号）')
      return
    }
    this.toast(`已与 ${deviceCount} 台设备完成端端同步 📲`)
  }

  @Builder
  statCell(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontColor(Theme.GREEN)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  settingRow(title: string, desc: string, isOn: boolean) {
    Row() {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontColor(Theme.TEXT_MAIN)
        Text(desc)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(Theme.GREEN)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  /** 账号头部：头像（点击换头像）/ 昵称 / 个性签名 / 登录入口 */
  @Builder
  accountHeader() {
    Row({ space: 14 }) {
      Text(this.accAvatar)
        .fontSize(44)
        .width(64)
        .height(64)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.accLoggedIn ? 'rgba(52,199,123,0.15)' : Theme.CARD_BG)
        .borderRadius(32)
        .onClick(() => {
          if (this.accLoggedIn) {
            this.signInput = this.accSignature
            this.showAvatarPanel = true
          } else {
            this.openAuthPanel()
          }
        })

      Column({ space: 4 }) {
        if (this.accLoggedIn) {
          Text(this.accNickname)
            .fontSize(20)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text(this.accSignature !== '' ? this.accSignature : '设置个性签名')
            .fontSize(12)
            .fontColor(this.accSignature !== '' ? Theme.TEXT_SUB : Theme.BLUE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.signInput = this.accSignature
              this.showSignPanel = true
            })
          Text(`${this.accIsHuawei ? '💙 华为账号' : '📱 手机号注册'} · Lv.${this.stats.level} · 积分 ${this.stats.totalPoints}`)
            .fontSize(11)
            .fontColor(Theme.ORANGE)
        } else {
          Text(this.accExists ? '点击登录' : '注册 / 登录')
            .fontSize(20)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text(this.accExists ? '欢迎回来，登录后继续运动之旅' : '支持手机号或华为账号注册')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
          Text(`Lv.${this.stats.level} · 运动积分 ${this.stats.totalPoints}`)
            .fontSize(11)
            .fontColor(Theme.ORANGE)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .onClick(() => {
      if (!this.accLoggedIn) {
        this.openAuthPanel()
      }
    })
  }

  /** 身体数据卡：体重 / 体脂率 / 趋势 */
  @Builder
  bodyMetricCard() {
    Column({ space: 10 }) {
      Row() {
        Text('💪 身体数据')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('记录一次')
          .fontSize(12)
          .height(32)
          .backgroundColor(Theme.GREEN)
          .borderRadius(16)
          .onClick(() => {
            if (!this.accLoggedIn) {
              this.openAuthPanel()
              this.toast('请先登录后记录身体数据')
              return
            }
            this.showBodyPanel = true
          })
      }
      .width('100%')

      if (this.metrics.length > 0) {
        Row() {
          Column({ space: 3 }) {
            Text(`${this.metrics[0].weightKg}`)
              .fontSize(22)
              .fontColor(Theme.GREEN)
              .fontWeight(FontWeight.Bold)
            Text('体重 kg')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          Column({ space: 3 }) {
            Text(`${this.metrics[0].bodyFatPct}`)
              .fontSize(22)
              .fontColor(Theme.BLUE)
              .fontWeight(FontWeight.Bold)
            Text('体脂率 %')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          Column({ space: 3 }) {
            Text(this.weightDelta > 0 ? `+${this.weightDelta}` : `${this.weightDelta}`)
              .fontSize(22)
              .fontColor(this.weightDelta > 0 ? Theme.ORANGE : Theme.GREEN)
              .fontWeight(FontWeight.Bold)
            Text('较上次 kg')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          Column({ space: 3 }) {
            Text(`${this.metrics.length}`)
              .fontSize(22)
              .fontColor(Theme.PURPLE)
              .fontWeight(FontWeight.Bold)
            Text('记录条数')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')

        ForEach(this.metrics.slice(0, 3), (m: BodyMetric) => {
          Row({ space: 8 }) {
            Text(`📅 ${FormatUtils.dateKeyOf(m.ts)} ${FormatUtils.timeOf(m.ts)}`)
              .fontSize(11)
              .fontColor(Theme.TEXT_SUB)
              .layoutWeight(1)
            Text(`${m.weightKg} kg · 体脂 ${m.bodyFatPct}%`)
              .fontSize(11)
              .fontColor(Theme.TEXT_MAIN)
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
        }, (m: BodyMetric) => `${m.ts}`)
      } else {
        Text('记录体重和体脂率，追踪身体变化趋势（登录后可用）')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
      }
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  authTabLabel(index: number, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.authTab === index ? Theme.GREEN : Theme.TEXT_SUB)
      .fontWeight(this.authTab === index ? FontWeight.Bold : FontWeight.Normal)
      .padding({ top: 6, bottom: 6, left: 14, right: 14 })
      .backgroundColor(this.authTab === index ? 'rgba(52,199,123,0.12)' : 'transparent')
      .borderRadius(14)
      .onClick(() => {
        this.authTab = index
      })
  }

  /** 注册 / 登录面板（手机号 或 华为账号，支持本机多账号） */
  @Builder
  authPanel() {
    Column({ space: 12 }) {
      Row() {
        Text(this.authMode === 1 ? '创建账号' : '欢迎回来')
          .fontSize(18)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('✕')
          .fontSize(16)
          .fontColor(Theme.TEXT_SUB)
          .onClick(() => {
            this.showAuthPanel = false
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        this.authTabLabel(0, this.authMode === 1 ? '📱 手机号注册' : '📱 手机号登录')
        this.authTabLabel(1, this.authMode === 1 ? '💙 华为账号注册' : '💙 华为账号登录')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      if (this.authMode === 0 && this.localAccounts.length > 0) {
        Column({ space: 6 }) {
          Text('本机已注册账号（点击快选登录）')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(this.localAccounts, (acc: UserAccount) => {
              Row({ space: 5 }) {
                Text(acc.avatar)
                  .fontSize(15)
                Text(acc.nickname)
                  .fontSize(11)
                  .fontColor(Theme.TEXT_MAIN)
                  .maxLines(1)
              }
              .padding({ top: 5, bottom: 5, left: 10, right: 10 })
              .margin(3)
              .backgroundColor('rgba(255,255,255,0.10)')
              .borderRadius(14)
              .border({ width: 1, color: Theme.CARD_STROKE })
              .onClick(() => {
                this.quickLogin(acc)
              })
            }, (acc: UserAccount) => acc.uid)
          }
          .width('100%')
        }
        .width('100%')
      }

      if (this.authTab === 0) {
        if (this.authMode === 1) {
          TextInput({ placeholder: '昵称（2-12 字）', text: this.nicknameInput })
            .height(42)
            .fontSize(13)
            .backgroundColor('rgba(255,255,255,0.10)')
            .onChange((value: string) => {
              this.nicknameInput = value
            })
        }
        TextInput({ placeholder: '手机号', text: this.phoneInput })
          .height(42)
          .fontSize(13)
          .type(InputType.Number)
          .backgroundColor('rgba(255,255,255,0.10)')
          .onChange((value: string) => {
            this.phoneInput = value
          })
        Row({ space: 8 }) {
          TextInput({ placeholder: '验证码', text: this.codeInput })
            .height(42)
            .fontSize(13)
            .type(InputType.Number)
            .backgroundColor('rgba(255,255,255,0.10)')
            .layoutWeight(1)
            .onChange((value: string) => {
              this.codeInput = value
            })
          Button('获取验证码')
            .height(42)
            .fontSize(12)
            .backgroundColor('rgba(255,255,255,0.15)')
            .fontColor(Theme.TEXT_MAIN)
            .borderRadius(Theme.RADIUS_BTN)
            .onClick(() => {
              this.sendVerifyCode()
            })
        }
        .width('100%')
        Text('纯软件演示：验证码固定为 123456')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        Text(this.authMode === 1
          ? '授权华为账号一键注册（演示模拟 Account Kit），无需手机号与验证码'
          : '使用已注册的华为账号一键授权登录，无需输入密码')
          .fontSize(12)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
      }

      Button(this.authMode === 1
        ? (this.authTab === 0 ? '注册并登录' : '💙 华为账号一键注册')
        : (this.authTab === 0 ? '登录' : '💙 华为账号一键登录'))
        .height(44)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(Theme.GREEN)
        .borderRadius(Theme.RADIUS_BTN)
        .width('100%')
        .onClick(() => {
          this.submitAuth()
        })

      Text(this.authMode === 1 ? '已有账号？直接登录' : '注册新账号 ➕')
        .fontSize(12)
        .fontColor(Theme.BLUE)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 2 })
        .onClick(() => {
          this.authMode = this.authMode === 1 ? 0 : 1
        })
    }
    .width('86%')
    .padding(18)
    .backgroundColor('#1B2440')
    .borderRadius(20)
    .border({ width: 1, color: Theme.CARD_STROKE })
  }

  /** 换头像面板（emoji 头像库） */
  @Builder
  avatarPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('选择头像')
          .fontSize(18)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('✕')
          .fontSize(16)
          .fontColor(Theme.TEXT_SUB)
          .onClick(() => {
            this.showAvatarPanel = false
          })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceAround }) {
        ForEach(AVATAR_POOL, (emoji: string) => {
          Text(emoji)
            .fontSize(30)
            .width(52)
            .height(52)
            .textAlign(TextAlign.Center)
            .margin(6)
            .backgroundColor(emoji === this.accAvatar ? 'rgba(52,199,123,0.25)' : 'rgba(255,255,255,0.07)')
            .borderRadius(26)
            .border({ width: emoji === this.accAvatar ? 2 : 0, color: Theme.GREEN })
            .onClick(() => {
              this.pickAvatar(emoji)
            })
        }, (emoji: string) => `${emoji}_${emoji === this.accAvatar}`)
      }
      .width('100%')

      Text('点击头像立即更换，社区与挑战中同步展示')
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('86%')
    .padding(18)
    .backgroundColor('#1B2440')
    .borderRadius(20)
    .border({ width: 1, color: Theme.CARD_STROKE })
  }

  /** 个性签名编辑面板 */
  @Builder
  signPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('个性签名')
          .fontSize(18)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('✕')
          .fontSize(16)
          .fontColor(Theme.TEXT_SUB)
          .onClick(() => {
            this.showSignPanel = false
          })
      }
      .width('100%')

      TextInput({ placeholder: '写点什么介绍自己吧（30 字以内）', text: this.signInput })
        .height(46)
        .fontSize(13)
        .backgroundColor('rgba(255,255,255,0.10)')
        .onChange((value: string) => {
          this.signInput = value
        })

      Row({ space: 10 }) {
        Button('保存')
          .height(40)
          .fontSize(13)
          .backgroundColor(Theme.GREEN)
          .borderRadius(Theme.RADIUS_BTN)
          .layoutWeight(1)
          .onClick(() => {
            this.saveSignature()
          })
        Button('取消')
          .height(40)
          .fontSize(13)
          .backgroundColor('rgba(255,255,255,0.15)')
          .fontColor(Theme.TEXT_MAIN)
          .borderRadius(Theme.RADIUS_BTN)
          .layoutWeight(1)
          .onClick(() => {
            this.showSignPanel = false
          })
      }
      .width('100%')
    }
    .width('86%')
    .padding(18)
    .backgroundColor('#1B2440')
    .borderRadius(20)
    .border({ width: 1, color: Theme.CARD_STROKE })
  }

  /** 体重 / 体脂率记录面板 */
  @Builder
  bodyPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('记录身体数据')
          .fontSize(18)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('✕')
          .fontSize(16)
          .fontColor(Theme.TEXT_SUB)
          .onClick(() => {
            this.showBodyPanel = false
          })
      }
      .width('100%')

      TextInput({ placeholder: '体重（kg，如 65.5）', text: this.weightInput })
        .height(44)
        .fontSize(13)
        .type(InputType.Number)
        .backgroundColor('rgba(255,255,255,0.10)')
        .onChange((value: string) => {
          this.weightInput = value
        })
      TextInput({ placeholder: '体脂率（%，如 18.5）', text: this.fatInput })
        .height(44)
        .fontSize(13)
        .type(InputType.Number)
        .backgroundColor('rgba(255,255,255,0.10)')
        .onChange((value: string) => {
          this.fatInput = value
        })
      Text('体重范围 20-300 kg · 体脂率范围 2-60%，数据仅保存在本机')
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
        .textAlign(TextAlign.Center)

      Button('保存记录')
        .height(42)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(Theme.GREEN)
        .borderRadius(Theme.RADIUS_BTN)
        .width('100%')
        .onClick(() => {
          this.saveBodyMetric()
        })
    }
    .width('86%')
    .padding(18)
    .backgroundColor('#1B2440')
    .borderRadius(20)
    .border({ width: 1, color: Theme.CARD_STROKE })
  }

  @Builder
  watchHealthCard() {
    Column({ space: 10 }) {
      Row() {
        Text('⌚ 手表实时健康')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.watchOn })
          .selectedColor(Theme.GREEN)
          .onChange((isOn: boolean) => {
            this.toggleWatch()
          })
      }
      .width('100%')

      Row() {
        Column({ space: 3 }) {
          Text(`${this.watchOn && this.health.heartRate > 0 ? this.health.heartRate : '--'}`)
            .fontSize(22)
            .fontColor(Theme.RED)
            .fontWeight(FontWeight.Bold)
          Text('心率')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 3 }) {
          Text(`${this.watchOn ? this.health.spo2 : '--'}`)
            .fontSize(22)
            .fontColor(Theme.BLUE)
            .fontWeight(FontWeight.Bold)
          Text('血氧 %')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 3 }) {
          Text(`${this.watchOn ? this.health.stress : '--'}`)
            .fontSize(22)
            .fontColor(Theme.ORANGE)
            .fontWeight(FontWeight.Bold)
          Text('压力')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        Column({ space: 3 }) {
          Text(`${HealthService.sleepBaseline()}`)
            .fontSize(22)
            .fontColor(Theme.PURPLE)
            .fontWeight(FontWeight.Bold)
          Text('睡眠 h')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      Text(this.watchOn ? '手表采集中：心率/血氧每 2 秒上报，运动时自动同步手机运动页'
        : '打开开关连接手表（纯软件演示），实时记录身体健康状态')
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  healthSyncCard() {
    Column({ space: 10 }) {
      Row() {
        Text('🔄 华为运动健康')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(this.syncState.totalSyncCount > 0 ? '已连接' : '未连接')
          .fontSize(11)
          .fontColor(this.syncState.totalSyncCount > 0 ? Theme.GREEN : Theme.TEXT_SUB)
      }
      .width('100%')

      Text(HealthSyncService.summaryOf(this.syncState))
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
        .lineHeight(17)

      if (this.syncState.lastSyncTs > 0) {
        Text(`上次同步 ${FormatUtils.dateKeyOf(this.syncState.lastSyncTs)} ${FormatUtils.timeOf(this.syncState.lastSyncTs)} · 已同步 ${this.syncState.totalSyncCount} 次`)
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
      }

      Row({ space: 10 }) {
        Button('立即同步')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor(Theme.RED)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
          .borderRadius(20)
          .onClick(() => {
            this.doHealthSync()
          })
        Column({ space: 2 }) {
          Text('自动同步')
            .fontSize(11)
            .fontColor(Theme.TEXT_MAIN)
          Toggle({ type: ToggleType.Switch, isOn: this.syncState.autoSync })
            .selectedColor(Theme.GREEN)
            .onChange((isOn: boolean) => {
              HealthSyncService.setAutoSync(isOn)
              this.syncState = HealthSyncService.getState()
            })
        }
      }
      .width('100%')
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  deviceSyncCard() {
    Column({ space: 10 }) {
      Row() {
        Text('📲 跨设备同步')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(this.deviceSyncCount > 0 ? `${this.deviceSyncCount} 台设备在线` : '无组网设备')
          .fontSize(11)
          .fontColor(this.deviceSyncCount > 0 ? Theme.GREEN : Theme.TEXT_SUB)
      }
      .width('100%')

      Text('手机与平板登录同一华为账号并可信组网后，账号资料与身体数据通过分布式键值数据库自动同步，冲突按修改时间最新保留')
        .fontSize(11)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
        .lineHeight(17)

      if (this.deviceSyncTs > 0) {
        Text(`上次同步 ${FormatUtils.dateKeyOf(this.deviceSyncTs)} ${FormatUtils.timeOf(this.deviceSyncTs)}` +
          `${this.deviceMergedCount > 0 ? ` · 已合并远端数据 ${this.deviceMergedCount} 次` : ''}`)
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
      }

      Button('立即同步')
        .height(40)
        .fontSize(13)
        .backgroundColor(Theme.BLUE)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .borderRadius(20)
        .width('100%')
        .onClick(() => {
          this.doDeviceSync()
        })
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  campusCard() {
    Column({ space: 8 }) {
      Row() {
        Text('🎓 校园绑定')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(CampusService.isBound() ? '已认证' : '未绑定')
          .fontSize(11)
          .fontColor(CampusService.isBound() ? Theme.GREEN : Theme.TEXT_SUB)
      }
      .width('100%')

      if (CampusService.isBound()) {
        Text(`${this.campusInfo.school} · ${this.campusInfo.studentName}（${this.campusInfo.studentId.substring(0, 3)}****）`)
          .fontSize(12)
          .fontColor(Theme.TEXT_MAIN)
          .width('100%')
        Text(`绑定于 ${FormatUtils.dateKeyOf(this.campusInfo.boundTs)} · 校友圈与校园运动榜已解锁（社区页查看）`)
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
      } else {
        Text('前往社区页完成校园绑定，解锁校友圈与校园运动榜')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
      }
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  weeklyPlanCard() {
    Column({ space: 4 }) {
      Row() {
        Text('🤖 AI 本周训练计划')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('✨ 定制 AI 训练')
          .fontSize(11)
          .height(30)
          .padding({ left: 12, right: 12 })
          .backgroundColor(Theme.PURPLE)
          .fontColor('#FFFFFF')
          .borderRadius(15)
          .onClick(() => {
            this.openAiChat()
          })
      }
      .width('100%')
      .margin({ bottom: 6 })

      if (this.aiPlan === undefined) {
        Text('还没有 AI 定制计划 · 点击「定制 AI 训练」，和 AI 教练对话生成专属一周安排')
          .fontSize(10)
          .fontColor(Theme.BLUE)
          .width('100%')
          .margin({ bottom: 6 })
        ForEach(WEEK_PLAN, (d: PlanDay, idx: number) => {
          this.planDayRow(d, idx)
        }, (d: PlanDay) => `${d.dayLabel}_${d.title}`)
      } else {
        Row({ space: 8 }) {
          Text(this.aiPlan.goalWord)
            .fontSize(10)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(Theme.PURPLE)
            .borderRadius(10)
          Text(this.aiPlan.requirement !== '' ? this.aiPlan.requirement : 'AI 智能定制')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`生成于 ${FormatUtils.timeOf(this.aiPlan.generatedAt)}`)
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        .margin({ bottom: 6 })

        ForEach(this.aiDays(), (d: AiWeekPlanDay, idx: number) => {
          this.aiPlanDayRow(d, idx)
        }, (d: AiWeekPlanDay) => `${d.dateKey}_${d.focus}_${d.rest}_${this.aiPlan?.generatedAt}`)
      }

      Text('完成当天训练（健身页打卡）后自动同步 · 连续完成可解锁「七日之约」勋章')
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')
        .margin({ top: 6 })
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** AI 定制计划的单日行（动作明细摘要 + 强度标签，按今天高亮） */
  @Builder
  aiPlanDayRow(d: AiWeekPlanDay, idx: number) {
    Row({ space: 10 }) {
      Text(d.label)
        .fontSize(12)
        .fontColor(isToday(idx) ? Theme.GREEN : Theme.TEXT_SUB)
        .fontWeight(FontWeight.Bold)
        .width(34)
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(d.rest ? '休息恢复' : d.focus)
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(isToday(idx) ? FontWeight.Bold : FontWeight.Medium)
          if (isToday(idx)) {
            Text('今天')
              .fontSize(9)
              .fontColor('#06281A')
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor(Theme.GREEN)
              .borderRadius(8)
          }
        }
        Text(aiDayDescOf(d))
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(intensityLabelOf(aiDayIntensityOf(d)))
        .fontSize(10)
        .fontColor(intensityColorOf(aiDayIntensityOf(d)))
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(intensityBgOf(aiDayIntensityOf(d)))
        .borderRadius(10)
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor(isToday(idx) ? 'rgba(49,208,127,0.10)' : 'rgba(255,255,255,0.03)')
    .borderRadius(12)
    .margin({ bottom: 4 })
  }

  @Builder
  planDayRow(d: PlanDay, idx: number) {
    Row({ space: 10 }) {
      Text(d.dayLabel)
        .fontSize(12)
        .fontColor(isToday(idx) ? Theme.GREEN : Theme.TEXT_SUB)
        .fontWeight(FontWeight.Bold)
        .width(34)
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(d.title)
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(isToday(idx) ? FontWeight.Bold : FontWeight.Medium)
          if (isToday(idx)) {
            Text('今天')
              .fontSize(9)
              .fontColor('#06281A')
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor(Theme.GREEN)
              .borderRadius(8)
          }
        }
        Text(d.desc)
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(intensityLabelOf(d.intensity))
        .fontSize(10)
        .fontColor(intensityColorOf(d.intensity))
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(intensityBgOf(d.intensity))
        .borderRadius(10)
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor(isToday(idx) ? 'rgba(49,208,127,0.10)' : 'rgba(255,255,255,0.03)')
    .borderRadius(12)
    .margin({ bottom: 4 })
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 14 }) {
          this.accountHeader()

          Row() {
            this.statCell(`${this.stats.totalKm}`, '累计公里')
            this.statCell(`${this.stats.totalTimes}`, '运动次数')
            this.statCell(`${this.stats.totalMinutes}`, '运动分钟')
            this.statCell(`${this.stats.streakDays}`, '连续天数')
          }
          .width('100%')
          .padding({ top: 16, bottom: 16 })
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)

          this.bodyMetricCard()

          Button('✨ 定制 AI 训练 · 对话定制一周训练计划')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(Theme.PURPLE)
            .fontColor('#FFFFFF')
            .borderRadius(Theme.RADIUS_BTN)
            .width('100%')
            .onClick(() => {
              this.openAiChat()
            })

          this.weeklyPlanCard()
          this.watchHealthCard()
          this.healthSyncCard()
          this.deviceSyncCard()
          this.campusCard()

          Column({ space: 4 }) {
            Text('🌱 学期运动报告')
              .fontSize(15)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Text(`本学期你共运动 ${this.stats.totalTimes} 次、${this.stats.totalKm} 公里，` +
              `约等于绕操场 ${Math.round(this.stats.totalKm / 0.4)} 圈，` +
              `碳减排约 ${Math.round(this.stats.totalKm * 0.17 * 10) / 10} kg。`)
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
              .lineHeight(18)
          }
          .padding(14)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 6 }) {
            Text('隐私与安全')
              .fontSize(15)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Divider()
              .color(Theme.CARD_STROKE)
            this.settingRow('轨迹脱敏分享', '动态海报起终点 500 米内自动模糊', this.fuzzEnabled)
            Divider()
              .color(Theme.CARD_STROKE)
            this.settingRow('安全夜跑', '实时位置仅好友可见，30 分钟自动过期', this.nightGuardEnabled)
          }
          .padding(14)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)
          .width('100%')

          if (this.accLoggedIn) {
            Button('退出登录')
              .height(42)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.RED)
              .backgroundColor('rgba(232,64,74,0.15)')
              .borderRadius(Theme.RADIUS_BTN)
              .width('100%')
              .onClick(() => {
                this.doLogout()
              })
          }

          Text('脉动光谷 V1.0 · HarmonyOS NEXT 原生应用')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
            .margin({ top: 8, bottom: 24 })
        }
        .padding(16)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)

      if (this.showAuthPanel) {
        Column() {
          this.authPanel()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .onClick(() => {
          this.showAuthPanel = false
        })
      }

      if (this.showAvatarPanel) {
        Column() {
          this.avatarPanel()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .onClick(() => {
          this.showAvatarPanel = false
        })
      }

      if (this.showSignPanel) {
        Column() {
          this.signPanel()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .onClick(() => {
          this.showSignPanel = false
        })
      }

      if (this.showBodyPanel) {
        Column() {
          this.bodyPanel()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.55)')
        .onClick(() => {
          this.showBodyPanel = false
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** 训练计划：今天对应行下标（周一=0 … 周日=6） */
function isToday(idx: number): boolean {
  const day: number = new Date().getDay()
  const todayIdx: number = day === 0 ? 6 : day - 1
  return idx === todayIdx
}

/** AI 计划日：动作明细摘要（休息日给恢复建议） */
function aiDayDescOf(d: AiWeekPlanDay): string {
  if (d.rest) {
    return '休息恢复 · 保证睡眠与营养，可安排轻度拉伸'
  }
  const parts: string[] = []
  for (let i = 0; i < d.moves.length; i++) {
    const m: GymMove = d.moves[i]
    parts.push(`${m.emoji} ${m.name} ${m.suggestSets}×${m.suggestReps}` +
      (m.suggestWeightKg > 0 ? `@${m.suggestWeightKg}kg` : ''))
  }
  if (parts.length === 0) {
    return d.focus
  }
  return parts.join(' · ')
}

/** AI 计划日强度估算：休息=3；按当日总组数 14+ 高强度 / 10+ 中强度 / 其余低强度 */
function aiDayIntensityOf(d: AiWeekPlanDay): number {
  if (d.rest) {
    return 3
  }
  let totalSets: number = 0
  for (let i = 0; i < d.moves.length; i++) {
    totalSets += d.moves[i].suggestSets
  }
  if (totalSets >= 14) {
    return 2
  }
  if (totalSets >= 10) {
    return 1
  }
  return 0
}

/** 训练强度文案 */
function intensityLabelOf(intensity: number): string {
  if (intensity === 2) {
    return '高强度'
  }
  if (intensity === 1) {
    return '中强度'
  }
  if (intensity === 3) {
    return '休息日'
  }
  return '低强度'
}

/** 训练强度主色 */
function intensityColorOf(intensity: number): string {
  if (intensity === 2) {
    return Theme.RED
  }
  if (intensity === 1) {
    return Theme.ORANGE
  }
  if (intensity === 3) {
    return Theme.TEXT_SUB
  }
  return Theme.BLUE
}

/** 训练强度底色 */
function intensityBgOf(intensity: number): string {
  if (intensity === 2) {
    return 'rgba(239,68,68,0.14)'
  }
  if (intensity === 1) {
    return 'rgba(255,138,61,0.14)'
  }
  if (intensity === 3) {
    return 'rgba(255,255,255,0.06)'
  }
  return 'rgba(47,128,237,0.14)'
}
