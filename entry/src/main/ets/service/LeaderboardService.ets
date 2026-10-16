/**
 * 脉动光谷 - 排行榜服务（分布式成就与排行）
 * 好友榜 / 全校榜 / 班级榜 / 跨校榜 / 队伍榜：
 * 任意设备完成运动 → 里程立即并入榜单 → 经软总线同步所有设备
 * 演示版为种子榜单 + 我的真实累计里程实时插入排序
 */
import { Challenge, CommunityUser, LeaderEntry } from '../common/Types'
import { StoreService } from './StoreService'
import { CommunityService } from './CommunityService'
import { ChallengeService } from './ChallengeService'

export enum LeaderScope {
  FRIENDS = 0,
  CAMPUS = 1,
  CLASS = 2,
  SCHOOL = 3,
  TEAM = 4
}

export class LeaderboardService {
  /** 好友榜：好友种子里程 + 我的真实累计里程 */
  static friendBoard(): LeaderEntry[] {
    const myStats = StoreService.getInstance().getUserStats()
    const entries: LeaderEntry[] = []
    const friends: CommunityUser[] = CommunityService.listFriends()
    for (let i = 0; i < friends.length; i++) {
      entries.push(LeaderEntry.of(friends[i].name, friends[i].avatar,
        Math.round(friends[i].weeklyKm * 10) / 10, '本周里程', false))
    }
    entries.push(LeaderEntry.of('我', '🏃', Math.round(myStats.totalKm * 10) / 10, '累计里程', true))
    entries.sort((a: LeaderEntry, b: LeaderEntry): number => b.km - a.km)
    return entries
  }

  /** 全校榜：种子校园高手 + 我的真实累计里程 */
  static campusBoard(): LeaderEntry[] {
    const myStats = StoreService.getInstance().getUserStats()
    const entries: LeaderEntry[] = [
      LeaderEntry.of('追风少年', '🏃', 128.6, '体育学院', false),
      LeaderEntry.of('环湖跑团·阿凯', '🏃', 96.3, '计算机学院', false),
      LeaderEntry.of('绿道骑士·大川', '🚴', 88.9, '机械学院', false),
      LeaderEntry.of('晨跑365·老周', '🏃', 75.2, '经管学院', false),
      LeaderEntry.of('小曼', '🧘', 52.4, '外语学院', false),
      LeaderEntry.of('露露', '🎧', 41.8, '新闻学院', false)
    ]
    entries.push(LeaderEntry.of('我', '🏃', Math.round(myStats.totalKm * 10) / 10, '我的学院', true))
    entries.sort((a: LeaderEntry, b: LeaderEntry): number => b.km - a.km)
    return entries
  }

  /** 班级榜：种子班级 + 我的班级（真实累计里程） */
  static classBoard(): LeaderEntry[] {
    const myStats = StoreService.getInstance().getUserStats()
    const entries: LeaderEntry[] = [
      LeaderEntry.of('软件2301班', '💻', 486.2, '42 人参与', false),
      LeaderEntry.of('体教2402班', '🏅', 452.7, '38 人参与', false),
      LeaderEntry.of('会计2303班', '📊', 391.4, '45 人参与', false),
      LeaderEntry.of('机制2401班', '⚙️', 350.8, '36 人参与', false),
      LeaderEntry.of('英语2302班', '🗺️', 298.5, '40 人参与', false)
    ]
    entries.push(LeaderEntry.of('我的班级', '🏃', Math.round(myStats.totalKm * 10) / 10, '我贡献的里程', true))
    entries.sort((a: LeaderEntry, b: LeaderEntry): number => b.km - a.km)
    return entries
  }

  /** 跨校榜：藏龙岛高校圈种子选手 + 我的真实累计里程 */
  static crossSchoolBoard(): LeaderEntry[] {
    const myStats = StoreService.getInstance().getUserStats()
    const entries: LeaderEntry[] = [
      LeaderEntry.of('湖美·画笔与风', '🎨', 143.2, '湖北美术学院', false),
      LeaderEntry.of('经院·晚风十里', '🍃', 121.6, '湖北经济学院', false),
      LeaderEntry.of('纺大·织跑者', '🧵', 105.9, '武汉纺织大学', false),
      LeaderEntry.of('武体·圈速之王', '⚡', 98.4, '武汉体育学院', false),
      LeaderEntry.of('传媒·追光少年', '📷', 76.8, '湖北广电传媒', false)
    ]
    entries.push(LeaderEntry.of('我', '🏃', Math.round(myStats.totalKm * 10) / 10, '我的学校', true))
    entries.sort((a: LeaderEntry, b: LeaderEntry): number => b.km - a.km)
    return entries
  }

  /** 队伍榜：种子队伍 + 我参加挑战的队伍（成员进度实时汇总） */
  static teamBoard(): LeaderEntry[] {
    const myStats = StoreService.getInstance().getUserStats()
    const entries: LeaderEntry[] = [
      LeaderEntry.of('藏龙岛闪电队', '⚡', 88.6, '5 人 · 环湖跑团', false),
      LeaderEntry.of('夜跑者联盟', '🌙', 74.3, '4 人 · 操场夜跑', false),
      LeaderEntry.of('绿道骑行社', '🚴', 69.8, '6 人 · 绿道挑战', false)
    ]
    const challenges: Challenge[] = ChallengeService.list()
    for (let i = 0; i < challenges.length; i++) {
      const c: Challenge = challenges[i]
      if (!c.joined) {
        continue
      }
      let sumKm: number = 0
      for (let j = 0; j < c.members.length; j++) {
        sumKm += c.members[j].progressKm
      }
      entries.push(LeaderEntry.of(c.title, c.emoji, Math.round(sumKm * 10) / 10,
        `${c.members.length} 人 · 我的队伍`, true))
    }
    if (myStats.totalKm > 0) {
      entries.push(LeaderEntry.of('我的个人里程', '🏃', Math.round(myStats.totalKm * 10) / 10, '跨挑战累计', false))
    }
    entries.sort((a: LeaderEntry, b: LeaderEntry): number => b.km - a.km)
    return entries
  }

  /** 按 scope 取对应榜单 */
  static boardOf(scope: LeaderScope): LeaderEntry[] {
    if (scope === LeaderScope.FRIENDS) {
      return LeaderboardService.friendBoard()
    }
    if (scope === LeaderScope.CAMPUS) {
      return LeaderboardService.campusBoard()
    }
    if (scope === LeaderScope.CLASS) {
      return LeaderboardService.classBoard()
    }
    if (scope === LeaderScope.TEAM) {
      return LeaderboardService.teamBoard()
    }
    return LeaderboardService.crossSchoolBoard()
  }

  /** 我的名次（1 起算） */
  static myRank(list: LeaderEntry[]): number {
    for (let i = 0; i < list.length; i++) {
      if (list[i].isMe) {
        return i + 1
      }
    }
    return list.length
  }
}
