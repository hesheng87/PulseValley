/**
 * 脉动光谷 - 环境联动服务（M2）
 * EnvService：AQI/气象快照获取 + 30min 缓存 + 降级最近已知值
 * SafetyGuard：安全红线硬拦截（详设 4.2 阈值表）
 * 数据源：校园环境网关（演示数据源，按小时段生成合理 AQI 曲线，接口预留真实网关）
 */
import { EnvSnapshot, EnvGuardResult } from '../common/Types'
import { ENV_CACHE_TTL_MS, AQI_BLOCK_THRESHOLD, TEMP_HIGH_BLOCK, TEMP_LOW_BLOCK } from '../common/Constants'

export class EnvService {
  private static instance: EnvService | undefined = undefined
  private cache: EnvSnapshot | undefined = undefined

  static getInstance(): EnvService {
    if (EnvService.instance === undefined) {
      EnvService.instance = new EnvService()
    }
    return EnvService.instance
  }

  /** 获取环境快照：命中缓存直接返回，否则"请求网关"（演示源）并缓存 30min */
  getSnapshot(): EnvSnapshot {
    const now: number = Date.now()
    if (this.cache !== undefined && now - this.cache.updatedAt < ENV_CACHE_TTL_MS) {
      return this.cache
    }
    const fresh: EnvSnapshot = this.fetchFromGateway(now)
    this.cache = fresh
    return fresh
  }

  /** 强制刷新（下拉刷新场景） */
  refresh(): EnvSnapshot {
    this.cache = undefined
    return this.getSnapshot()
  }

  /**
   * 演示数据源：模拟校园环境网关返回。
   * 生产环境替换为 http.get('/v1/env/aqi?lng=&lat=')（和风天气双源冗余）。
   */
  private fetchFromGateway(now: number): EnvSnapshot {
    const hour: number = new Date(now).getHours()
    // 校园 AQI 日内曲线：早晚高峰偏高，午后偏低
    const baseAqi: number = 42 + Math.round(38 * Math.sin((hour - 7) * Math.PI / 12))
    const aqi: number = Math.max(18, Math.min(baseAqi, 165))
    const temp: number = 16 + Math.round(10 * Math.sin((hour - 9) * Math.PI / 13))
    const snap: EnvSnapshot = new EnvSnapshot()
    snap.aqi = aqi
    snap.pm25 = Math.round(aqi * 0.72)
    snap.temp = temp
    snap.humidity = 45 + (hour % 5) * 6
    snap.uv = hour >= 10 && hour <= 15 ? 6 + (hour % 3) : 2
    snap.wind = 2 + (hour % 4)
    snap.source = 'campus-gateway'
    snap.updatedAt = now
    snap.isStale = false
    return snap
  }

  /** AQI 等级描述 */
  static aqiLevelOf(aqi: number): string {
    if (aqi <= 50) {
      return '优'
    }
    if (aqi <= 100) {
      return '良'
    }
    if (aqi <= 150) {
      return '轻度污染'
    }
    return '中重度污染'
  }

  static aqiColorOf(aqi: number): string {
    if (aqi <= 50) {
      return '#34C77B'
    }
    if (aqi <= 100) {
      return '#F5A623'
    }
    if (aqi <= 150) {
      return '#FF7A45'
    }
    return '#E8404A'
  }

  /** 安全红线，详设 4.2：BLOCK 硬拦截 / WARN 降级推荐 / OK 正常 */
  static safetyCheck(snap: EnvSnapshot): EnvGuardResult {
    if (snap.aqi > AQI_BLOCK_THRESHOLD) {
      return EnvGuardResult.BLOCK
    }
    if (snap.temp >= TEMP_HIGH_BLOCK || snap.temp <= TEMP_LOW_BLOCK) {
      return EnvGuardResult.BLOCK
    }
    if (snap.aqi > 100) {
      return EnvGuardResult.WARN
    }
    return EnvGuardResult.OK
  }

  /** 红线拦截时的室内替代建议 */
  static indoorAdvice(): string {
    return '当前环境不宜户外运动，已为你推荐室内跟练课程（宿舍拉伸 / HIIT 燃脂）'
  }
}
