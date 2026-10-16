/**
 * 脉动光谷 - 社区页（Tab3）
 * 大学社区：微博式图文发布 + 分享/转发运动记录（AI 生成总结文案） + 跑友交友 + 动态再挑战 + 校友圈
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  AlumniUser, CampusInfo, CommunityPost, CommunityUser, LeaderEntry, SportRecord
} from '../common/Types'
import { CommunityService } from '../service/CommunityService'
import { StoreService } from '../service/StoreService'
import { AiCoach } from '../service/AiCoach'
import { CampusService } from '../service/CampusService'
import { Theme } from '../common/Theme'
import { FormatUtils } from '../common/FormatUtils'
import { RunningParams } from '../model/RouteParams'

/** 话题标签（选中态切换，纯前端演示） */
const TOPIC_TAGS: string[] = ['#环湖夜跑', '#操场打卡', '#绿道骑行', '#接力加油', '#晨跑联盟']

@Component
export struct CommunityTab {
  @State posts: CommunityPost[] = []
  @State runners: CommunityUser[] = []
  @State friends: CommunityUser[] = []
  @State myRecords: SportRecord[] = []
  @State sharedIds: string[] = []
  @State publishText: string = ''
  @State publishImages: string[] = []
  // 校友圈
  @State campusInfo: CampusInfo = new CampusInfo()
  @State inputSchool: string = ''
  @State inputStudentId: string = ''
  @State inputStudentName: string = ''
  @State alumni: AlumniUser[] = []
  @State campusBoardEntries: LeaderEntry[] = []
  @State selectedTopic: string = TOPIC_TAGS[0]

  aboutToAppear(): void {
    this.reload()
  }

  reload(): void {
    this.posts = CommunityService.listPosts()
    this.runners = CommunityService.listRunners()
    this.friends = CommunityService.listFriends()
    this.sharedIds = CommunityService.listSharedRecordIds()
    const records: SportRecord[] = StoreService.getInstance().getRecords()
    const top: SportRecord[] = []
    const max: number = Math.min(records.length, 5)
    for (let i = 0; i < max; i++) {
      top.push(records[i])
    }
    this.myRecords = top
    this.campusInfo = CampusService.getInfo()
    this.inputSchool = this.campusInfo.school
    if (CampusService.isBound()) {
      this.alumni = CampusService.listAlumni()
      this.campusBoardEntries = CampusService.campusBoard()
    } else {
      this.alumni = []
      this.campusBoardEntries = []
    }
  }

  toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg })
    } catch (e) {
      console.error('[CommunityTab] showToast failed')
    }
  }

  /** 选择图片（最多 3 张，系统相册选择器） */
  private pickImages(): void {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 3
      }).then((result: photoAccessHelper.PhotoSelectResult): void => {
        if (result.photoUris !== undefined && result.photoUris.length > 0) {
          this.publishImages = result.photoUris
        }
      }).catch((e: BusinessError): void => {
        console.error(`[Community] pick images failed: ${e.message}`)
      })
    } catch (e) {
      this.toast('相册选择器不可用')
    }
  }

  /** 发布图文动态（微博式） */
  private doPublish(): void {
    if (this.publishText === '' && this.publishImages.length === 0) {
      this.toast('说点什么或选择一张图片吧')
      return
    }
    const ok: boolean = CommunityService.publishMoment(this.publishText, this.publishImages)
    if (ok) {
      this.publishText = ''
      this.publishImages = []
      this.reload()
      this.toast('动态已发布 🎉')
    }
  }

  /** 绑定校园 */
  private doBind(): void {
    const err: string = CampusService.bind(this.inputSchool, this.inputStudentId, this.inputStudentName)
    if (err !== '') {
      this.toast(err)
      return
    }
    this.reload()
    this.toast(`校园绑定成功！欢迎加入 ${this.campusInfo.school} 校友圈 🎓`)
  }

  @Builder
  friendChip(user: CommunityUser) {
    Row({ space: 6 }) {
      Text(user.avatar)
        .fontSize(18)
      Text(user.name)
        .fontSize(12)
        .fontColor(Theme.TEXT_MAIN)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(16)
    .border({ width: 1, color: Theme.CARD_STROKE })
    .margin({ right: 8, bottom: 8 })
  }

  @Builder
  runnerRow(user: CommunityUser) {
    Row({ space: 12 }) {
      Text(user.avatar)
        .fontSize(26)
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(user.name)
            .fontSize(14)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Medium)
          Text(`Lv${user.level}`)
            .fontSize(10)
            .fontColor(Theme.BLUE)
        }
        Text(user.bio)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`本周 ${user.weeklyKm} km`)
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button('加好友')
        .height(32)
        .fontSize(12)
        .backgroundColor(Theme.GREEN)
        .fontColor('#06281A')
        .borderRadius(14)
        .onClick(() => {
          CommunityService.addFriend(user.id)
          this.reload()
          this.toast(`已和 ${user.name} 成为好友，一起去运动吧`)
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
  }

  @Builder
  shareRow(record: SportRecord) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(`${FormatUtils.sportNameOf(record.type)} · ${FormatUtils.kmOf(record.distanceM)} km`)
          .fontSize(13)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Medium)
        Text(`${FormatUtils.dateKeyOf(record.startTs)} · ${FormatUtils.paceOf(record.paceSecPerKm)}/km · ${record.calorie} kcal`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.sharedIds.indexOf(record.id) >= 0) {
        Button('已分享')
          .height(32)
          .fontSize(12)
          .backgroundColor(Theme.CARD_BG)
          .fontColor(Theme.TEXT_SUB)
          .borderRadius(14)
      } else {
        Button('AI 分享')
          .height(32)
          .fontSize(12)
          .backgroundColor(Theme.GREEN)
          .fontColor('#06281A')
          .borderRadius(14)
          .onClick(() => {
            // AI 生成个性化总结文案并分享进社区
            const copy: string = AiCoach.shareCopyOf(record, record.distanceM / 1000)
            CommunityService.shareMyRecord(record.id, `🤖 ${copy}`)
            this.reload()
            this.toast('AI 已生成总结动态并分享到社区 🎉')
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
  }

  @Builder
  postCard(post: CommunityPost) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text(post.authorAvatar)
          .fontSize(24)
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(post.authorName)
              .fontSize(14)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            if (post.repostOf !== '') {
              Text('转发')
                .fontSize(9)
                .fontColor(Theme.BLUE)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor('rgba(77,141,255,0.15)')
                .borderRadius(8)
            }
          }
          Text(`${FormatUtils.dateKeyOf(post.startTs)} ${FormatUtils.timeOf(post.startTs)}`)
            .fontSize(10)
            .fontColor(Theme.TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (post.isMe) {
          Text('我')
            .fontSize(10)
            .fontColor(Theme.GREEN)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('rgba(52,199,123,0.15)')
            .borderRadius(8)
        }
      }
      .width('100%')

      Text(post.content)
        .fontSize(13)
        .fontColor(Theme.TEXT_MAIN)
        .width('100%')

      // 图文动态附带的图片（九宫格）
      if (post.images.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(post.images, (uri: string) => {
            Image(uri)
              .width(92)
              .height(92)
              .objectFit(ImageFit.Cover)
              .borderRadius(10)
              .margin({ right: 6, bottom: 6 })
          }, (uri: string) => uri)
        }
        .width('100%')
      }

      // AI 总结标识 + 路线地图示意
      if (post.fromMyRecord && post.content.indexOf('🤖') === 0) {
        Row({ space: 8 }) {
          Text('🤖 AI 训练总结')
            .fontSize(10)
            .fontColor(Theme.PURPLE)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(139,92,246,0.14)')
            .borderRadius(10)
          Text('📍 路线地图已附')
            .fontSize(10)
            .fontColor(Theme.BLUE)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(77,141,255,0.12)')
            .borderRadius(10)
        }
        .width('100%')
      }

      if (post.kind === 'record') {
        Row({ space: 14 }) {
          Text(`📍 ${FormatUtils.kmOf(post.distanceM)} km`)
            .fontSize(12)
            .fontColor(Theme.GREEN)
            .fontWeight(FontWeight.Bold)
          Text(`⏱ ${FormatUtils.durationOf(post.durationS)}`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
          Text(`⚡ ${FormatUtils.paceOf(post.paceSecPerKm)}/km`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
          Text(`🔥 ${post.calorie} kcal`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
      }

      Row({ space: 12 }) {
        Button(post.likedByMe ? `❤️ 已赞 ${post.likes}` : `🤍 点赞 ${post.likes}`)
          .height(34)
          .fontSize(12)
          .backgroundColor(post.likedByMe ? 'rgba(232,64,74,0.18)' : Theme.CARD_BG)
          .fontColor(post.likedByMe ? Theme.RED : Theme.TEXT_MAIN)
          .borderRadius(17)
          .onClick(() => {
            CommunityService.toggleLike(post.id)
            this.reload()
          })
        if (post.repostOf === '') {
          Button(post.forwardedByMe ? `🔁 已转发 ${post.forwards}` : `🔁 转发 ${post.forwards}`)
            .height(34)
            .fontSize(12)
            .backgroundColor(post.forwardedByMe ? 'rgba(52,199,123,0.18)' : Theme.CARD_BG)
            .fontColor(post.forwardedByMe ? Theme.GREEN : Theme.TEXT_MAIN)
            .borderRadius(17)
            .onClick(() => {
              if (CommunityService.forward(post.id)) {
                this.reload()
                this.toast(`已转发 @${post.authorName} 的运动记录`)
              }
            })
        }
        Button('⚡ 再挑战')
          .height(34)
          .fontSize(12)
          .backgroundColor('rgba(245,166,35,0.16)')
          .fontColor(Theme.ORANGE)
          .borderRadius(17)
          .onClick(() => {
            const p: RunningParams = { type: post.sportType === 1 ? 1 : (post.sportType === 2 ? 2 : 0) }
            this.getUIContext().getRouter().pushUrl({ url: 'pages/RunningPage', params: p })
          })
        Blank()
        Text('脉动光谷大学社区')
          .fontSize(10)
          .fontColor(Theme.TEXT_SUB)
      }
      .width('100%')
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  publishBox() {
    Column({ space: 10 }) {
      TextArea({ text: this.publishText, placeholder: '分享此刻运动心情，打卡今日训练…' })
        .fontSize(13)
        .fontColor(Theme.TEXT_MAIN)
        .placeholderColor(Theme.TEXT_SUB)
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(12)
        .constraintSize({ maxHeight: 110 })
        .width('100%')
        .onChange((value: string) => {
          this.publishText = value
        })

      if (this.publishImages.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.publishImages, (uri: string) => {
            Stack({ alignContent: Alignment.TopEnd }) {
              Image(uri)
                .width(76)
                .height(76)
                .objectFit(ImageFit.Cover)
                .borderRadius(10)
              Text('✕')
                .fontSize(11)
                .fontColor('#FFFFFF')
                .padding(4)
                .backgroundColor('rgba(0,0,0,0.55)')
                .borderRadius(10)
                .margin(4)
                .onClick(() => {
                  const next: string[] = []
                  for (let i = 0; i < this.publishImages.length; i++) {
                    if (this.publishImages[i] !== uri) {
                      next.push(this.publishImages[i])
                    }
                  }
                  this.publishImages = next
                })
            }
            .margin({ right: 6, bottom: 6 })
          }, (uri: string) => uri)
        }
        .width('100%')
      }

      Row({ space: 10 }) {
        Button('🖼 选择图片')
          .height(38)
          .fontSize(13)
          .backgroundColor(Theme.CARD_BG)
          .fontColor(Theme.TEXT_MAIN)
          .borderRadius(19)
          .onClick(() => {
            this.pickImages()
          })
        Blank()
        Text(`${this.publishText.length}/500`)
          .fontSize(11)
          .fontColor(Theme.TEXT_SUB)
        Button('发布')
          .height(38)
          .fontSize(13)
          .backgroundColor(Theme.GREEN)
          .fontColor('#06281A')
          .fontWeight(FontWeight.Bold)
          .borderRadius(19)
          .padding({ left: 22, right: 22 })
          .onClick(() => {
            this.doPublish()
          })
      }
      .width('100%')
    }
    .padding(12)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  @Builder
  campusSection() {
    Column({ space: 12 }) {
      Row() {
        Text('🎓 校友圈')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(CampusService.isBound() ? `${this.campusInfo.school} · 已绑定` : '未绑定')
          .fontSize(11)
          .fontColor(CampusService.isBound() ? Theme.GREEN : Theme.TEXT_SUB)
      }
      .width('100%')

      if (!CampusService.isBound()) {
        Column({ space: 10 }) {
          Text('绑定校园后可查看校友、参与校园运动榜')
            .fontSize(11)
            .fontColor(Theme.TEXT_SUB)
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(CampusService.schools(), (school: string) => {
              Text(school)
                .fontSize(11)
                .fontColor(this.inputSchool === school ? '#06281A' : Theme.TEXT_MAIN)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor(this.inputSchool === school ? Theme.GREEN : 'rgba(255,255,255,0.06)')
                .borderRadius(12)
                .margin({ right: 6, bottom: 6 })
                .onClick(() => {
                  this.inputSchool = school
                })
            }, (school: string) => `${school}_${this.inputSchool === school ? 1 : 0}`)
          }
          .width('100%')

          TextInput({ placeholder: '姓名' })
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .placeholderColor(Theme.TEXT_SUB)
            .backgroundColor('rgba(255,255,255,0.05)')
            .borderRadius(12)
            .height(42)
            .width('100%')
            .onChange((value: string) => {
              this.inputStudentName = value
            })
          TextInput({ placeholder: '学号（6-12 位）' })
            .fontSize(13)
            .fontColor(Theme.TEXT_MAIN)
            .placeholderColor(Theme.TEXT_SUB)
            .backgroundColor('rgba(255,255,255,0.05)')
            .borderRadius(12)
            .height(42)
            .width('100%')
            .type(InputType.Number)
            .onChange((value: string) => {
              this.inputStudentId = value
            })
          Button('绑定校园')
            .width('100%')
            .height(42)
            .backgroundColor(Theme.GREEN)
            .fontColor('#06281A')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .borderRadius(21)
            .onClick(() => {
              this.doBind()
            })
        }
        .width('100%')
      } else {
        Text(`🎓 ${this.campusInfo.school} · ${CampusService.sameSchoolCount()} 位同校校友 · 校园运动榜`)
          .fontSize(11)
          .fontColor(Theme.PURPLE)
          .width('100%')

        ForEach(this.campusBoardEntries, (e: LeaderEntry, idx: number) => {
          Row({ space: 10 }) {
            Text(rankMedalOf(idx))
              .fontSize(13)
              .width(22)
            Text(e.avatar)
              .fontSize(15)
            Column({ space: 1 }) {
              Text(e.name + (e.isMe ? '（我）' : ''))
                .fontSize(12)
                .fontColor(e.isMe ? Theme.GREEN : Theme.TEXT_MAIN)
                .fontWeight(e.isMe ? FontWeight.Bold : FontWeight.Normal)
              Text(e.dept)
                .fontSize(9)
                .fontColor(Theme.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text(`${e.km} km`)
              .fontSize(12)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding({ top: 5, bottom: 5 })
          .onClick(() => {
            this.toast(`${e.avatar} ${e.name} · ${e.dept} · 本周 ${e.km} km`)
          })
        }, (e: LeaderEntry) => `${e.name}_${e.km}_${e.isMe}`)

        Button('解除绑定')
          .height(34)
          .fontSize(12)
          .backgroundColor(Theme.CARD_BG)
          .fontColor(Theme.TEXT_SUB)
          .borderRadius(17)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            CampusService.unbind()
            this.reload()
            this.toast('已解除校园绑定')
          })
      }
    }
    .padding(14)
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.RADIUS_CARD)
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Column() {
            Text('运动社区')
              .fontSize(22)
              .fontColor(Theme.TEXT_MAIN)
              .fontWeight(FontWeight.Bold)
            Text('大学社区 · 分享运动 · 结交跑友')
              .fontSize(12)
              .fontColor(Theme.TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('💬')
            .fontSize(28)
        }
        .width('100%')

        Scroll() {
          Row({ space: 8 }) {
            ForEach(TOPIC_TAGS, (topic: string) => {
              Text(topic)
                .fontSize(12)
                .fontColor(this.selectedTopic === topic ? '#06281A' : Theme.TEXT_MAIN)
                .fontWeight(this.selectedTopic === topic ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.selectedTopic === topic ? Theme.GREEN : Theme.CARD_BG)
                .borderRadius(14)
                .border({
                  width: 1,
                  color: this.selectedTopic === topic ? Theme.GREEN : Theme.CARD_STROKE
                })
                .onClick(() => {
                  this.selectedTopic = topic
                })
            }, (topic: string) => `${topic}_${this.selectedTopic === topic ? 1 : 0}`)
          }
          .padding({ left: 2, right: 2 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')

        this.publishBox()

        Row() {
          Text('👥 我的好友')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(`${this.friends.length} 位`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')

        if (this.friends.length === 0) {
          Text('还没有好友，到下方推荐区认识校园跑友吧')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        } else {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.friends, (user: CommunityUser) => {
              this.friendChip(user)
            }, (user: CommunityUser) => user.id)
          }
          .width('100%')
        }

        Text('🔥 校园跑友推荐')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        if (this.runners.length === 0) {
          Text('校园跑友都已认识，去挑战页发起挑战吧')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        ForEach(this.runners, (user: CommunityUser) => {
          this.runnerRow(user)
        }, (user: CommunityUser) => user.id + (user.isFriend ? '1' : '0'))

        Text('📤 分享我的运动记录')
          .fontSize(15)
          .fontColor(Theme.TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        if (this.myRecords.length === 0) {
          Text('还没有运动记录，先去运动页完成一次打卡吧')
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
            .padding({ top: 8, bottom: 8 })
        }
        ForEach(this.myRecords, (record: SportRecord) => {
          this.shareRow(record)
        }, (record: SportRecord) => record.id + (this.sharedIds.indexOf(record.id) >= 0 ? '_s' : '_n'))

        Row() {
          Text('🏘️ 校园动态')
            .fontSize(15)
            .fontColor(Theme.TEXT_MAIN)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text(`${this.posts.length} 条`)
            .fontSize(12)
            .fontColor(Theme.TEXT_SUB)
        }
        .width('100%')
        ForEach(this.posts, (post: CommunityPost) => {
          this.postCard(post)
        }, (post: CommunityPost) =>
        `${post.id}_${post.likedByMe ? 1 : 0}${post.forwardedByMe ? 1 : 0}_${post.likes}_${post.forwards}`)

        this.campusSection()
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

/** 校园榜前三名奖牌 */
function rankMedalOf(idx: number): string {
  if (idx === 0) {
    return '🥇'
  }
  if (idx === 1) {
    return '🥈'
  }
  if (idx === 2) {
    return '🥉'
  }
  return `${idx + 1}`
}
