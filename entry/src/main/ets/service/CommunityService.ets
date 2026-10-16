/**
 * 脉动光谷 - 大学社区服务（M5 社交）
 * 运动记录分享/转发 + 跑友交友（Local-First 演示版；生产接校园社区云服务）
 */
import { CommunityPost, CommunityUser, SportRecord, SportType } from '../common/Types'
import { StoreService } from './StoreService'
import { FormatUtils } from '../common/FormatUtils'

interface CommunityState {
  friends: string[]
  likedIds: string[]
  forwardedIds: string[]
  sharedRecordIds: string[]
  aiContents: Record<string, string>
  /** 我发布的图文动态（微博式），JSON 数组：[{id, text, images, ts}] */
  moments: string
}

/** 图文动态持久化条目 */
interface MomentItem {
  id: string
  text: string
  images: string[]
  ts: number
}

export class CommunityService {
  private static inited: boolean = false
  private static users: CommunityUser[] = []
  private static seedPosts: CommunityPost[] = []
  private static state: CommunityState = {
    friends: [],
    likedIds: [],
    forwardedIds: [],
    sharedRecordIds: [],
    aiContents: { 'k': '' },
    moments: '[]'
  }

  /** 首次启动播种校园用户与动态，并恢复本地社交状态 */
  static ensureSeeded(): void {
    if (CommunityService.inited) {
      return
    }
    CommunityService.inited = true
    const stats = StoreService.getInstance().getUserStats()
    const me: CommunityUser = CommunityUser.of('me', '我', '🏃', '脉动光谷跑者', stats.level, stats.totalKm, true)
    CommunityService.users = [
      me,
      CommunityUser.of('u_kaikai', '阿凯', '🏃', '环湖跑团团长 · 夜跑爱好者', 5, 28.4, false),
      CommunityUser.of('u_xiaoman', '小曼', '🧘', '瑜伽+慢跑 · 操场常客', 4, 21.7, false),
      CommunityUser.of('u_dachuan', '大川', '🚴', '骑行党 · 光谷绿道刷圈', 6, 65.2, false),
      CommunityUser.of('u_lulu', '露露', '🎧', '配速6分30秒 · 音乐跑者', 3, 15.9, false),
      CommunityUser.of('u_laozhou', '老周', '🏃', '晨跑打卡 365 天', 5, 32.1, false)
    ]
    CommunityService.seedPosts = CommunityService.buildSeedPosts()
    CommunityService.state = CommunityService.parseState(StoreService.getInstance().getCommunityState())
    for (let i = 0; i < CommunityService.users.length; i++) {
      CommunityService.users[i].isFriend = CommunityService.state.friends.indexOf(CommunityService.users[i].id) >= 0
    }
  }

