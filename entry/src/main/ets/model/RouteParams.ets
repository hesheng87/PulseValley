/**
 * 脉动光谷 - 路由参数定义（全工程唯一声明，arkts-no-decl-merging）
 */

/** RunningPage 入参：type 取值见 SportType 枚举 */
export interface RunningParams {
  type: number
}

/** ResultPage 入参：recordId 定位记录；newBadges 为逗号分隔的勋章 id */
export interface ResultParams {
  recordId: string
  newBadges: string
}

/** ShareCardPage 入参：recordId 定位记录 */
export interface ShareCardParams {
  recordId: string
}

/** RouteDetailPage 入参：routeId 对应 RouteScorer 路线库 */
export interface RouteDetailParams {
  routeId: string
}

/** ChallengeDetailPage 入参：challengeId 对应 ChallengeService 挑战列表 */
export interface ChallengeDetailParams {
  challengeId: string
}

/** LeaderboardPage 入参：scope 取值见 LeaderScope 枚举 */
export interface LeaderboardParams {
  scope: number
}
