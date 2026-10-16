/**
 * 脉动光谷 - AI 计划制定（对话定制一周训练计划）
 * 与 AI 健身教练对话：说出目标/部位/天数/器械/水平需求，
 * AI 自动生成一周训练计划并同步到健身页「AI 本周训练计划」
 */
import { common } from '@kit.AbilityKit'
import { AiChatMessage } from '../common/Types'
import { StoreService } from '../service/StoreService'
import { AiCoach } from '../service/AiCoach'
import { Theme } from '../common/Theme'

const CHAT_PRESETS: string[] = ['增肌，一周练5天', '减脂，多安排有氧', '一周练4天', '新手徒手入门', '周三练核心', '周五休息']

@Entry
@Component
struct WeekPlanChatPage {
  @State messages: AiChatMessage[] = []
  @State input: string = ''
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    StoreService.getInstance().init(context)
    if (this.messages.length === 0) {
      this.messages = [AiCoach.greetWeekPlan()]
    }
  }

  private send(text: string): void {
    const t: string = text.trim()
    if (t === '') {
      return
    }
    const userMsg: AiChatMessage = AiChatMessage.of('user', t, Date.now())
    this.messages.push(userMsg)
    this.messages = this.messages.slice()
    this.input = ''
    const reply = AiCoach.weekPlanChatReply(t)
    this.messages.push(AiChatMessage.of('ai', reply.text, Date.now()))
    this.messages = this.messages.slice()
    if (reply.plan !== undefined) {
      StoreService.getInstance().saveAiWeekPlan(reply.plan)
      try {
        this.getUIContext().getPromptAction().showToast({ message: '本周计划已保存，回到「我的」页即可查看 ✅' })
      } catch (e) {
        console.error('[WeekPlanChatPage] showToast failed')
      }
    }
    // 滚动到最新消息
    setTimeout((): void => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 80)
  }

  @Builder
  chatBubble(msg: AiChatMessage) {
    Row({ space: 8 }) {
      if (msg.role === 'user') {
        Blank()
      }
      Column({ space: 4 }) {
        Text(msg.role === 'user' ? '我' : '🤖 AI 教练')
          .fontSize(9)
          .fontColor(Theme.TEXT_SUB)
        Text(msg.text)
          .fontSize(13)
          .fontColor(Theme.TEXT_MAIN)
          .lineHeight(19)
      }
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(msg.role === 'user' ? 'rgba(139,92,246,0.22)' : Theme.CARD_BG)
      .borderRadius(14)
      .constraintSize({ maxWidth: '78%' })
      .alignItems(HorizontalAlign.Start)
      if (msg.role !== 'user') {
        Blank()
      }
    }
    .width('100%')
  }

  build() {
    Column({ space: 10 }) {
      // 标题栏
      Row({ space: 10 }) {
        Text('‹')
          .fontSize(24)
          .fontColor(Theme.TEXT_MAIN)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('AI 计划制定')
          .fontSize(20)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('定制一周训练计划')
          .fontSize(11)
          .fontColor(Theme.PURPLE)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 })

      // 对话区
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          ForEach(this.messages, (msg: AiChatMessage) => {
            this.chatBubble(msg)
          }, (msg: AiChatMessage) => `${msg.ts}_${msg.role}`)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)

      // 快捷需求
      Scroll() {
        Row({ space: 6 }) {
          ForEach(CHAT_PRESETS, (preset: string) => {
            Text(preset)
              .fontSize(11)
              .fontColor(Theme.TEXT_SUB)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(Theme.CARD_BG)
              .borderRadius(13)
              .border({ width: 1, color: Theme.CARD_STROKE })
              .onClick(() => {
                this.send(preset)
              })
          }, (preset: string) => preset)
        }
        .padding({ left: 14, right: 14 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      // 输入区
      Row({ space: 8 }) {
        TextInput({ placeholder: '告诉 AI 你的训练需求…', text: this.input })
          .onChange((value: string) => {
            this.input = value
          })
          .layoutWeight(1)
          .height(44)
          .fontSize(13)
          .fontColor(Theme.TEXT_MAIN)
          .backgroundColor(Theme.CARD_BG)
          .borderRadius(14)
        Button('发送')
          .height(44)
          .padding({ left: 18, right: 18 })
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Theme.PURPLE)
          .fontColor('#FFFFFF')
          .borderRadius(14)
          .onClick(() => {
            this.send(this.input)
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 4, bottom: 14 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[Theme.BG_TOP, 0.0], [Theme.BG_BOTTOM, 1.0]]
    })
  }
}