  private static buildSeedPosts(): CommunityPost[] {
    const now: number = Date.now()
    const hour: number = 3600 * 1000
    const minute: number = 60 * 1000
    const r1: SportRecord = SportRecord.of('sp_1', SportType.RUN, now - 5 * hour, now - 5 * hour + 31 * minute,
      5200, 31 * 60, 5830, 323, 358, 52)
    const p1: CommunityPost = CommunityPost.of('sp_1', CommunityService.users[1],
      '今晚环湖线风小体感佳，配速稳住了 ✌️', r1)
    const r2: SportRecord = SportRecord.of('sp_2', SportType.WALK, now - 9 * hour, now - 9 * hour + 38 * minute,
      3100, 38 * 60, 4400, 130, 735, 0)
    const p2: CommunityPost = CommunityPost.of('sp_2', CommunityService.users[2],
      '晚饭后操场健走三圈，消食又放松 🌿', r2)
    const r3: SportRecord = SportRecord.of('sp_3', SportType.RIDE, now - 26 * hour, now - 26 * hour + 47 * minute,
      18600, 47 * 60, 0, 446, 151, 120)
    const p3: CommunityPost = CommunityPost.of('sp_3', CommunityService.users[3],
      '光谷绿道骑行打卡，18 公里到底！🚴', r3)
    const r4: SportRecord = SportRecord.of('sp_4', SportType.RUN, now - 30 * hour, now - 30 * hour + 26 * minute,
      4000, 26 * 60, 4500, 249, 390, 40)
    const p4: CommunityPost = CommunityPost.of('sp_4', CommunityService.users[4],
      '戴着新歌单跑操场，四公里不知不觉就完成了 🎧', r4)
    const r5: SportRecord = SportRecord.of('sp_5', SportType.RUN, now - 49 * hour, now - 49 * hour + 40 * minute,
      6800, 40 * 60, 7600, 422, 353, 61)
    const p5: CommunityPost = CommunityPost.of('sp_5', CommunityService.users[5],
      '晨跑第 365 天，风雨无阻，一起坚持 🌅', r5)
    const posts: CommunityPost[] = [p1, p2, p3, p4, p5]
    const baseLikes: number[] = [23, 12, 31, 8, 46]
    const baseForwards: number[] = [4, 1, 7, 0, 9]
    for (let i = 0; i < posts.length; i++) {
      posts[i].baseLikes = baseLikes[i]
      posts[i].baseForwards = baseForwards[i]
      posts[i].likes = baseLikes[i]
      posts[i].forwards = baseForwards[i]
    }
    return posts
  }

  private static parseState(raw: string): CommunityState {
    const state: CommunityState = {
      friends: [], likedIds: [], forwardedIds: [], sharedRecordIds: [], aiContents: { 'k': '' }, moments: '[]'
    }
    if (raw === '') {
      return state
    }
    try {
      const o: Record<string, Object> = JSON.parse(raw) as Record<string, Object>
      state.friends = (o['friends'] ?? []) as string[]
      state.likedIds = (o['likedIds'] ?? []) as string[]
      state.forwardedIds = (o['forwardedIds'] ?? []) as string[]
      state.sharedRecordIds = (o['sharedRecordIds'] ?? []) as string[]
      state.aiContents = (o['aiContents'] ?? { 'k': '' }) as Record<string, string>
      state.moments = (o['moments'] ?? '[]') as string
    } catch (e) {
      // 数据损坏时回退为空状态
    }
    return state
  }

  private static persist(): void {
    StoreService.getInstance().saveCommunityState(JSON.stringify(CommunityService.state))
  }

  /** ---------- 好友 ---------- */

  static listFriends(): CommunityUser[] {
    CommunityService.ensureSeeded()
    const list: CommunityUser[] = []
    for (let i = 0; i < CommunityService.users.length; i++) {
      if (CommunityService.users[i].isFriend) {
        list.push(CommunityService.users[i])
      }
    }
    return list
  }

  /** 推荐跑友：非我、非好友 */
  static listRunners(): CommunityUser[] {
    CommunityService.ensureSeeded()
    const list: CommunityUser[] = []
    for (let i = 0; i < CommunityService.users.length; i++) {
      const u: CommunityUser = CommunityService.users[i]
      if (!u.isMe && !u.isFriend) {
        list.push(u)
      }
    }
    return list
  }

  static addFriend(userId: string): void {
    CommunityService.ensureSeeded()
    if (CommunityService.state.friends.indexOf(userId) >= 0) {
      return
    }
    CommunityService.state.friends.unshift(userId)
    CommunityService.persist()
    for (let i = 0; i < CommunityService.users.length; i++) {
      if (CommunityService.users[i].id === userId) {
        CommunityService.users[i].isFriend = true
      }
    }
  }

  /** ---------- 我的运动记录分享 ---------- */

  static listSharedRecordIds(): string[] {
    CommunityService.ensureSeeded()
    return CommunityService.state.sharedRecordIds
  }

  static isRecordShared(recordId: string): boolean {
    CommunityService.ensureSeeded()
    return CommunityService.state.sharedRecordIds.indexOf(recordId) >= 0
  }

