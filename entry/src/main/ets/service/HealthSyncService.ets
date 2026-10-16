/**
 * 脉动光谷 - 华为运动健康同步服务
 * 与华为运动健康（Huawei Health Kit）双向同步：拉取步数/睡眠/静息心率/卡路里，
 * 回传运动记录与健身训练；演示版为端侧模拟适配器（真实环境接入 Health Kit 开放接口）
 */
import { HealthSyncState, HealthSnapshot } from '../common/Types'
import { StoreService } from './StoreService'
import { HealthService } from './HealthService'

export class HealthSyncService {
  /** 是否已连接华为运动健康（演示版：绑定即视为已连接） */
  static isConnected(): boolean {
    return StoreService.getInstance().getHealthSyncState().totalSyncCount > 0
  }

  static getState(): HealthSyncState {
    return StoreService.getInstance().getHealthSyncState()
  }

  /** 手表实时健康快照（同步预览用） */
  static liveSnapshot(): HealthSnapshot {
    return HealthService.getInstance().getSnapshot()
  }

  /**
   * 立即同步：从华为运动健康拉取今日步数/睡眠/静息心率/卡路里，
   * 并回传本端运动记录（演示版模拟适配器往返，返回同步摘要）
   */
  static syncNow(): HealthSyncState {
    const store: StoreService = StoreService.getInstance()
    const state: HealthSyncState = store.getHealthSyncState()
    const snap: HealthSnapshot = HealthService.getInstance().getSnapshot()
    const stats = store.getUserStats()

    state.lastSyncTs = Date.now()
    state.lastSyncSteps = snap.steps > 0 ? snap.steps : 6800 + Math.floor(Math.random() * 2000)
    state.lastSyncSleepH = HealthService.sleepBaseline()
    state.lastSyncRestingHr = HealthService.restingHrBaseline(stats.totalKm)
    state.lastSyncCalories = 300 + Math.floor(stats.totalKm * 4)
    state.totalSyncCount += 1
    store.saveHealthSyncState(state)
    store.flush()
    return state
  }

  static setAutoSync(enabled: boolean): void {
    const store: StoreService = StoreService.getInstance()
    const state: HealthSyncState = store.getHealthSyncState()
    state.autoSync = enabled
    store.saveHealthSyncState(state)
  }

  /** 同步摘要文案 */
  static summaryOf(state: HealthSyncState): string {
    if (state.lastSyncTs === 0) {
      return '尚未同步，点击立即同步连接华为运动健康'
    }
    return `已同步：今日 ${state.lastSyncSteps} 步 · 睡眠 ${state.lastSyncSleepH} 小时 · ` +
      `静息心率 ${state.lastSyncRestingHr} 次/分 · 消耗 ${state.lastSyncCalories} 千卡`
  }
}
