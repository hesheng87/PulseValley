/**
 * 脉动光谷 - 分布式流转服务（鸿蒙分布式核心）
 * 基于分布式软总线组网：手机(轨迹记录 MAIN) / 平板(实时大屏看板) / 手表(心率采集+震动提醒)
 * 1. 设备发现与组网展示（deviceManager 真实发现，演示环境降级为预置设备组网）
 * 2. 跨设备流转：手机记录轨迹 → 平板实时看板 → 手表震动提醒（配速/心率/每公里/队友动态）
 * 3. 分布式成就与排行榜：任意设备完成挑战，成就与排名立即经 DDO 同步到所有设备
 */
import { distributedDataObject } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { vibrator } from '@kit.SensorServiceKit'
import { CheerMessage, DeviceAlertEvent, FlowDevice, LivePanelState, SocialSyncSource } from '../common/Types'
import { StoreService } from './StoreService'
import { HealthService } from './HealthService'

export type CheerCallback = (cheer: CheerMessage) => void

const SOCIAL_SESSION: string = 'maidong_social_sync'
const WATCH_PACE_SLOW_SEC: number = 480
const WATCH_HR_HIGH: number = 160

export class DeviceFlowService {
  private static instance: DeviceFlowService | undefined = undefined

  private devices: FlowDevice[] = []
  private socialDdo: distributedDataObject.DataObject | undefined = undefined
  private socialSource: SocialSyncSource = new SocialSyncSource()
  private socialOnline: boolean = false

  private cheerTimer: number = -1
  private cheerListener: CheerCallback | undefined = undefined
  private lastPaceAlertTs: number = 0
  private lastHrAlertTs: number = 0
  private lastLap: number = 0
  private lastCheer: CheerMessage = new CheerMessage()

  static getInstance(): DeviceFlowService {
    if (DeviceFlowService.instance === undefined) {
      DeviceFlowService.instance = new DeviceFlowService()
    }
    return DeviceFlowService.instance
  }

  /** ---------- 设备组网 ---------- */

  /** 组网设备列表：软总线发现（真实多设备环境）+ 演示预置组网 */
  listDevices(): FlowDevice[] {
    if (this.devices.length > 0) {
      return this.devices
    }
    // 演示环境预置"一机三端"组网（真实环境由 deviceManager 信任设备列表覆盖）
    this.devices = [
      FlowDevice.of('dev_phone', '我的手机', '📱', '轨迹记录 · 主控端', true,
        '记录 GPS 轨迹 / 配速 / 步数，作为 MAIN 端发布数据', '实时'),
      FlowDevice.of('dev_pad', '我的平板', '📱', '大屏看板 · 数据流转', true,
        '实时大屏数据看板：轨迹 / 配速曲线 / 队友排行榜', '1 秒前'),
      FlowDevice.of('dev_watch', '我的手表', '⌚', '随身采集 · 震动提醒', true,
        '心率 / 步频采集上报，配速偏慢与队友动态震动提醒', '实时')
    ]
    return this.devices
  }

  /** 当前组网在线设备数（不含本机） */
  onlineCount(): number {
    const list: FlowDevice[] = this.listDevices()
    let count: number = 0
    for (let i = 0; i < list.length; i++) {
      if (list[i].online && list[i].id !== 'dev_phone') {
        count += 1
      }
    }
    return count
  }

  /** 跨设备流转链路描述（演示叙事） */
  flowChainText(): string {
    return '手机记录轨迹 → 平板实时大屏看板 → 手表震动提醒'
  }

  /** ---------- 设备同时启动 / 停止（纯软件演示） ---------- */

  /**
   * 启停一台组网设备：
   * - 手表：启停虚拟手表健康采集（心率/血氧/压力实时流 + DDO 上报）
   * - 平板：启停大屏看板数据流转
   * 返回切换后的在线状态
   */
  toggleDevice(id: string): boolean {
    const list: FlowDevice[] = this.listDevices()
    for (let i = 0; i < list.length; i++) {
      if (list[i].id !== id || list[i].id === 'dev_phone') {
        continue
      }
      list[i].online = !list[i].online
      if (id === 'dev_watch') {
        if (list[i].online) {
          HealthService.getInstance().startWatch()
        } else {
          HealthService.getInstance().stopWatch()
        }
      }
      list[i].lastSyncText = list[i].online ? '实时' : '离线'
      return list[i].online
    }
    return false
  }

