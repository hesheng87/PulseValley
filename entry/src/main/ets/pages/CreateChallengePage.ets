/**
 * 脉动光谷 - 创建挑战页（对应需求文档 8.3 创建挑战）
 * 挑战类型 / 目标设置 / 截止时间 / 组队模式 / 邀请好友
 */
import { CommunityUser } from '../common/Types'
import { ChallengeService } from '../service/ChallengeService'
import { CommunityService } from '../service/CommunityService'
import { AchievementEngine } from '../service/AchievementEngine'
import { Theme } from '../common/Theme'

interface ChallengeTypeOption {
  name: string
  emoji: string
  typeDesc: string
}

const TYPE_OPTIONS: ChallengeTypeOption[] = [
  { name: '接力赛', emoji: '🎽', typeDesc: '接力赛' },
  { name: '累计里程赛', emoji: '📏', typeDesc: '累计里程赛' },
  { name: '步数PK', emoji: '👟', typeDesc: '步数PK' },
  { name: '配速对决', emoji: '⏱️', typeDesc: '配速对决' },
  { name: '环湖打卡', emoji: '🏞️', typeDesc: '环湖打卡' }
]

const END_DATE_OPTIONS: string[] = ['本周五 24:00', '本周日 24:00', '下周五 24:00']

@Entry
@Component
struct CreateChallengePage {
  @State title: string = ''
  @State selectedType: number = 0
  @State targetKm: number = 10
  @State endDateIdx: number = 1
  @State teamMode: boolean = true
  @State friends: CommunityUser[] = []
  @State invitedIds: string[] = []

  aboutToAppear(): void {
    this.friends = CommunityService.listFriends()
    if (this.friends.length === 0) {
      // 未添加好友时展示校园跑友，便于演示邀请
      this.friends = CommunityService.listRunners()
    }
  }

  private toggleInvite(id: string): void {
    const idx: number = this.invitedIds.indexOf(id)
    if (idx >= 0) {
      this.invitedIds.splice(idx, 1)
    } else {
      this.invitedIds.push(id)
    }
    this.invitedIds = this.invitedIds.slice()
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (e) {
      console.error('[CreateChallengePage] showToast failed')
    }
  }

  private submit(): void {
    if (this.title === '') {
      this.toast('先给挑战起个响亮的名字吧')
      return
    }
    const opt: ChallengeTypeOption = TYPE_OPTIONS[this.selectedType]
    const c = ChallengeService.create(this.title, opt.emoji, opt.typeDesc,
      this.targetKm, END_DATE_OPTIONS[this.endDateIdx], this.teamMode)
    const badges = AchievementEngine.evaluateOnJoinChallenge()
    if (badges.length > 0) {
      this.toast(`挑战已创建！解锁勋章「${badges[0].name}」${badges[0].emoji}`)
    } else {
      const inviteText: string = this.invitedIds.length > 0
        ? `，已邀请 ${this.invitedIds.length} 位好友` : ''
      this.toast(`挑战「${c.title}」创建成功${inviteText} 🎉`)
    }
    this.getUIContext().getRouter().back()
  }

