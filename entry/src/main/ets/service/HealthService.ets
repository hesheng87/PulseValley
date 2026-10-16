/**
 * 脉动光谷 - 手表健康数据服务（纯软件演示）
 * 模拟华为手表作为 COLLECTOR 端：实时采集心率/血氧/压力/睡眠/步数/卡路里，
 * 心率与步频写入分布式数据对象（软总线 DDO），手机运动面板实时读取展示，
 * 实现"手机 + 手表同时启动使用、数据毫秒级同步"的单机纯软件演示。
 * 生产环境替换为真实手表端 Sensor 服务经 softbus 上报。
 */
import { HealthSnapshot } from '../common/Types'
import { SyncChannel } from './SyncChannel'
import { StoreService } from './StoreService'

const WATCH_TICK_MS: number = 2000

export type HealthTickCallback = (snap: HealthSnapshot) => void

export class HealthService {
  private static instance: HealthService | undefined = undefined

  private snap: HealthSnapshot = new HealthSnapshot()
  private timerId: number = -1
  private watchRunning: boolean = false
  private listeners: HealthTickCallback[] = []

  static getInstance(): HealthService {
    if (HealthService.instance === undefined) {
      HealthService.instance = new HealthService()
    }
    return HealthService.instance
  }

  private constructor() {
    this.snap.heartRate = 72
    this.snap.restingHr = 62
    this.snap.spo2 = 98
    this.snap.stress = 35
    this.snap.sleepHours = 7.2
    this.snap.calories = 0
    this.snap.steps = 0
    this.snap.updatedTs = Date.now()
  }

  isWatchRunning(): boolean {
    return this.watchRunning
  }

  getSnapshot(): HealthSnapshot {
    return this.snap
  }

  /** 启动虚拟手表（开始实时健康采集与分布式上报） */
  startWatch(): void {
    if (this.watchRunning) {
      return
    }
    this.watchRunning = true
    console.info('[Health] virtual watch started')
    this.timerId = setInterval((): void => {
      this.tick()
    }, WATCH_TICK_MS)
    this.tick()
  }

  /** 停止虚拟手表 */
  stopWatch(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    this.watchRunning = false
    console.info('[Health] virtual watch stopped')
  }

  /** 订阅健康数据流（UI 观测） */
  subscribe(cb: HealthTickCallback): void {
    this.listeners.push(cb)
  }

  unsubscribe(cb: HealthTickCallback): void {
    const idx: number = this.listeners.indexOf(cb)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }

  /** 每 2 秒采集一拍：心率随机游走（运动态抬升），血氧/压力/步数/卡路里联动更新 */
  private tick(): void {
    const now: number = Date.now()
    const sessionActive: boolean = SyncChannel.getInstance().isOnline()
    let targetHr: number = 72 + Math.round(Math.random() * 8)
    if (sessionActive) {
      targetHr = 138 + Math.round(Math.random() * 26)
    }
    // 随机游走逼近目标心率
    const drift: number = Math.round((targetHr - this.snap.heartRate) * 0.3) +
      (Math.random() > 0.5 ? 1 : -1)
    this.snap.heartRate = Math.max(55, Math.min(this.snap.heartRate + drift, 188))
    this.snap.spo2 = Math.max(93, Math.min(99, 97 + Math.round((Math.random() - 0.5) * 3)))
    this.snap.stress = Math.max(10, Math.min(80, this.snap.stress + Math.round((Math.random() - 0.5) * 6)))
    if (sessionActive) {
      this.snap.steps += 3 + Math.floor(Math.random() * 4)
      this.snap.calories += Math.random() > 0.5 ? 1 : 0
    } else {
      this.snap.steps += Math.floor(Math.random() * 2)
    }
    this.snap.updatedTs = now

    // 手表(COLLECTOR)写者：心率/步频写入 DDO 共享对象，手机端面板实时读取
    const src = SyncChannel.getInstance().getSource()
    src.heartRate = this.snap.heartRate
    src.cadence = sessionActive ? 168 + Math.floor(Math.random() * 10) : 0
    if (SyncChannel.getInstance().isOnline()) {
      SyncChannel.getInstance().publish()
    }

    // 广播给订阅的 UI（手表面板/健康卡等）
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i](this.snap)
    }
  }

  /** 手表侧今日健康摘要（供华为运动健康同步输入） */
  todaySummary(): HealthSnapshot {
    return this.snap
  }

  /** 睡眠时长的模拟基线（演示版固定合理区间） */
  static sleepBaseline(): number {
    const h: number = new Date().getHours()
    return h < 9 ? 7.6 : (h < 12 ? 7.1 : 6.8)
  }

  /** 静息心率基线 */
  static restingHrBaseline(statsTotalKm: number): number {
    return Math.max(52, 66 - Math.floor(statsTotalKm / 20))
  }
}
