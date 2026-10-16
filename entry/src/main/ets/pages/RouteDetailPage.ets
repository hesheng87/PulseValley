/**
 * 脉动光谷 - 路线详情页（对应需求文档 8.2 路线详情）
 * 路线地图模拟（自绘）+ 起点/终点 + 关键点 + 安全提示 + 一键开始
 */
import { CampusRoute, EnvSnapshot, RouteRecommend, EnvGuardResult } from '../common/Types'
import { RouteScorer } from '../service/RouteScorer'
import { EnvService } from '../service/EnvService'
import { AiCoach } from '../service/AiCoach'
import { StoreService } from '../service/StoreService'
import { Theme } from '../common/Theme'
import { RouteDetailParams, RunningParams } from '../model/RouteParams'

@Entry
@Component
struct RouteDetailPage {
  @State route: CampusRoute = new CampusRoute()
  @State snap: EnvSnapshot = new EnvSnapshot()
  @State reason: string = ''
  @State narrative: string = ''
  @State found: boolean = false
  private mapCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true))

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as RouteDetailParams
    const routeId: string = params?.routeId ?? ''
    const routes: CampusRoute[] = RouteScorer.getRoutes()
    for (let i = 0; i < routes.length; i++) {
      if (routes[i].id === routeId) {
        this.route = routes[i]
        this.found = true
        break
      }
    }
    this.snap = EnvService.getInstance().getSnapshot()
    const recList: RouteRecommend[] = RouteScorer.recommend(this.snap,
      StoreService.getInstance().getUserStats().totalKm)
    for (let i = 0; i < recList.length; i++) {
      if (recList[i].route.id === routeId) {
        this.reason = recList[i].reason
        break
      }
    }
    this.narrative = AiCoach.narrateRoute(this.snap,
      StoreService.getInstance().getUserStats().totalKm, this.route.name)
  }

  private estimatedMinutes(): number {
    return Math.max(10, Math.round(this.route.baseKm * 6.5))
  }

  private difficultyText(): string {
    if (this.route.baseKm >= 4) {
      return '困难'
    }
    if (this.route.baseKm >= 3) {
      return '中等'
    }
    return '轻松'
  }

  private difficultyColor(): string {
    if (this.route.baseKm >= 4) {
      return Theme.RED
    }
    if (this.route.baseKm >= 3) {
      return Theme.ORANGE
    }
    return Theme.GREEN
  }

  private safetyTips(): string[] {
    const tips: string[] = []
    tips.push('夜跑注意路线照明，尽量结伴同行')
    tips.push('前 500 米控制节奏，充分热身后再提速')
    tips.push('沿途每公里有补给点，及时补水')
    if (this.snap.aqi > 100) {
      tips.push(`当前 AQI ${this.snap.aqi}，建议缩短运动时长`)
    }
    return tips
  }

  private startRun(): void {
    const guard: EnvGuardResult = EnvService.safetyCheck(this.snap)
    if (guard === EnvGuardResult.BLOCK) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: EnvService.indoorAdvice() })
      } catch (e) {
        console.error('[RouteDetailPage] showToast failed')
      }
      return
    }
    const p: RunningParams = { type: 0 }
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/RunningPage', params: p })
    } catch (e) {
      console.error('[RouteDetailPage] startRun failed')
    }
  }

  private drawMap(): void {
    const ctx: CanvasRenderingContext2D = this.mapCtx
    const w: number = ctx.width
    const h: number = ctx.height
    // 地图底色（深夜跑道）
    ctx.fillStyle = '#101820'
    ctx.fillRect(0, 0, w, h)
    // 网格街区
    ctx.strokeStyle = 'rgba(255,255,255,0.06)'
    ctx.lineWidth = 1
    for (let x = 0; x < w; x += 28) {
      ctx.beginPath()
      ctx.moveTo(x, 0)
      ctx.lineTo(x, h)
      ctx.stroke()
    }
    for (let y = 0; y < h; y += 28) {
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(w, y)
      ctx.stroke()
    }
    // 绿化带
    ctx.fillStyle = 'rgba(49,208,127,0.10)'
    ctx.fillRect(12, 12, 60, 44)
    ctx.fillRect(w - 80, h - 60, 62, 46)
    // 路线主体（脉动绿发光环线）
    const cx: number = w / 2
    const cy: number = h / 2
    const rx: number = w / 2 - 46
    const ry: number = h / 2 - 36
    ctx.strokeStyle = 'rgba(49,208,127,0.35)'
    ctx.lineWidth = 9
    ctx.beginPath()
    ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2)
    ctx.stroke()
    ctx.strokeStyle = Theme.GREEN
    ctx.lineWidth = 3
    ctx.beginPath()
    ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2)
    ctx.stroke()
    // 起点标记（右侧）
    const sx: number = cx + rx
    const sy: number = cy
    ctx.fillStyle = Theme.GREEN
    ctx.beginPath()
    ctx.arc(sx, sy, 8, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = '#06281A'
    ctx.font = 'bold 10px sans-serif'
    ctx.fillText('起', sx - 5, sy + 4)
    // 终点标记（与起点重合的环线，标记在上方）
    const ex: number = cx
    const ey: number = cy - ry
    ctx.fillStyle = Theme.ORANGE
    ctx.beginPath()
    ctx.arc(ex, ey, 8, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = '#3A1802'
    ctx.font = 'bold 10px sans-serif'
    ctx.fillText('终', ex - 5, ey + 4)
    // 补给点标记
    const wx: number = cx - rx
    const wy: number = cy
    ctx.fillStyle = Theme.BLUE
    ctx.beginPath()
    ctx.arc(wx, wy, 6, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = '#FFFFFF'
    ctx.font = '9px sans-serif'
    ctx.fillText('💧', wx - 6, wy + 22)
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
          Text('路线详情')
            .fontSize(20)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(`${this.route.baseKm} km`)
            .fontSize(14)
            .fontColor(Theme.GREEN)
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')

        if (this.found) {
          // 路线地图模拟（自绘环线：起终点 + 补给点）
          Column() {
            Canvas(this.mapCtx)
              .width('100%')
              .height(210)
              .onReady(() => {
                this.drawMap()
              })
            Row({ space: 12 }) {
              Row({ space: 4 }) {
                Column().width(8).height(8).borderRadius(4).backgroundColor(Theme.GREEN)
                Text('起点 · 校园南门')
                  .fontSize(10)
                  .fontColor(Theme.TEXT_SUB)
              }
              Row({ space: 4 }) {
                Column().width(8).height(8).borderRadius(4).backgroundColor(Theme.BLUE)
                Text('补给点')
                  .fontSize(10)
                  .fontColor(Theme.TEXT_SUB)
              }
              Row({ space: 4 }) {
                Column().width(8).height(8).borderRadius(4).backgroundColor(Theme.ORANGE)
                Text('终点 · 环线闭合')
                  .fontSize(10)
                  .fontColor(Theme.TEXT_SUB)
              }
            }
            .width('100%')
            .padding(10)
          }
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)
          .clip(true)

          Row({ space: 10 }) {
            Column() {
              Text(`${this.route.baseKm}`)
                .fontSize(26)
                .fontColor(Theme.GREEN)
                .fontWeight(FontWeight.Bold)
              Text('全程 km')
                .fontSize(10)
                .fontColor(Theme.TEXT_SUB)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            Column() {
              Text(`${this.estimatedMinutes()}`)
                .fontSize(26)
                .fontColor(Theme.BLUE)
                .fontWeight(FontWeight.Bold)
              Text('预计分钟')
                .fontSize(10)
                .fontColor(Theme.TEXT_SUB)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            Column() {
              Text(this.difficultyText())
                .fontSize(20)
                .fontColor(this.difficultyColor())
                .fontWeight(FontWeight.Bold)
              Text('难度')
                .fontSize(10)
                .fontColor(Theme.TEXT_SUB)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)

          Column({ space: 8 }) {
            Text(`📍 ${this.route.name}`)
              .fontSize(16)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            Text(this.route.desc)
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
              .width('100%')
            Text(`走向参考：${this.route.points}`)
              .fontSize(11)
              .fontColor(Theme.TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)

          Column({ space: 8 }) {
            Text('🤖 AI 推荐理由')
              .fontSize(14)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            if (this.reason !== '') {
              Text(this.reason)
                .fontSize(12)
                .fontColor(Theme.BLUE)
                .width('100%')
            }
            Text(this.narrative)
              .fontSize(12)
              .fontColor(Theme.PURPLE)
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)

          Column({ space: 8 }) {
            Text('🛡️ 安全提示')
              .fontSize(14)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            ForEach(this.safetyTips(), (tip: string) => {
              Row({ space: 8 }) {
                Text('•')
                  .fontSize(12)
                  .fontColor(Theme.WARNING)
                Text(tip)
                  .fontSize(12)
                  .fontColor(Theme.TEXT_MAIN)
                  .layoutWeight(1)
              }
              .width('100%')
            }, (tip: string) => tip)
            Text('本产品仅提供运动辅助建议，不构成医疗建议；如有身体不适应立即停止运动。')
              .fontSize(10)
              .fontColor(Theme.TEXT_SUB)
              .width('100%')
              .margin({ top: 4 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(Theme.RADIUS_CARD)

          Button('🏁 一键开始')
            .width('100%')
            .height(52)
            .backgroundColor(Theme.GREEN)
            .fontColor('#06281A')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .borderRadius(Theme.RADIUS_BTN)
            .margin({ top: 6, bottom: 30 })
            .onClick(() => {
              this.startRun()
            })
        } else {
          Text('未找到该路线，请返回重新选择')
            .fontSize(13)
            .fontColor(Theme.TEXT_SUB)
            .padding({ top: 40 })
        }
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
