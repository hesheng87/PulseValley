/**
 * 脉动光谷 - 智能路线推荐引擎（M2.3）
 * score(route, slot) = Σ wᵢ·fᵢ 七维打分：AQI适配/温湿体感/UV/风速/绿植/远离车流/用户偏好
 * 对应《详细设计文档》4.3 RouteScorer
 */
import { CampusRoute, EnvSnapshot, RouteRecommend, EnvGuardResult } from '../common/Types'
import { RouteWeights } from '../common/Constants'
import { EnvService } from './EnvService'

export class RouteScorer {
  private static seededRoutes: CampusRoute[] = RouteScorer.buildSeedRoutes()

  /** 校园 POI 路线库（首批预置，生产由运营云端下发 route_library） */
  private static buildSeedRoutes(): CampusRoute[] {
    const lake: CampusRoute = new CampusRoute()
    lake.id = 'r_lake'
    lake.name = '环湖线'
    lake.desc = '东湖绿道接驳，湖风拂面，傍晚视野极佳'
    lake.baseKm = 3.2
    lake.greenRate = 0.9
    lake.awayTraffic = 0.85
    lake.popularity = 92
    lake.points = '沿湖岸顺时针'

    const track: CampusRoute = new CampusRoute()
    track.id = 'r_track'
    track.name = '操场环线'
    track.desc = '标准塑胶跑道 400m，适合配速训练与体测备考'
    track.baseKm = 1.6
    track.greenRate = 0.4
    track.awayTraffic = 1.0
    track.popularity = 88
    track.points = '外圈逆时针'

    const tree: CampusRoute = new CampusRoute()
    tree.id = 'r_tree'
    tree.name = '林荫道线'
    tree.desc = '梧桐大道贯通教学区，绿植覆盖隔尘降噪'
    tree.baseKm = 2.4
    tree.greenRate = 0.95
    tree.awayTraffic = 0.7
    tree.popularity = 76
    tree.points = '南门进北门出'

    const hill: CampusRoute = new CampusRoute()
    hill.id = 'r_hill'
    hill.name = '坡道挑战线'
    hill.desc = '连续缓坡 3 段，强度进阶，登顶俯瞰光谷'
    hill.baseKm = 4.1
    hill.greenRate = 0.7
    hill.awayTraffic = 0.6
    hill.popularity = 64
    hill.points = '环山公路'

    return [lake, track, tree, hill]
  }

  static getRoutes(): CampusRoute[] {
    return RouteScorer.seededRoutes
  }

  /** 主推荐入口：红线拦截返回室内方案；否则输出 Top3 路线 + 最佳时段 + 理由 */
  static recommend(snap: EnvSnapshot, historyKm: number): RouteRecommend[] {
    const guard: EnvGuardResult = EnvService.safetyCheck(snap)
    if (guard === EnvGuardResult.BLOCK) {
      const indoor: CampusRoute = new CampusRoute()
      indoor.id = 'r_indoor'
      indoor.name = '室内跟练方案'
      indoor.desc = EnvService.indoorAdvice()
      indoor.baseKm = 0
      const result: RouteRecommend = new RouteRecommend()
      result.route = indoor
      result.score = 0
      result.reason = `AQI ${snap.aqi} 超出安全红线，已切换室内模式`
      result.slot = ''
      return [result]
    }

    const w: RouteWeights = new RouteWeights()
    const results: RouteRecommend[] = []
    for (let i = 0; i < RouteScorer.seededRoutes.length; i++) {
      const route: CampusRoute = RouteScorer.seededRoutes[i]
      const score: number = w.aqi * RouteScorer.fAqi(snap) +
        w.body * RouteScorer.fBody(snap) +
        w.uv * RouteScorer.fUv(snap) +
        w.wind * RouteScorer.fWind(snap) +
        w.green * (route.greenRate * 10) +
        w.away * (route.awayTraffic * 10) +
        w.pref * RouteScorer.fPref(route, historyKm)
      const rec: RouteRecommend = new RouteRecommend()
      rec.route = route
      rec.score = Math.round(Math.min(score, 10) * 10) / 10
      rec.reason = RouteScorer.buildReason(snap, route, guard)
      rec.slot = RouteScorer.bestSlot()
      results.push(rec)
    }
    results.sort((a: RouteRecommend, b: RouteRecommend): number => b.score - a.score)
    return results.slice(0, 3)
  }

  /** 详设 4.3 特征函数 */
  static fAqi(snap: EnvSnapshot): number {
    if (snap.aqi <= 50) {
      return 10
    }
    if (snap.aqi <= 150) {
      return 10 - 0.05 * (snap.aqi - 50)
    }
    return 0
  }

  static fBody(snap: EnvSnapshot): number {
    const raw: number = 10 - Math.abs(snap.temp - 18) * 0.5
    return Math.max(0, Math.min(raw, 10))
  }

  static fUv(snap: EnvSnapshot): number {
    return Math.max(0, 10 - Math.max(0, snap.uv - 3) * 1.5)
  }

  static fWind(snap: EnvSnapshot): number {
    return Math.max(0, 10 - Math.max(0, snap.wind - 5) * 1.2)
  }

  static fPref(route: CampusRoute, historyKm: number): number {
    // 新手偏好低强度路线，老手偏好挑战路线
    const difficulty: number = route.baseKm >= 4 ? 1.0 : (route.baseKm >= 3 ? 0.6 : 0.3)
    const expLevel: number = Math.min(historyKm / 100, 1)
    return 1 + 9 * Math.abs(difficulty - (1 - expLevel) * 0.5)
  }

  /** 最佳运动窗口：18:30-20:30 校园运动高峰先验 */
  static bestSlot(): string {
    return '今晚 18:30 - 20:30'
  }

  static buildReason(snap: EnvSnapshot, route: CampusRoute, guard: EnvGuardResult): string {
    const parts: string[] = []
    parts.push(`AQI ${snap.aqi} ${EnvService.aqiLevelOf(snap.aqi)}`)
    parts.push(`体感 ${snap.temp}℃`)
    if (route.greenRate >= 0.8) {
      parts.push('高绿植隔尘')
    } else if (route.awayTraffic >= 0.95) {
      parts.push('远离车流')
    } else {
      parts.push('强度进阶')
    }
    if (guard === EnvGuardResult.WARN) {
      parts.push('轻度污染时段建议缩短时长')
    }
    return parts.join(' · ')
  }
}
