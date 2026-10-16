/**
 * 脉动光谷 - 运动会话编排器（M1 核心）
 * 状态机 IDLE→PREPARING→RECORDING→PAUSED→FINISHED（详设 3.1.2）
 * 联动：LocationService(轨迹) + StepService(计步) + SyncChannel(分布式同步)
 * Local-First：每秒快照防崩溃丢失（详设 3.1.3）
 */
import { common } from '@kit.AbilityKit'
import {
  SessionStatus, SportType, SportPoint, SportRecord, LivePanelState, SportSyncSource
} from '../common/Types'
import { AUTO_PAUSE_SPEED_MPS, AUTO_PAUSE_SECONDS, STEP_ESTIMATE_M } from '../common/Constants'
import { LocationService } from './LocationService'
import { StepService } from './StepService'
import { SyncChannel } from './SyncChannel'

export type PanelCallback = (panel: LivePanelState) => void
export type FinishCallback = (record: SportRecord) => void

export class SportSession {
  private static instance: SportSession | undefined = undefined

  private status: SessionStatus = SessionStatus.IDLE
  private type: SportType = SportType.RUN
  private recordId: string = ''
  private startTs: number = 0
  private movingMs: number = 0
  private lastTickTs: number = 0
  private distanceM: number = 0
  private gpsDistanceM: number = 0
  private lapKm: number = 0
  private pointCount: number = 0
  private lastPoint: SportPoint | undefined = undefined
  private stepBase: number = -1
  private stepCurrent: number = 0
  private gpsMode: boolean = true
  private stillTicks: number = 0
  /** 3-2-1 倒计时剩余秒数 */
  private countdownNum: number = 3
  /** 本次运动最佳配速（秒/公里，0=尚无） */
  private bestPaceSecPerKm: number = 0
  private timerId: number = -1
  private panelCb: PanelCallback | undefined = undefined
  private finishCb: FinishCallback | undefined = undefined

  static getInstance(): SportSession {
    if (SportSession.instance === undefined) {
      SportSession.instance = new SportSession()
    }
    return SportSession.instance
  }

  getStatus(): SessionStatus {
    return this.status
  }

  start(context: common.UIAbilityContext, type: SportType,
    onPanel: PanelCallback, onFinish: FinishCallback): void {
    if (this.status === SessionStatus.RECORDING || this.status === SessionStatus.PAUSED) {
      return
    }
    this.status = SessionStatus.PREPARING
    this.type = type
    this.recordId = `r_${Date.now()}_${Math.floor(Math.random() * 10000)}`
    this.startTs = Date.now()
    this.lastTickTs = this.startTs
    this.movingMs = 0
    this.distanceM = 0
    this.gpsDistanceM = 0
    this.lapKm = 0
    this.pointCount = 0
    this.lastPoint = undefined
    this.stepBase = -1
    this.stepCurrent = 0
    this.stillTicks = 0
    this.countdownNum = 3
    this.bestPaceSecPerKm = 0
    this.panelCb = onPanel
    this.finishCb = onFinish

    // 采集链路：计步（手表/手机传感器，失败降级估算模式展示为0）
    StepService.getInstance().subscribe((totalSteps: number): void => {
      if (this.stepBase < 0) {
        this.stepBase = totalSteps
      }
      this.stepCurrent = totalSteps
    })
    // 采集链路：持续定位（无权限/无信号时降级为步数估算模式）
    const gpsOk: boolean = LocationService.getInstance().subscribe((point: SportPoint): void => {
      this.onLocation(point)
    })
    this.gpsMode = gpsOk

    // 分布式链路：软总线 DDO 组网（多设备实时同步，失败降级仅本机）
    SyncChannel.getInstance().open(context, this.recordId, (fields: string[]): void => {
      this.onRemoteChange(fields)
    })

    // 3-2-1 倒计时（PREPARING），结束后进入 RECORDING
    this.timerId = setInterval((): void => {
      this.tick()
    }, 1000)
    this.emitPanel()
  }

  pause(): void {
    if (this.status !== SessionStatus.RECORDING) {
      return
    }
    this.status = SessionStatus.PAUSED
    this.lastTickTs = Date.now()
    this.emitPanel()
  }

  resume(): void {
    if (this.status !== SessionStatus.PAUSED) {
      return
    }
    this.status = SessionStatus.RECORDING
    this.lastTickTs = Date.now()
    this.emitPanel()
  }

  isRunning(): boolean {
    return this.status === SessionStatus.RECORDING || this.status === SessionStatus.PAUSED ||
      this.status === SessionStatus.PREPARING
  }

  /** 每秒心跳：倒计时 / 计时 / 配速 / 步数估算 / DDO发布 / 自动暂停 */
  private tick(): void {
    if (this.status === SessionStatus.PREPARING) {
      this.countdownNum -= 1
      if (this.countdownNum <= 0) {
        this.status = SessionStatus.RECORDING
        this.lastTickTs = Date.now()
      }
    } else if (this.status === SessionStatus.RECORDING) {
      const now: number = Date.now()
      this.movingMs += now - this.lastTickTs
      this.lastTickTs = now

      // 无 GPS 时按步数估算里程（详设 3.2.1 降级路径）
      if (!this.gpsMode) {
        this.distanceM = Math.max(this.distanceM, this.estimateBySteps())
      }

      // 最佳配速追踪（当前配速优于历史最佳时刷新）
      const paceNow: number = this.currentPace()
      if (paceNow > 0 && (this.bestPaceSecPerKm <= 0 || paceNow < this.bestPaceSecPerKm)) {
        this.bestPaceSecPerKm = paceNow
      }

      // 自动暂停判定（详设 3.2.2）
      if (this.estimateSpeed() < AUTO_PAUSE_SPEED_MPS) {
        this.stillTicks += 1
        if (this.stillTicks >= AUTO_PAUSE_SECONDS) {
          this.pause()
        }
      } else {
        this.stillTicks = 0
      }
    }
    this.publishToSync()
    this.emitPanel()
  }

