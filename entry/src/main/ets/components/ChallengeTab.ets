/**
 * 脉动光谷 - 挑战页（Tab3，对齐需求文档 8.3）
 * 我的挑战（进行中）/ 推荐挑战 / 创建挑战 / AI 智能组队匹配
 * 多维度排行榜 + 成就墙（等级成长 + 勋章墙，端侧成就引擎解锁）
 */
import { AiMateMatch, BadgeDef, Challenge, ChallengeMember, CheerMessage, LeaderEntry, UserStats } from '../common/Types'
import { ChallengeService } from '../service/ChallengeService'
import { AchievementEngine } from '../service/AchievementEngine'
import { LeaderboardService, LeaderScope } from '../service/LeaderboardService'
import { AiCoach } from '../service/AiCoach'
import { StoreService } from '../service/StoreService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { Theme } from '../common/Theme'
import { RunningParams, ChallengeDetailParams, LeaderboardParams } from '../model/RouteParams'

@Component
export struct ChallengeTab {
  @State challenges: Challenge[] = []
  @State mates: AiMateMatch[] = []
  @State boardScope: LeaderScope = LeaderScope.CAMPUS
  @State board: LeaderEntry[] = []
  @State myRank: number = 0
  @State latestCheer: CheerMessage = new CheerMessage()
  @State stats: UserStats = new UserStats()
  @State unlockedIds: string[] = []
  @State deviceCount: number = 1
  private liveTimer: number = -1

