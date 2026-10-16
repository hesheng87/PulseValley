/**
 * 脉动光谷 - 排行榜页（多维度）
 * 好友榜 / 全校榜 / 班级榜 / 跨校榜 / 队伍榜 全量展示
 * 我的真实累计里程实时插入排序，Local-First 落盘后立即反映
 */
import { LeaderEntry } from '../common/Types'
import { LeaderboardService, LeaderScope } from '../service/LeaderboardService'
import { Theme } from '../common/Theme'
import { LeaderboardParams } from '../model/RouteParams'

interface ScopeMeta {
  label: string
  scope: LeaderScope
}

const SCOPE_TABS: ScopeMeta[] = [
  { label: '好友榜', scope: LeaderScope.FRIENDS },
  { label: '全校榜', scope: LeaderScope.CAMPUS },
  { label: '班级榜', scope: LeaderScope.CLASS },
  { label: '跨校榜', scope: LeaderScope.SCHOOL },
  { label: '队伍榜', scope: LeaderScope.TEAM }
]

@Entry
@Component
struct LeaderboardPage {
  @State boardScope: LeaderScope = LeaderScope.CAMPUS
  @State board: LeaderEntry[] = []
  @State myRank: number = 0

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as LeaderboardParams
    if (params !== undefined && params.scope !== undefined) {
      const scope: LeaderScope = params.scope as LeaderScope
      this.boardScope = scope
    }
    this.refreshBoard()
  }

  private refreshBoard(): void {
    this.board = LeaderboardService.boardOf(this.boardScope)
    this.myRank = LeaderboardService.myRank(this.board)
  }

  private scopeLabel(): string {
    for (let i = 0; i < SCOPE_TABS.length; i++) {
      if (SCOPE_TABS[i].scope === this.boardScope) {
        return SCOPE_TABS[i].label
      }
    }
    return '排行榜'
  }

  @Builder
  scopeChip(meta: ScopeMeta) {
    Text(meta.label)
      .fontSize(12)
      .fontColor(this.boardScope === meta.scope ? '#06281A' : Theme.TEXT_MAIN)
      .fontWeight(this.boardScope === meta.scope ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.boardScope === meta.scope ? Theme.GREEN : Theme.CARD_BG)
      .borderRadius(16)
      .border({
        width: 1,
        color: this.boardScope === meta.scope ? Theme.GREEN : Theme.CARD_STROKE
      })
      .onClick(() => {
        this.boardScope = meta.scope
        this.refreshBoard()
      })
  }

  @Builder
  boardRow(e: LeaderEntry, rank: number) {
    Row({ space: 10 }) {
      Text(rankBadgeOf(rank))
        .fontSize(14)
        .width(26)
        .textAlign(TextAlign.Center)
      Text(e.avatar)
        .fontSize(16)
      Column({ space: 2 }) {
        Text(e.name + (e.isMe ? '（我）' : ''))
          .fontSize(13)
          .fontColor(e.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
          .fontWeight(e.isMe ? FontWeight.Bold : FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(e.dept)
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(`${e.km} km`)
        .fontSize(14)
        .fontColor(e.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 12, right: 12 })
    .margin({ bottom: 6 })
    .backgroundColor(e.isMe ? 'rgba(49,208,127,0.10)' : 'rgba(255,255,255,0.04)')
    .borderRadius(14)
    .border({
      width: 1,
      color: e.isMe ? 'rgba(49,208,127,0.45)' : Theme.CARD_STROKE
    })
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
        Text('排行榜')
          .fontSize(18)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(`我的名次 #${this.myRank}`)
          .fontSize(12)
          .fontColor(Theme.ORANGE)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Scroll() {
        Row({ space: 8 }) {
          ForEach(SCOPE_TABS, (meta: ScopeMeta) => {
            this.scopeChip(meta)
          }, (meta: ScopeMeta) => `${meta.label}_${this.boardScope === meta.scope ? 1 : 0}`)
        }
        .padding({ left: 2, right: 2 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')

      Text('🏅 前三名颁发金银铜徽章 · 我的条目绿色高亮')
        .fontSize(10)
        .fontColor(Theme.TEXT_SUB)
        .width('100%')

      Scroll() {
        Column({ space: 2 }) {
          ForEach(this.board, (e: LeaderEntry, idx: number) => {
            this.boardRow(e, idx + 1)
          }, (e: LeaderEntry) => `${this.scopeLabel()}_${e.name}_${e.km}_${e.isMe}`)

          Text('📡 运动完成即自动入榜（Local-First 先落盘后上榜）· 成就与里程经软总线同步所有组网设备')
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 16 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
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
