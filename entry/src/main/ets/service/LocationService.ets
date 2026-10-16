/**
 * 脉动光谷 - 持续定位服务
 * 对应概设 M1.2 / 详设 3.2：Location Kit 持续定位 + 轨迹点过滤
 */
import { geoLocationManager } from '@kit.LocationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { SportPoint } from '../common/Types'
import { MIN_POINT_ACCURACY_M, MAX_HUMAN_SPEED_MPS } from '../common/Constants'

export type LocationCallback = (point: SportPoint) => void

export class LocationService {
  private static instance: LocationService | undefined = undefined
  private subscribed: boolean = false
  private listener: LocationCallback | undefined = undefined
  private lastPoint: SportPoint | undefined = undefined
  private cheatCounter: number = 0

  static getInstance(): LocationService {
    if (LocationService.instance === undefined) {
      LocationService.instance = new LocationService()
    }
    return LocationService.instance
  }

  /** 开启持续定位（1 秒间隔，导航场景），返回是否成功 */
  subscribe(callback: LocationCallback): boolean {
    this.listener = callback
    if (this.subscribed) {
      return true
    }
    try {
      const request: geoLocationManager.ContinuousLocationRequest = {
        interval: 1,
        locationScenario: geoLocationManager.UserActivityScenario.NAVIGATION
      }
      geoLocationManager.on('locationChange', request, (loc: geoLocationManager.Location): void => {
        this.handleLocation(loc)
      })
      this.subscribed = true
      return true
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[LocationService] subscribe failed: ${err.code} ${err.message}`)
      return false
    }
  }

  unsubscribe(): void {
    if (!this.subscribed) {
      return
    }
    try {
      geoLocationManager.off('locationChange')
      this.subscribed = false
      this.lastPoint = undefined
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[LocationService] unsubscribe failed: ${err.code}`)
    }
  }

  /** 详设 3.2.1 轨迹点过滤：精度过滤 + 速度红线（模拟定位特征累计） */
  private handleLocation(loc: geoLocationManager.Location): void {
    if (loc.accuracy > MIN_POINT_ACCURACY_M) {
      return
    }
    const point: SportPoint = {
      ts: Date.now(),
      lng: loc.longitude,
      lat: loc.latitude,
      accuracy: loc.accuracy,
      speed: loc.speed
    }
    const last: SportPoint | undefined = this.lastPoint
    if (last !== undefined) {
      const dt: number = Math.max((point.ts - last.ts) / 1000, 0.001)
      const dist: number = this.haversine(last, point)
      const speed: number = dist / dt
      if (speed > MAX_HUMAN_SPEED_MPS) {
        this.cheatCounter += 1
        return
      }
      this.cheatCounter = Math.max(0, this.cheatCounter - 1)
    }
    this.lastPoint = point
    if (this.listener !== undefined) {
      this.listener(point)
    }
  }

  /** 球面距离（米），详设 3.2.1 */
  haversine(p: SportPoint, q: SportPoint): number {
    const R: number = 6371000
    const radLat1: number = p.lat * Math.PI / 180
    const radLat2: number = q.lat * Math.PI / 180
    const dLat: number = radLat2 - radLat1
    const dLng: number = (q.lng - p.lng) * Math.PI / 180
    const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(radLat1) * Math.cos(radLat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2)
    return 2 * R * Math.asin(Math.sqrt(a))
  }

  getCheatScore(): number {
    return this.cheatCounter
  }
}
