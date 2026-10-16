/**
 * 脉动光谷 - 平板端赛事/数据大屏组件（对应需求文档 10 章）
 * 赛事驾驶舱：挑战实况 + 队伍进度看板 + 实时排行榜 + 成就墙 + AI 赛事总结
 * 演示版：定时器模拟队友端里程经软总线实时上报，排行榜与进度条实时变化
 */
import { BadgeDef, Challenge, ChallengeMember, LeaderEntry } from '../common/Types'
import { ChallengeService } from '../service/ChallengeService'
import { LeaderboardService } from '../service/LeaderboardService'
import { AchievementEngine } from '../service/AchievementEngine'
import { StoreService } from '../service/StoreService'
import { DeviceFlowService } from '../service/DeviceFlowService'
import { AiCoach } from '../service/AiCoach'
import { EnvService } from '../service/EnvService'
import { Theme } from '../common/Theme'

@Component
export struct TabletDashboard {
  @State challenge: Challenge = new Challenge()
  @State members: ChallengeMember[] = []
  @State board: LeaderEntry[] = []
  @State unlockedIds: string[] = []
  @State onlineDevices: number = 3
  @State tickCount: number = 0
  @State aiSummary: string = ''
  private liveTimer: number = -1

  aboutToAppear(): void {
    const list: Challenge[] = ChallengeService.list()
    for (let i = 0; i < list.length; i++) {
      if (list[i].joined || this.challenge.id === '') {
        this.challenge = list[i]
        if (list[i].joined) {
          break
        }
      }
    }
    this.members = sortedByProgress(this.challenge.members)
    this.board = LeaderboardService.campusBoard()
    this.unlockedIds = StoreService.getInstance().getUnlockedBadgeIds()
    this.onlineDevices = DeviceFlowService.getInstance().onlineCount() + 1
    this.aiSummary = this.buildAiSummary()
    // 每 5 秒模拟队友端里程经软总线上报（真实环境为 DDO 字段级变更推送）
    this.liveTimer = setInterval((): void => {
      this.liveTick()
    }, 5000)
  }

  aboutToDisappear(): void {
    if (this.liveTimer >= 0) {
      clearInterval(this.liveTimer)
      this.liveTimer = -1
    }
  }

  private liveTick(): void {
    for (let i = 0; i < this.members.length; i++) {
      this.members[i].progressKm =
        Math.round((this.members[i].progressKm + 0.08 + Math.random() * 0.22) * 100) / 100
    }
    this.members = sortedByProgress(this.members.slice())
    this.tickCount += 1
    if (this.tickCount % 4 === 0) {
      this.aiSummary = this.buildAiSummary()
    }
  }

  private buildAiSummary(): string {
    const top: ChallengeMember = this.members.length > 0 ? this.members[0] : new ChallengeMember()
    const totalKm: number = totalKmOf(this.members)
    const pace: number = Math.round((6 + Math.random() * 0.8) * 60)
    const mm: number = Math.floor(pace / 60)
    const ss: string = `${pace % 60 < 10 ? '0' : ''}${pace % 60}`
    const snap = EnvService.getInstance().getSnapshot()
    return `AI 赛事实况：当前累计 ${totalKm.toFixed(1)} 公里，领跑者 ${top.name}（${top.progressKm} km），` +
      `全场平均配速 ${mm}'${ss}''。AQI ${snap.aqi}（${EnvService.aqiLevelOf(snap.aqi)}）适宜户外，` +
      `预计 ${Math.max(1, Math.round((this.challenge.targetKm - totalKm) / Math.max(this.members.length, 1)))} ` +
      `分钟后队伍冲线。冲刺阶段注意保持节奏，完赛记得拉伸补水。`
  }

  private progressPercent(m: ChallengeMember): number {
    if (this.challenge.targetKm <= 0) {
      return 0
    }
    return Math.min(100, Math.round(m.progressKm / this.challenge.targetKm * 100))
  }