  aboutToAppear(): void {
    this.stats = StoreService.getInstance().getUserStats()
    this.challenges = ChallengeService.list()
    this.mates = AiCoach.matchTeammates(this.stats, new Date().getHours())
    this.unlockedIds = StoreService.getInstance().getUnlockedBadgeIds()
    this.deviceCount = DeviceFlowService.getInstance().onlineCount() + 1
    DeviceFlowService.getInstance().broadcastAchievements()
    this.refreshBoard()
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

  /** 模拟队友端实时里程上报（真实环境经 DDO 字段级变更推送） */
  private liveTick(): void {
    let changed: boolean = false
    for (let i = 0; i < this.challenges.length; i++) {
      const c: Challenge = this.challenges[i]
      if (!c.joined) {
        continue
      }
      for (let j = 0; j < c.members.length; j++) {
        if (!c.members[j].isMe) {
          c.members[j].progressKm =
            Math.round((c.members[j].progressKm + 0.05 + Math.random() * 0.15) * 100) / 100
          changed = true
        }
      }
    }
    if (changed) {
      this.challenges = this.challenges.slice()
    }
  }

  private refreshBoard(): void {
    if (this.boardScope === LeaderScope.FRIENDS) {
      this.board = LeaderboardService.friendBoard()
    } else {
      this.board = LeaderboardService.campusBoard()
    }
    this.myRank = LeaderboardService.myRank(this.board)
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (e) {
      console.error('[ChallengeTab] showToast failed')
    }
  }

  private doJoin(c: Challenge): void {
    ChallengeService.join(c.id)
    const badges = AchievementEngine.evaluateOnJoinChallenge()
    this.challenges = ChallengeService.list()
    if (badges.length > 0) {
      this.toast(`解锁勋章「${badges[0].name}」${badges[0].emoji}`)
    } else {
      this.toast(`已加入「${c.title}」`)
    }
  }

  /** 邀请 AI 匹配的队友组队 */
  private inviteMate(m: AiMateMatch): void {
    this.toast(`已向 ${m.user.name} 发起组队邀请（匹配度 ${m.matchScore}%）🤝`)
  }

  /** 向队友广播语音加油 */
  private sendCheer(c: Challenge): void {
    const texts: string[] = ['兄弟们冲！🔥', '进度过半，稳住！💪', '完赛约奶茶！🧋']
    const idx: number = Math.floor(Math.random() * texts.length)
    const cheer: CheerMessage = DeviceFlowService.getInstance().sendCheer('我', '📣',
      texts[Math.min(idx, texts.length - 1)])
    this.latestCheer = cheer
    this.toast(`语音加油已广播到「${c.title}」：${cheer.text}`)
  }

  private levelProgress(): number {
    const currentLevelPoints: number = 50 * Math.pow(this.stats.level - 1, 2)
    const nextLevelPoints: number = 50 * Math.pow(this.stats.level, 2)
    if (nextLevelPoints <= currentLevelPoints) {
      return 0
    }
    return Math.round((this.stats.totalPoints - currentLevelPoints) /
      (nextLevelPoints - currentLevelPoints) * 100)
  }

  @Builder
  memberRow(m: ChallengeMember, rank: number) {
    Row({ space: 10 }) {
      Text(`${rank}`)
        .fontSize(14)
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
      Text(`${m.progressKm} km`)
        .fontSize(13)
        .fontColor(Theme.TEXT_MAIN)
      if (!m.isMe) {
        Text('🟢 实时')
          .fontSize(9)
          .fontColor(Theme.GREEN)
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .backgroundColor('rgba(49,208,127,0.12)')
          .borderRadius(8)
      }
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  mateCard(m: AiMateMatch) {
    Row({ space: 12 }) {
      Text(m.user.avatar)
        .fontSize(26)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(m.user.name)
            .fontSize(14)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text(`匹配度 ${m.matchScore}%`)
            .fontSize(11)
            .fontColor(Theme.PURPLE)
            .fontWeight(FontWeight.Bold)
        }
        Text(m.reason)
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button('邀请组队')
        .height(32)
        .fontSize(12)
        .backgroundColor(Theme.PURPLE)
        .fontColor('#FFFFFF')
        .borderRadius(14)
        .onClick(() => {
          this.inviteMate(m)
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
  }

  @Builder
  boardRow(e: LeaderEntry, rank: number) {
    Row({ space: 10 }) {
      Text(rankBadgeOf(rank))
        .fontSize(14)
        .width(24)
      Text(e.avatar)
        .fontSize(16)
      Text(e.name + (e.isMe ? '（我）' : ''))
        .fontSize(13)
        .fontColor(e.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
        .fontWeight(e.isMe ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)
      Text(e.dept)
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
      Text(`${e.km} km`)
        .fontSize(13)
        .fontColor(Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  challengeCard(c: Challenge) {
    Column({ space: 10 }) {
      Row() {
        Text(`${c.emoji} ${c.title}`)
          .fontSize(16)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (c.joined) {
          Text('已加入')
            .fontSize(11)
            .fontColor(Theme.GREEN)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(49,208,127,0.16)')
            .borderRadius(10)
        }
        Text('详情 ›')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')

      Row({ space: 10 }) {
        Text(c.typeDesc)
          .fontSize(11)
          .fontColor(Theme.BLUE)
        Text(`目标 ${c.targetKm} km`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
        Text(`截止 ${c.endDate}`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')

      Column({ space: 2 }) {
        ForEach(sortedMembers(c), (item: ChallengeMember, idx: number) => {
          this.memberRow(item, idx + 1)
        }, (item: ChallengeMember) => `${c.id}_${item.name}_${item.progressKm}`)
      }
      .width('100%')

      if (c.joined) {
        Row({ space: 10 }) {
          Button('📣 语音加油')
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .backgroundColor('rgba(139,92,246,0.20)')
            .fontColor(Theme.PURPLE)
            .borderRadius(19)
            .onClick(() => {
              this.sendCheer(c)
            })
          Button('🏃 去跑两步')
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .backgroundColor(Theme.GREEN)
            .fontColor('#06281A')
            .fontWeight(FontWeight.Medium)
            .borderRadius(19)
            .onClick(() => {
              const p: RunningParams = { type: 0 }
              this.getUIContext().getRouter().pushUrl({ url: 'pages/RunningPage', params: p })
            })
        }
        .width('100%')
      } else {
        Button('加入挑战')
          .width('100%')
          .height(40)
          .backgroundColor(Theme.ORANGE)
          .fontColor('#3A1802')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .borderRadius(Theme.RADIUS_BTN)
          .onClick(() => {
            this.doJoin(c)
          })
      }
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
    .onClick(() => {
      const p: ChallengeDetailParams = { challengeId: c.id }
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ChallengeDetailPage', params: p })
    })
  }

  @Builder
  badgeCell(b: BadgeDef) {
    Column({ space: 6 }) {
      Text(b.emoji)
        .fontSize(28)
        .opacity(this.unlockedIds.indexOf(b.id) >= 0 ? 1.0 : 0.25)
      Text(b.name)
        .fontSize(11)
        .fontColor(this.unlockedIds.indexOf(b.id) >= 0 ? Theme.TEXT_MAIN : Theme.TEXT_SUB)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 12, bottom: 10 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .onClick(() => {
      this.getUIContext().getPromptAction().showToast({ message: `${b.emoji} ${b.name}：${b.desc}` })
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Column() {
            Text('组队挑战')
              .fontSize(22)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Text('和校友一起互相监督，队友数据实时可见')
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('＋ 创建挑战')
            .height(34)
            .fontSize(12)
            .backgroundColor(Theme.ORANGE)
            .fontColor('#3A1802')
            .fontWeight(FontWeight.Bold)
            .borderRadius(17)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/CreateChallengePage' })
            })
        }
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

        // 我的挑战（进行中）
        if (myChallenges(this.challenges).length > 0) {
          Text('🔥 我的挑战')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          ForEach(myChallenges(this.challenges), (c: Challenge) => {
            this.challengeCard(c)
          }, (c: Challenge) => `${c.id}_${c.joined}_${c.members[0].progressKm}`)
        }

        // 推荐挑战
        if (recommendChallenges(this.challenges).length > 0) {
          Text('🌟 推荐挑战 · 正在报名')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          ForEach(recommendChallenges(this.challenges), (c: Challenge) => {
            this.challengeCard(c)
          }, (c: Challenge) => `${c.id}_${c.joined}`)
        }

        // AI 智能组队匹配
        Text('🤖 AI 智能组队匹配')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        Text('大模型综合运动水平 · 时间偏好 · 目标一致性为你推荐队友')
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .width('100%')
        if (this.mates.length === 0) {
          Text('校园跑友都已认识，去动态页认识更多小伙伴吧')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        ForEach(this.mates, (m: AiMateMatch) => {
          this.mateCard(m)
        }, (m: AiMateMatch) => `${m.user.id}_${m.matchScore}`)

        // 多维度排行榜
        Row() {
          Text('🏆 排行榜')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(`我的名次 #${this.myRank}`)
            .fontSize(12)
            .fontColor(Theme.ORANGE)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')

        Row({ space: 10 }) {
          Button(this.boardScope === LeaderScope.FRIENDS ? '● 好友榜' : '好友榜')
            .layoutWeight(1)
            .height(34)
            .fontSize(12)
            .backgroundColor(this.boardScope === LeaderScope.FRIENDS ? Theme.GREEN : Theme.CARD_BG)
            .fontColor(this.boardScope === LeaderScope.FRIENDS ? '#06281A' : Theme.TEXT_SUB)
            .borderRadius(17)
            .onClick(() => {
              this.boardScope = LeaderScope.FRIENDS
              this.refreshBoard()
            })
          Button(this.boardScope === LeaderScope.CAMPUS ? '● 全校榜' : '全校榜')
            .layoutWeight(1)
            .height(34)
            .fontSize(12)
            .backgroundColor(this.boardScope === LeaderScope.CAMPUS ? Theme.GREEN : Theme.CARD_BG)
            .fontColor(this.boardScope === LeaderScope.CAMPUS ? '#06281A' : Theme.TEXT_SUB)
            .borderRadius(17)
            .onClick(() => {
              this.boardScope = LeaderScope.CAMPUS
              this.refreshBoard()
            })
        }
        .width('100%')

        Column({ space: 2 }) {
          ForEach(topEntries(this.board), (e: LeaderEntry, idx: number) => {
            this.boardRow(e, idx + 1)
          }, (e: LeaderEntry) => `${e.name}_${e.km}_${e.isMe}`)

          Button('查看全部榜单（好友 / 全校 / 班级 / 跨校 / 队伍）›')
            .width('100%')
            .height(38)
            .margin({ top: 8 })
            .fontSize(12)
            .backgroundColor('rgba(49,208,127,0.14)')
            .fontColor(Theme.GREEN)
            .fontWeight(FontWeight.Medium)
            .borderRadius(19)
            .onClick(() => {
              const p: LeaderboardParams = { scope: this.boardScope }
              this.getUIContext().getRouter().pushUrl({ url: 'pages/LeaderboardPage', params: p })
            })
        }
        .padding(12)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .width('100%')

        // 成就墙
        Row() {
          Text('🏅 成就墙')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(`已解锁 ${this.unlockedIds.length} / ${AchievementEngine.getCatalog().length} 枚`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')

        Column({ space: 10 }) {
          Row() {
            Text(`Lv.${this.stats.level}`)
              .fontSize(28)
              .fontColor(Theme.ORANGE)
              .fontWeight(FontWeight.Bold)
            Column({ space: 2 }) {
              Text(`运动积分 ${this.stats.totalPoints}`)
                .fontSize(13)
                .fontColor(Theme.TEXT_MAIN)
              Text(`距下一级还需 ${Math.max(50 * Math.pow(this.stats.level, 2) - this.stats.totalPoints, 0)} 积分`)
                .fontSize(11)
                .fontColor(Theme.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 12 })
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Progress({ value: this.levelProgress(), total: 100, type: ProgressType.Linear })
            .width('100%')
            .color(Theme.ORANGE)
        }
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .width('100%')

        Grid() {
          ForEach(AchievementEngine.getCatalog(), (b: BadgeDef) => {
            GridItem() {
              this.badgeCell(b)
            }
          }, (b: BadgeDef) => b.id)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsGap(10)
        .columnsGap(10)
        .width('100%')

        Text(`📡 分布式成就已同步至 ${this.deviceCount} 台设备 · 任意端完成挑战全端立即更新（软总线）`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
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
  }
}

/** 我已加入的挑战 */
function myChallenges(list: Challenge[]): Challenge[] {
  const mine: Challenge[] = []
  for (let i = 0; i < list.length; i++) {
    if (list[i].joined) {
      mine.push(list[i])
    }
  }
  return mine
}

/** 未加入的推荐挑战 */
function recommendChallenges(list: Challenge[]): Challenge[] {
  const rec: Challenge[] = []
  for (let i = 0; i < list.length; i++) {
    if (!list[i].joined) {
      rec.push(list[i])
    }
  }
  return rec
}

/** 成员按进度降序 */
function sortedMembers(c: Challenge): ChallengeMember[] {
  const arr: ChallengeMember[] = c.members.slice()
  arr.sort((a: ChallengeMember, b: ChallengeMember): number => b.progressKm - a.progressKm)
  return arr
}

/** 榜单预览：前三名 */
function topEntries(list: LeaderEntry[]): LeaderEntry[] {
  const top: LeaderEntry[] = []
  const max: number = Math.min(list.length, 3)
  for (let i = 0; i < max; i++) {
    top.push(list[i])
  }
  return top
}

/** 前三名奖牌标识 */
function rankBadgeOf(rank: number): string {
  if (rank === 1) {
    return '🥇'
  }
  if (rank === 2) {
    return '🥈'
  }
  if (rank === 3) {
    return '🥉'
  }
  return `${rank}`
}