  @Builder
  typeChip(opt: ChallengeTypeOption, index: number) {
    Column({ space: 6 }) {
      Text(opt.emoji)
        .fontSize(22)
      Text(opt.name)
        .fontSize(11)
        .fontColor(this.selectedType === index ? Theme.GREEN : Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 12, bottom: 10 })
    .backgroundColor(this.selectedType === index ? 'rgba(49,208,127,0.16)' : Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .border({
      width: 1,
      color: this.selectedType === index ? Theme.GREEN : Theme.CARD_STROKE
    })
    .onClick(() => {
      this.selectedType = index
    })
  }

  @Builder
  dateChip(text: string, index: number) {
    Text(text)
      .fontSize(12)
      .fontColor(this.endDateIdx === index ? '#06281A' : Theme.TEXT_MAIN)
      .fontWeight(this.endDateIdx === index ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.endDateIdx === index ? Theme.GREEN : Theme.CARD_BG)
      .borderRadius(16)
      .onClick(() => {
        this.endDateIdx = index
      })
  }

  @Builder
  friendChip(f: CommunityUser) {
    Row({ space: 6 }) {
      Text(f.avatar)
        .fontSize(14)
      Text(f.name)
        .fontSize(12)
        .fontColor(this.invitedIds.indexOf(f.id) >= 0 ? '#3A1802' : Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Medium)
      if (this.invitedIds.indexOf(f.id) >= 0) {
        Text('✓')
          .fontSize(11)
          .fontColor('#3A1802')
          .fontWeight(FontWeight.Bold)
      }
    }
    .padding({ left: 12, right: 12, top: 7, bottom: 7 })
    .backgroundColor(this.invitedIds.indexOf(f.id) >= 0 ? Theme.ORANGE : Theme.CARD_BG)
    .borderRadius(16)
    .onClick(() => {
      this.toggleInvite(f.id)
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row({ space: 10 }) {
          Text('‹')
            .fontSize(24)
            .fontColor(Theme.TEXT_MAIN)
            .onClick(() => {
              this.getUIContext().getRouter().back()
            })
          Text('创建挑战')
            .fontSize(20)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')

        Column({ space: 8 }) {
          Text('挑战名称')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
          TextInput({ placeholder: '例如：光谷 3 公里接力 / 宿舍步数 PK' })
            .height(46)
            .fontSize(14)
            .fontColor(Theme.TEXT_MAIN)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(12)
            .onChange((value: string) => {
              this.title = value
            })
        }
        .width('100%')

        Text('挑战类型')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
        Grid() {
          ForEach(TYPE_OPTIONS, (opt: ChallengeTypeOption, index: number) => {
            GridItem() {
              this.typeChip(opt, index)
            }
          }, (opt: ChallengeTypeOption) => opt.name)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .columnsGap(8)
        .width('100%')

        Column({ space: 8 }) {
          Text(`目标里程：${this.targetKm} km`)
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
          Slider({ value: this.targetKm, min: 3, max: 100, step: 1 })
            .width('100%')
            .blockColor(Theme.GREEN)
            .trackColor(Theme.CARD_BG)
            .selectedColor(Theme.GREEN)
            .onChange((value: number) => {
              this.targetKm = Math.round(value)
            })
        }
        .width('100%')

        Text('截止时间')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
        Row({ space: 10 }) {
          ForEach(END_DATE_OPTIONS, (text: string, index: number) => {
            this.dateChip(text, index)
          }, (text: string) => text)
        }
        .width('100%')

        Row() {
          Column({ space: 3 }) {
            Text('组队模式')
              .fontSize(14)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Medium)
            Text('队友里程计入队伍总分，排行榜按队伍排名')
              .fontSize(11)
              .fontColor(Theme.TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.teamMode })
            .selectedColor(Theme.GREEN)
            .onChange((isOn: boolean) => {
              this.teamMode = isOn
            })
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)

        Column({ space: 10 }) {
          Text(`邀请好友（已选 ${this.invitedIds.length} 人）`)
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
          if (this.friends.length === 0) {
            Text('暂无可邀请的好友，去动态页添加跑友吧')
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
          }
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.friends, (f: CommunityUser) => {
              this.friendChip(f)
            }, (f: CommunityUser) => `${f.id}_${this.invitedIds.indexOf(f.id) >= 0}`)
          }
          .width('100%')
        }
        .width('100%')

        Button('🚀 发起挑战')
          .width('100%')
          .height(52)
          .backgroundColor(Theme.ORANGE)
          .fontColor('#3A1802')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .borderRadius(Theme.RADIUS_BTN)
          .margin({ top: 6, bottom: 30 })
          .onClick(() => {
            this.submit()
          })
      }
      .padding(16)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(Theme.BG_TOP)
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }
}
