/**
 * 脉动光谷 - 全局常量
 * 对应《详细设计文档》2.2 全局常量表
 */

/** 运动配速与物理校验红线 */
export const MAX_HUMAN_SPEED_MPS: number = 10.0
export const MIN_POINT_ACCURACY_M: number = 30
export const AUTO_PAUSE_SPEED_MPS: number = 0.5
export const AUTO_PAUSE_SECONDS: number = 30
export const STEP_ESTIMATE_M: number = 0.7

/** 环境联动 */
export const ENV_CACHE_TTL_MS: number = 30 * 60 * 1000
export const AQI_BLOCK_THRESHOLD: number = 150
export const TEMP_HIGH_BLOCK: number = 38
export const TEMP_LOW_BLOCK: number = -10

/** 路线打分默认权重（云端可配热更，此处为端侧默认值） */
export class RouteWeights {
  aqi: number = 0.30
  body: number = 0.20
  uv: number = 0.10
  wind: number = 0.05
  green: number = 0.15
  away: number = 0.10
  pref: number = 0.10
}

/** 等级成长曲线：level = floor(sqrt(points / 50)) + 1 */
export const POINTS_PER_KM: number = 10
export const POINTS_PER_RUN: number = 20
export const LEVEL_DIVISOR: number = 50

/** 校园路线库（首批预置 POI，运营可云端下发扩展） */
export class RouteLibrary {
  static readonly LAKE: string = '环湖线'
  static readonly TRACK: string = '操场环线'
  static readonly TREE: string = '林荫道线'
  static readonly HILL: string = '坡道挑战线'
}