  /** 指定设备是否在线 */
  isDeviceOnline(id: string): boolean {
    const list: FlowDevice[] = this.listDevices()
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i].online
      }
    }
    return false
  }

  /** 全部设备同时启动（一键多端协同） */
  startAllDevices(): void {
    const list: FlowDevice[] = this.listDevices()
    for (let i = 0; i < list.length; i++) {
      if (!list[i].online) {
        this.toggleDevice(list[i].id)
      }
    }
  }

  /** ---------- 分布式成就与排行榜同步 ---------- */

  /** 加入分布式社交同步组网（成就/排行 DDO 会话） */
  openSocialSync(context: common.UIAbilityContext): void {
    if (this.socialDdo !== undefined) {
      return
    }
    try {
      this.socialDdo = distributedDataObject.create(context, this.socialSource)
      this.socialDdo.setSessionId(SOCIAL_SESSION, (): void => {
        this.socialOnline = true
        console.info('[DeviceFlow] social sync session joined')
      })
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[DeviceFlow] social sync open failed: ${err.code} ${err.message}`)
      this.socialOnline = false
    }
  }

  /**
   * 广播成就与排行榜到所有组网设备：
   * 任意设备完成挑战 → 成就与排名立即在所有设备同步更新
   */
  broadcastAchievements(): boolean {
    const store: StoreService = StoreService.getInstance()
    const ids: string[] = store.getUnlockedBadgeIds()
    const stats = store.getUserStats()
    this.socialSource.badgeCsv = ids.join(',')
    this.socialSource.totalKm = stats.totalKm
    this.socialSource.level = stats.level
    this.socialSource.lastUpdateTs = Date.now()
    if (this.socialDdo !== undefined && this.socialOnline) {
      try {
        this.socialDdo.save('maidong_social_sync')
        return true
      } catch (e) {
        console.error('[DeviceFlow] broadcast save failed')
      }
    }
    return false
  }

  /** ---------- 手表震动提醒（跨设备流转通知） ---------- */

  /**
   * 运动中每秒面板刷新时调用：手表端根据实时数据生成震动提醒
   * 返回提醒事件（节流内返回空事件），本机同时震动演示
   */
  evaluateWatchAlert(panel: LivePanelState): DeviceAlertEvent {
    const now: number = Date.now()
    if (panel.lapKm > this.lastLap) {
      this.lastLap = panel.lapKm
      this.lastPaceAlertTs = now
      return this.fireAlert(`⌚ 恭喜完成第 ${panel.lapKm} 公里！手表为你震动庆祝 🎉`, 'lap')
    }
    if (panel.heartRate > WATCH_HR_HIGH && now - this.lastHrAlertTs > 180000) {
      this.lastHrAlertTs = now
      return this.fireAlert(`⌚ 心率 ${panel.heartRate} 偏高，手表提醒：放慢配速，调整呼吸`, 'hr')
    }
    if (panel.paceSecPerKm > WATCH_PACE_SLOW_SEC && panel.distanceM > 500 && now - this.lastPaceAlertTs > 240000) {
      this.lastPaceAlertTs = now
      return this.fireAlert('⌚ 配速偏慢啦，手表提醒：跟上节奏，队友正在赶超！', 'pace')
    }
    return new DeviceAlertEvent()
  }

  private fireAlert(text: string, kind: string): DeviceAlertEvent {
    this.vibrate(320)
    return DeviceAlertEvent.of(text, '⌚ 手表', Date.now(), kind)
  }

  /** 手表/本机震动（生产环境经软总线下发到手表端执行） */
  private vibrate(durationMs: number): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: durationMs
      }, {
        id: 0,
        usage: 'notification'
      }).then((): void => {
      }).catch((e: BusinessError): void => {
        console.error(`[DeviceFlow] vibrate failed: ${e.message}`)
      })
    } catch (e) {
      // 演示环境无震动马达时静默降级
    }
  }

  /** ---------- 语音加油实时流（挑战内社交互动） ---------- */

  /** 开始监听队友语音加油（模拟经软总线从队友设备实时推送） */
  startCheerFeed(listener: CheerCallback): void {
    this.cheerListener = listener
    if (this.cheerTimer >= 0) {
      return
    }
    this.cheerTimer = setInterval((): void => {
      this.pushRandomCheer()
    }, 25000)
  }

  stopCheerFeed(): void {
    if (this.cheerTimer >= 0) {
      clearInterval(this.cheerTimer)
      this.cheerTimer = -1
    }
    this.cheerListener = undefined
  }

  /** 我发出的语音加油（广播到所有队友设备） */
  sendCheer(from: string, avatar: string, text: string): CheerMessage {
    const cheer: CheerMessage = CheerMessage.of(from, avatar, text, Date.now())
    this.lastCheer = cheer
    this.vibrate(200)
    return cheer
  }

  getLastCheer(): CheerMessage {
    return this.lastCheer
  }

  private pushRandomCheer(): void {
    const poolFrom: string[] = ['阿凯', '小曼', '大川', '露露', '老周']
    const poolAvatar: string[] = ['🏃', '🧘', '🚴', '🎧', '📣']
    const poolText: string[] = [
      '加油！还有最后 1 公里 🔥',
      '配速稳住，我在平板看板上盯着你呢 😎',
      '冲鸭！完赛请你喝奶茶 🧋',
      '追上我了！好样的，保持住 💪',
      '语音加油已送达：节奏带起来！🎵'
    ]
    const idx: number = Math.floor(Math.random() * poolText.length)
    const fidx: number = Math.floor(Math.random() * poolFrom.length)
    const cheer: CheerMessage = CheerMessage.of(poolFrom[fidx], poolAvatar[fidx],
      poolText[Math.min(idx, poolText.length - 1)], Date.now())
    this.lastCheer = cheer
    this.vibrate(200)
    if (this.cheerListener !== undefined) {
      this.cheerListener(cheer)
    }
  }

  /** ---------- 运动结束清理 ---------- */

  onSessionEnd(): void {
    this.stopCheerFeed()
    this.lastLap = 0
    this.lastPaceAlertTs = 0
    this.lastHrAlertTs = 0
  }
}