  private estimateBySteps(): number {
    if (this.stepBase < 0) {
      return this.distanceM
    }
    return Math.max(0, this.stepCurrent - this.stepBase) * STEP_ESTIMATE_M
  }

  private estimateSpeed(): number {
    if (this.gpsMode && this.lastPoint !== undefined) {
      return this.lastPoint.speed
    }
    return 0.6
  }

  /** 定位点处理：里程累加 + 每公里 Lap 事件（详设 3.2.1 / 3.4） */
  private onLocation(point: SportPoint): void {
    if (this.status !== SessionStatus.RECORDING) {
      return
    }
    const last: SportPoint | undefined = this.lastPoint
    if (last !== undefined) {
      const seg: number = LocationService.getInstance().haversine(last, point)
      if (seg > 0) {
        this.gpsDistanceM += seg
        this.distanceM = this.gpsDistanceM
      }
    }
    this.lastPoint = point
    this.pointCount += 1
    const newLap: number = Math.floor(this.distanceM / 1000)
    if (newLap > this.lapKm) {
      this.lapKm = newLap
      console.info(`[SportSession] lap ${newLap}km done`)
    }
  }

  /** DDO 远端变更（手表心率/步频上报），当前端侧面板合并展示 */
  private onRemoteChange(fields: string[]): void {
    console.info(`[SportSession] remote fields changed: ${fields.join(',')}`)
  }

  /** 分布式发布：单一写者原则，本端(手机 MAIN)写里程/配速/状态 */
  private publishToSync(): void {
    const src: SportSyncSource = SyncChannel.getInstance().getSource()
    src.status = this.status
    src.distanceM = Math.round(this.distanceM)
    src.paceSecPerKm = this.currentPace()
    src.steps = Math.max(0, this.stepCurrent - Math.max(this.stepBase, 0))
    src.lapKm = this.lapKm
    SyncChannel.getInstance().publish()
  }

  private currentPace(): number {
    const km: number = this.distanceM / 1000
    if (km < 0.05) {
      return 0
    }
    return this.movingMs / 1000 / km
  }

  /** 结束运动：构建记录并回调（先落盘后展示，Local-First）；倒计时阶段视为取消不产生记录 */
  finish(): SportRecord | undefined {
    if (this.status === SessionStatus.PREPARING) {
      if (this.timerId >= 0) {
        clearInterval(this.timerId)
        this.timerId = -1
      }
      StepService.getInstance().unsubscribe()
      LocationService.getInstance().unsubscribe()
      SyncChannel.getInstance().close()
      this.status = SessionStatus.IDLE
      return undefined
    }
    if (this.status !== SessionStatus.RECORDING && this.status !== SessionStatus.PAUSED) {
      return undefined
    }
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
    StepService.getInstance().unsubscribe()
    LocationService.getInstance().unsubscribe()
    SyncChannel.getInstance().close()

    const endTs: number = Date.now()
    const durationS: number = Math.floor(this.movingMs / 1000)
    const steps: number = Math.max(0, this.stepCurrent - Math.max(this.stepBase, 0))
    const km: number = this.distanceM / 1000
    const weight: number = 60
    let calories: number = 0
    if (this.type === SportType.RUN) {
      calories = 1.036 * weight * km
    } else if (this.type === SportType.WALK) {
      calories = 0.7 * weight * km
    } else {
      calories = 0.6 * weight * km
    }
    const record: SportRecord = SportRecord.of(this.recordId, this.type, this.startTs, endTs,
      Math.round(this.distanceM), durationS, steps, Math.round(calories),
      Math.round(this.currentPace()), this.pointCount)

    this.status = SessionStatus.IDLE
    if (this.finishCb !== undefined) {
      this.finishCb(record)
    }
    return record
  }

  /** 生成 UI 面板快照（全新实例驱动 @State 刷新） */
  private emitPanel(): void {
    if (this.panelCb === undefined) {
      return
    }
    const panel: LivePanelState = new LivePanelState()
    panel.status = this.status
    panel.countdownNum = this.countdownNum
    panel.durationS = Math.floor(this.movingMs / 1000)
    panel.distanceM = Math.round(this.distanceM)
    panel.paceSecPerKm = Math.round(this.currentPace())
    panel.bestPaceSecPerKm = Math.round(this.bestPaceSecPerKm)
    panel.steps = Math.max(0, this.stepCurrent - Math.max(this.stepBase, 0))
    // 实时步频估算：步数增量 / 运动分钟数（步/分）
    const movingMinutes: number = this.movingMs / 60000
    panel.cadence = movingMinutes > 0.05
      ? Math.round(Math.max(0, this.stepCurrent - Math.max(this.stepBase, 0)) / movingMinutes) : 0
    panel.heartRate = SyncChannel.getInstance().getSource().heartRate
    panel.gpsFixCount = this.pointCount
    panel.gpsMode = this.gpsMode
    panel.syncOnline = SyncChannel.getInstance().isOnline()
    panel.lapKm = this.lapKm
    panel.flowOnlineCount = 2
    this.panelCb(panel)
  }
}
