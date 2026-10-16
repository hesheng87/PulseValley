/**
 * 脉动光谷 - 挑战详情页
 * 挑战信息 / 队伍完成度 / 成员实时进度 / 玩法说明 / 加入或去运动
 * 队友进度经软总线实时同步（演示版定时模拟增量，与挑战页一致）
 */
import { Challenge, ChallengeMember } from '../common/Types'
import { ChallengeService } from '../service/ChallengeService'
import { AchievementEngine } from '../service/AchievementEngine'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { CheerMessage } from '../common/Types'
import { Theme } from '../common/Theme'
import { RunningParams, ChallengeDetailParams } from '../model/RouteParams'

@Entry
@Component
struct ChallengeDetailPage {
  @State challenge: Challenge = new Challenge()
  @State found: boolean = false
  @State latestCheer: CheerMessage = new CheerMessage()
  private liveTimer: number = -1

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as ChallengeDetailParams
    if (params !== undefined && params.challengeId !== undefined) {
      this.loadChallenge(params.challengeId)
    }
    // 队友实时动态：模拟经软总线推送队友端里程增量（演示版定时驱动）
    this.liveTimer = setInterval((): void => {
      this.liveTick()
    }, 12000)
    DeviceFlowService.getInstance().startCheerFeed((cheer: CheerMessage): void => {
      this.latestCheer = cheer
    })
  }

  aboutToDisappear(): void {
    if (this.liveTimer >= 0) {
      clearInterval(this.liveTimer)
      this.liveTimer = -1
    }
    DeviceFlowService.getInstance().stopCheerFeed()
  }

  private loadChallenge(id: string): void {
    const list: Challenge[] = ChallengeService.list()
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        this.challenge = list[i]
        this.found = true
        return
      }
    }
  }

  /** 模拟队友端实时里程上报（真实环境经 DDO 字段级变更推送） */
  private liveTick(): void {
    let changed: boolean = false
    for (let j = 0; j < this.challenge.members.length; j++) {
      if (!this.challenge.members[j].isMe) {
        this.challenge.members[j].progressKm =
          Math.round((this.challenge.members[j].progressKm + 0.05 + Math.random() * 0.15) * 100) / 100
        changed = true
      }
    }
    if (changed) {
      const c: Challenge = this.challenge
      this.challenge = Challenge.of(c.id, c.title, c.emoji, c.typeDesc,
        c.targetKm, c.endDate, c.members, c.joined)
    }
  }

  /** 队伍完成度：成员累计里程 / 目标（上限 100%） */
  private teamPercent(): number {
    let sum: number = 0
    for (let i = 0; i < this.challenge.members.length; i++) {
      sum += this.challenge.members[i].progressKm
    }
    const target: number = this.challenge.targetKm > 0 ? this.challenge.targetKm : 1
    return Math.min(100, Math.round(sum / target * 100))
  }

  private teamTotalKm(): number {
    let sum: number = 0
    for (let i = 0; i < this.challenge.members.length; i++) {
      sum += this.challenge.members[i].progressKm
    }
    return Math.round(sum * 10) / 10
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (e) {
      console.error('[ChallengeDetailPage] showToast failed')
    }
  }

  private doJoin(): void {
    ChallengeService.join(this.challenge.id)
    this.loadChallenge(this.challenge.id)
    const badges = AchievementEngine.evaluateOnJoinChallenge()
    if (badges.length > 0) {
      this.toast(`已加入！解锁勋章「${badges[0].name}」${badges[0].emoji}`)
    } else {
      this.toast(`已加入「${this.challenge.title}」`)
    }
  }

  /** 向队友广播语音加油 */
  private sendCheer(): void {
    const texts: string[] = ['兄弟们冲！🔥', '进度过半，稳住！💪', '完赛约奶茶！🧋']
    const idx: number = Math.floor(Math.random() * texts.length)
    const cheer: CheerMessage = DeviceFlowService.getInstance().sendCheer('我', '📣',
      texts[Math.min(idx, texts.length - 1)])
    this.latestCheer = cheer
    this.toast(`语音加油已广播：${cheer.text}`)
  }

  private goRun(): void {
    const p: RunningParams = { type: 0 }
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/RunningPage', params: p })
    } catch (e) {
      console.error('[ChallengeDetailPage] goRun failed')
    }
  }

  @Builder
  infoCell(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(17)
        .fontColor(Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
      Text(label)
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  memberCard(m: ChallengeMember, rank: number) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(`${rank}`)
          .fontSize(13)
          .fontColor(rank === 1 ? Theme.ORANGE : Theme.TEXT_SUB)
          .fontWeight(FontWeight.Bold)
          .width(18)
        Text(m.avatar)
          .fontSize(18)
        Text(m.name + (m.isMe ? '（我）' : ''))
          .fontSize(13)
          .fontColor(m.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
          .fontWeight(m.isMe ? FontWeight.Bold : FontWeight.Normal)
          .layoutWeight(1)
        if (!m.isMe) {
          Text('🟢 实时')
            .fontSize(9)
            .fontColor(Theme.GREEN)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor('rgba(49,208,127,0.12)')
            .borderRadius(8)
        }
        Text(`${m.progressKm} km`)
          .fontSize(13)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      Progress({
        value: Math.min(100, m.progressKm / (this.challenge.targetKm > 0 ? this.challenge.targetKm : 1) * 100),
        total: 100,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(6)
        .color(m.isMe ? Theme.GREEN : Theme.BLUE)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  ruleRow(text: string) {
    Row({ space: 8 }) {
      Text('•')
        .fontSize(13)
        .fontColor(Theme.GREEN)
        .fontWeight(FontWeight.Bold)
      Text(text)
        .fontSize(12)
        .fontColor(Theme.TEXT_SUB)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Text('‹')
          .fontSize(26)
          .fontColor(Theme.TEXT_MAIN)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('挑战详情')
          .fontSize(18)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        if (this.challenge.joined) {
          Text('已加入')
            .fontSize(11)
            .fontColor(Theme.GREEN)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(49,208,127,0.16)')
            .borderRadius(10)
        }
      }
      .width('100%')

      if (!this.found) {
        Text('挑战不存在或已被解散')
          .fontSize(13)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 40 })
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 10 }) {
              Text(`${this.challenge.emoji} ${this.challenge.title}`)
                .fontSize(20)
                .fontColor(Theme.TEXT_MAIN)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              Text(this.challenge.typeDesc)
                .fontSize(12)
                .fontColor(Theme.BLUE)
                .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                .backgroundColor('rgba(47,128,237,0.12)')
                .borderRadius(10)

              Row() {
                this.infoCell(`${this.challenge.targetKm}`, '目标 km')
                this.infoCell(this.challenge.endDate, '截止时间')
                this.infoCell(`${this.challenge.members.length}`, '参与成员')
                this.infoCell(`${this.teamTotalKm()}`, '队伍累计 km')
              }
              .width('100%')
              .padding({ top: 4 })
            }
            .padding(14)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
            .width('100%')

            Column({ space: 10 }) {
              Row() {
                Text('🏁 队伍完成度')
                  .fontSize(15)
                  .fontColor(Theme.TEXT_MAIN)
                  .fontWeight(FontWeight.Bold)
                  .layoutWeight(1)
                Text(`${this.teamPercent()}%`)
                  .fontSize(15)
                  .fontColor(Theme.GREEN)
                  .fontWeight(FontWeight.Bold)
              }
              .width('100%')
              Progress({ value: this.teamPercent(), total: 100, type: ProgressType.Linear })
                .width('100%')
                .height(8)
                .color(Theme.GREEN)
              Text(`全队累计 ${this.teamTotalKm()} / ${this.challenge.targetKm} km · 任意成员运动完成后实时计入`)
                .fontSize(10)
                .fontColor(Theme.TEXT_SUB)
                .width('100%')
            }
            .padding(14)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
            .width('100%')

            if (this.latestCheer.text !== '') {
              Text(`📣 ${this.latestCheer.from}：${this.latestCheer.text}`)
                .fontSize(12)
                .fontColor(Theme.BLUE)
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor('rgba(47,128,237,0.12)')
                .borderRadius(12)
                .width('100%')
                .textAlign(TextAlign.Center)
            }

            Column({ space: 4 }) {
              Text('👥 成员实时进度')
                .fontSize(15)
                .fontColor(Theme.TEXT_MAIN)
                .fontWeight(FontWeight.Bold)
                .width('100%')
                .margin({ bottom: 4 })
              ForEach(sortedMembers(this.challenge), (m: ChallengeMember, idx: number) => {
                this.memberCard(m, idx + 1)
              }, (m: ChallengeMember) => `${this.challenge.id}_${m.name}_${m.progressKm}`)
            }
            .padding(14)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Text('📖 玩法说明')
                .fontSize(15)
                .fontColor(Theme.TEXT_MAIN)
                .fontWeight(FontWeight.Bold)
                .width('100%')
              ForEach(ruleTextsOf(this.challenge.typeDesc), (rule: string) => {
                this.ruleRow(rule)
              }, (rule: string) => rule)
            }
            .padding(14)
            .backgroundColor(Theme.CARD_BG)
            .borderRadius(Theme.RADIUS_CARD)
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Text('📡 队友数据经分布式软总线实时同步 · 任意端运动完成全端立即更新')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 8 })
          }
          .padding(16)
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)

        if (!this.challenge.joined) {
          Button('加入挑战')
            .width('100%')
            .height(48)
            .backgroundColor(Theme.ORANGE)
            .fontColor('#3A1802')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .borderRadius(Theme.RADIUS_BTN)
            .onClick(() => {
              this.doJoin()
            })
        } else {
          Row({ space: 12 }) {
            Button('📣 语音加油')
              .layoutWeight(1)
              .height(48)
              .fontSize(14)
              .backgroundColor('rgba(139,92,246,0.20)')
              .fontColor(Theme.PURPLE)
              .borderRadius(Theme.RADIUS_BTN)
              .onClick(() => {
                this.sendCheer()
              })
            Button('🏃 去跑两步')
              .layoutWeight(1)
              .height(48)
              .fontSize(14)
              .backgroundColor(Theme.GREEN)
              .fontColor('#06281A')
              .fontWeight(FontWeight.Medium)
              .borderRadius(Theme.RADIUS_BTN)
              .onClick(() => {
                this.goRun()
              })
          }
          .width('100%')
          .padding({ bottom: 12 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .linearGradient({
      angle: 160,
      colors: [[Theme.BG_TOP, 0.0], [Theme.BG_BOTTOM, 1.0]]
    })
  }
}

/** 成员按进度降序 */
function sortedMembers(c: Challenge): ChallengeMember[] {
  const arr: ChallengeMember[] = c.members.slice()
  arr.sort((a: ChallengeMember, b: ChallengeMember): number => b.progressKm - a.progressKm)
  return arr
}

/** 按挑战类型的玩法说明 */
function ruleTextsOf(typeDesc: string): string[] {
  if (typeDesc === '接力赛') {
    return ['每位队员依次完成 1 公里后交接下一位', '全队累计里程达到目标即挑战成功', '交接瞬间手表与平板大屏同步提醒']
  }
  if (typeDesc === '累计里程赛') {
    return ['个人运动里程实时计入队伍总进度', '任意设备完成运动即自动结算入榜', '达标后成就经软总线同步全部设备']
  }
  if (typeDesc === '步数PK') {
    return ['每日步数 24:00 自动结算', '以计步传感器数据为准，不可手改', '异常速度数据将被防作弊红线过滤']
  }
  if (typeDesc === '配速对决') {
    return ['以平均配速排名，越稳越强', '单次至少完成 2 公里才计入榜单', 'GPS 轨迹点用于校验有效里程']
  }
  return ['按路线节点顺序依次打卡', 'GPS 定位进入节点 50 米范围自动打卡', '完成全部节点即完赛']
}