  @Builder
  teamRow(m: ChallengeMember, rank: number) {
    Column({ space: 6 }) {
      Row({ space: 10 }) {
        Text(rankBadgeOf(rank))
          .fontSize(16)
          .width(30)
        Text(m.avatar)
          .fontSize(20)
        Text(m.name + (m.isMe ? '（我）' : ''))
          .fontSize(14)
          .fontColor(m.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
          .fontWeight(m.isMe ? FontWeight.Bold : FontWeight.Medium)
          .layoutWeight(1)
        Text('🟢 实时')
          .fontSize(10)
          .fontColor(Theme.GREEN)
        Text(`${m.progressKm} km · ${this.progressPercent(m)}%`)
          .fontSize(13)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      Progress({ value: this.progressPercent(m), total: 100, type: ProgressType.Linear })
        .width('100%')
        .color(rank === 1 ? Theme.ORANGE : Theme.GREEN)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  boardRow(e: LeaderEntry, rank: number) {
    Row({ space: 10 }) {
      Text(rankBadgeOf(rank))
        .fontSize(14)
        .width(28)
      Text(e.avatar)
        .fontSize(18)
      Text(e.name + (e.isMe ? '（我）' : ''))
        .fontSize(13)
        .fontColor(e.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
        .fontWeight(e.isMe ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1)
      Text(`${e.km} km`)
        .fontSize(13)
        .fontColor(Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  badgeCell(b: BadgeDef) {
    Column({ space: 5 }) {
      Text(b.emoji)
        .fontSize(24)
        .opacity(this.unlockedIds.indexOf(b.id) >= 0 ? 1.0 : 0.25)
      Text(b.name)
        .fontSize(9)
        .fontColor(this.unlockedIds.indexOf(b.id) >= 0 ? Theme.TEXT_MAIN : Theme.TEXT_SUB)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 10, bottom: 8 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(12)
  }

  build() {
    Column({ space: 14 }) {
      // 顶部：赛事驾驶舱
      Row({ space: 16 }) {
        Column({ space: 4 }) {
          Text(`${this.challenge.emoji} ${this.challenge.title}`)
            .fontSize(24)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Text(`目标 ${this.challenge.targetKm} km · ${this.challenge.typeDesc} · 截止 ${this.challenge.endDate}`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text(`${this.members.length}`)
            .fontSize(24)
            .fontColor(Theme.GREEN)
            .fontWeight(FontWeight.Bold)
          Text('参与人数')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(`${totalKmOf(this.members).toFixed(1)} km`)
            .fontSize(24)
            .fontColor(Theme.BLUE)
            .fontWeight(FontWeight.Bold)
          Text('累计里程')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text(`${this.onlineDevices}`)
            .fontSize(24)
            .fontColor(Theme.ORANGE)
            .fontWeight(FontWeight.Bold)
          Text('设备同步中')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Theme.CARD_BG)
      .borderRadius(Theme.RADIUS_CARD)

      // 中部：左排行 / 右队伍进度
      Row({ space: 14 }) {
        // 队伍进度看板
        Column({ space: 8 }) {
          Row() {
            Text('🎽 队伍进度看板')
              .fontSize(15)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('软总线实时')
              .fontSize(10)
              .fontColor(Theme.GREEN)
          }
          .width('100%')
          ForEach(this.members, (m: ChallengeMember, idx: number) => {
            this.teamRow(m, idx + 1)
          }, (m: ChallengeMember) => `${m.name}_${m.progressKm}`)
        }
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .layoutWeight(3)
        .alignItems(HorizontalAlign.Start)

        // 实时排行榜
        Column({ space: 8 }) {
          Row() {
            Text('🏆 实时排行榜 · 全校榜')
              .fontSize(15)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text(`已刷新 ${this.tickCount} 次`)
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .width('100%')
          ForEach(this.board, (e: LeaderEntry, idx: number) => {
            this.boardRow(e, idx + 1)
          }, (e: LeaderEntry) => `${e.name}_${e.km}_${e.isMe}`)
        }
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .layoutWeight(2)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top)

      // 底部：成就墙 / AI 赛事总结
      Row({ space: 14 }) {
        Column({ space: 10 }) {
          Row() {
            Text('🏅 成就墙')
              .fontSize(15)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text(`新解锁 ${this.unlockedIds.length} 枚`)
              .fontSize(10)
              .fontColor(Theme.ORANGE)
          }
          .width('100%')
          Grid() {
            ForEach(AchievementEngine.getCatalog(), (b: BadgeDef) => {
              GridItem() {
                this.badgeCell(b)
              }
            }, (b: BadgeDef) => b.id)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
          .columnsGap(8)
          .width('100%')
        }
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 10 }) {
          Row() {
            Text('🤖 AI 赛事总结')
              .fontSize(15)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('每 20 秒自动更新')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
          }
          .width('100%')
          Text(this.aiSummary)
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .lineHeight(22)
          Text(`下一次活动建议：${AiCoach.nextGoalHint()}`)
            .fontSize(12)
            .fontColor(Theme.BLUE)
        }
        .padding(14)
        .backgroundColor(Theme.CARD_BG)
        .borderRadius(Theme.RADIUS_CARD)
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** 成员按进度降序 */
function sortedByProgress(list: ChallengeMember[]): ChallengeMember[] {
  const arr: ChallengeMember[] = list.slice()
  arr.sort((a: ChallengeMember, b: ChallengeMember): number => b.progressKm - a.progressKm)
  return arr
}

/** 队伍累计里程 */
function totalKmOf(list: ChallengeMember[]): number {
  let total: number = 0
  for (let i = 0; i < list.length; i++) {
    total += list[i].progressKm
  }
  return total
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