  /**
   * 把我的一条运动记录分享进社区动态
   * aiContent：AI 生成的专属总结文案（大模型赛后深度分析），为空则用默认文案
   */
  static shareMyRecord(recordId: string, aiContent?: string): void {
    CommunityService.ensureSeeded()
    if (CommunityService.state.sharedRecordIds.indexOf(recordId) >= 0) {
      return
    }
    CommunityService.state.sharedRecordIds.unshift(recordId)
    if (aiContent !== undefined && aiContent !== '') {
      CommunityService.state.aiContents[recordId] = aiContent
    }
    CommunityService.persist()
  }

  /** ---------- 微博式图文动态发布 ---------- */

  /** 发布一条图文动态（可带图片，类似微博），返回是否成功 */
  static publishMoment(text: string, images: string[]): boolean {
    CommunityService.ensureSeeded()
    if (text === '' && images.length === 0) {
      return false
    }
    const item: MomentItem = {
      id: `mom_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      text: text,
      images: images,
      ts: Date.now()
    }
    const list: MomentItem[] = CommunityService.parseMoments()
    list.unshift(item)
    if (list.length > 50) {
      list.splice(50, list.length - 50)
    }
    CommunityService.state.moments = JSON.stringify(list)
    CommunityService.persist()
    return true
  }

  private static parseMoments(): MomentItem[] {
    try {
      const arr: object[] = JSON.parse(CommunityService.state.moments) as object[]
      const list: MomentItem[] = []
      for (let i = 0; i < arr.length; i++) {
        const o: Record<string, Object> = arr[i] as Record<string, Object>
        const images: string[] = (o['images'] ?? []) as string[]
        list.push({
          id: (o['id'] ?? '') as string,
          text: (o['text'] ?? '') as string,
          images: images,
          ts: (o['ts'] ?? 0) as number
        })
      }
      return list
    } catch (e) {
      return []
    }
  }

  /** 把已发布动态转为社区帖子（kind='moment'） */
  private static buildMomentPost(item: MomentItem, me: CommunityUser): CommunityPost {
    const p: CommunityPost = new CommunityPost()
    p.id = item.id
    p.authorId = me.id
    p.authorName = me.name
    p.authorAvatar = me.avatar
    p.isMe = true
    p.content = item.text !== '' ? item.text : '分享了图片'
    p.startTs = item.ts
    p.kind = 'moment'
    p.images = item.images
    p.likedByMe = CommunityService.state.likedIds.indexOf(p.id) >= 0
    p.likes = p.likedByMe ? 1 : 0
    return p
  }

  /** ---------- 动态：点赞 / 转发 ---------- */

  static toggleLike(postId: string): void {
    CommunityService.ensureSeeded()
    const idx: number = CommunityService.state.likedIds.indexOf(postId)
    if (idx >= 0) {
      CommunityService.state.likedIds.splice(idx, 1)
    } else {
      CommunityService.state.likedIds.unshift(postId)
    }
    CommunityService.persist()
  }

  /** 转发一条动态（以"我"的名义生成转发条目），返回是否成功 */
  static forward(postId: string): boolean {
    CommunityService.ensureSeeded()
    if (CommunityService.state.forwardedIds.indexOf(postId) >= 0) {
      return false
    }
    const posts: CommunityPost[] = CommunityService.listPosts()
    for (let i = 0; i < posts.length; i++) {
      if (posts[i].id === postId && posts[i].repostOf === '') {
        CommunityService.state.forwardedIds.unshift(postId)
        CommunityService.persist()
        return true
      }
    }
    return false
  }

  /** 动态列表：我发布的图文动态 + 我的转发 + 我的分享 + 校园种子动态 */
  static listPosts(): CommunityPost[] {
    CommunityService.ensureSeeded()
    const me: CommunityUser = CommunityService.users[0]
    const records: SportRecord[] = StoreService.getInstance().getRecords()
    const posts: CommunityPost[] = []

    // 我发布的图文动态（微博式，最新在前）
    const moments: MomentItem[] = CommunityService.parseMoments()
    for (let i = 0; i < moments.length; i++) {
      posts.push(CommunityService.buildMomentPost(moments[i], me))
    }
    // 我的转发（最新转发在前）
    for (let i = 0; i < CommunityService.state.forwardedIds.length; i++) {
      const origin: CommunityPost | undefined =
        CommunityService.findSeedOrShared(CommunityService.state.forwardedIds[i], records, me)
      if (origin !== undefined) {
        posts.push(CommunityService.cloneAsRepost(origin, me))
      }
    }
    // 我分享的运动记录（最新分享在前）
    for (let i = 0; i < CommunityService.state.sharedRecordIds.length; i++) {
      const recordId: string = CommunityService.state.sharedRecordIds[i]
      for (let j = 0; j < records.length; j++) {
        if (records[j].id === recordId) {
          posts.push(CommunityService.buildMyShare(records[j], me))
          break
        }
      }
    }
    // 校园种子动态
    for (let i = 0; i < CommunityService.seedPosts.length; i++) {
      const seed: CommunityPost = CommunityService.seedPosts[i]
      seed.likedByMe = CommunityService.state.likedIds.indexOf(seed.id) >= 0
      seed.forwardedByMe = CommunityService.state.forwardedIds.indexOf(seed.id) >= 0
      seed.likes = seed.baseLikes + (seed.likedByMe ? 1 : 0)
      seed.forwards = seed.baseForwards + (seed.forwardedByMe ? 1 : 0)
      posts.push(seed)
    }
    return posts
  }

  private static buildMyShare(record: SportRecord, me: CommunityUser): CommunityPost {
    const aiContent: string = CommunityService.state.aiContents[record.id] ?? ''
    const content: string = aiContent !== ''
      ? aiContent
      : `完成了${FormatUtils.sportNameOf(record.type)}打卡，累计 ${FormatUtils.kmOf(record.distanceM)} 公里，一起动起来！`
    const p: CommunityPost = CommunityPost.of(`share_${record.id}`, me, content, record)
    p.fromMyRecord = true
    p.likedByMe = CommunityService.state.likedIds.indexOf(p.id) >= 0
    p.likes = p.likedByMe ? 1 : 0
    return p
  }

  private static cloneAsRepost(origin: CommunityPost, me: CommunityUser): CommunityPost {
    const p: CommunityPost = new CommunityPost()
    p.id = `repost_${origin.id}`
    p.authorId = me.id
    p.authorName = me.name
    p.authorAvatar = me.avatar
    p.isMe = true
    p.content = `转发了 @${origin.authorName} 的${FormatUtils.sportNameOf(origin.sportType)}记录：${origin.content}`
    p.sportType = origin.sportType
    p.distanceM = origin.distanceM
    p.durationS = origin.durationS
    p.paceSecPerKm = origin.paceSecPerKm
    p.calorie = origin.calorie
    p.startTs = origin.startTs
    p.repostOf = origin.authorName
    p.likedByMe = CommunityService.state.likedIds.indexOf(p.id) >= 0
    p.likes = p.likedByMe ? 1 : 0
    return p
  }

  private static findSeedOrShared(postId: string, records: SportRecord[],
    me: CommunityUser): CommunityPost | undefined {
    for (let i = 0; i < CommunityService.seedPosts.length; i++) {
      if (CommunityService.seedPosts[i].id === postId) {
        return CommunityService.seedPosts[i]
      }
    }
    if (postId.indexOf('share_') === 0) {
      const recordId: string = postId.substring('share_'.length)
      for (let i = 0; i < records.length; i++) {
        if (records[i].id === recordId) {
          return CommunityService.buildMyShare(records[i], me)
        }
      }
    }
    return undefined
  }
}
