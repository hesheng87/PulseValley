/**
 * 脉动光谷 - 平板⇄手机 设备绑定服务
 * 绑定方案（对齐需求文档 6.3 平板端 / 14.6 分布式同步）：
 * 1. 绑定入口：平板"我的"页设备绑定卡 → 扫码/搜索发现手机 → 确认绑定
 * 2. 绑定通道：华为账号可信组网（AccountSyncService 已用真实 distributedKVStore
 *    + distributedDeviceManager 实现 PUSH_PULL 端端同步）
 * 3. 演示兜底：单设备环境下降级为"模拟扫码绑定"，绑定后数据一致（Local-First 同库）
 * 绑定状态经 Preferences 持久化，重启不丢失。
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { AccountSyncService } from './AccountSyncService'

export enum BindState {
  UNBOUND = 0,
  SCANNING = 1,
  BOUND = 2
}

export type BindChangedCallback = () => void

const BIND_STORE_NAME: string = 'pv_device_bind_store'
const KEY_BOUND: string = 'bound'
const KEY_DEVICE_NAME: string = 'device_name'
const KEY_BOUND_AT: string = 'bound_at'
const KEY_LAST_SYNC_TS: string = 'last_sync_ts'

export class DeviceBindService {
  private static instance: DeviceBindService | undefined = undefined

  private store: preferences.Preferences | undefined = undefined
  private state: BindState = BindState.UNBOUND
  private deviceName: string = ''
  private boundAt: number = 0
  private lastSyncTs: number = 0
  private scanTimer: number = -1
  private listener: BindChangedCallback | undefined = undefined

  static getInstance(): DeviceBindService {
    if (DeviceBindService.instance === undefined) {
      DeviceBindService.instance = new DeviceBindService()
    }
    return DeviceBindService.instance
  }

  init(context: common.UIAbilityContext): void {
    if (this.store === undefined) {
      try {
        this.store = preferences.getPreferencesSync(context, { name: BIND_STORE_NAME })
      } catch (e) {
        console.error('[DeviceBind] init preferences failed')
      }
      this.state = this.getVal(KEY_BOUND, false) as boolean
        ? BindState.BOUND : BindState.UNBOUND
      this.deviceName = this.getVal(KEY_DEVICE_NAME, '') as string
      this.boundAt = this.getVal(KEY_BOUND_AT, 0) as number
      this.lastSyncTs = this.getVal(KEY_LAST_SYNC_TS, 0) as number
    }
  }

  private getVal(key: string, def: preferences.ValueType): preferences.ValueType {
    if (this.store === undefined) {
      return def
    }
    try {
      return this.store.getSync(key, def)
    } catch (e) {
      return def
    }
  }

  private putVal(key: string, value: preferences.ValueType): void {
    if (this.store === undefined) {
      return
    }
    try {
      this.store.putSync(key, value)
    } catch (e) {
    }
  }

  private flushStore(): void {
    if (this.store === undefined) {
      return
    }
    try {
      this.store.flushSync()
    } catch (e) {
    }
  }

  setListener(listener: BindChangedCallback): void {
    this.listener = listener
  }

  getState(): BindState {
    return this.state
  }

  isBound(): boolean {
    return this.state === BindState.BOUND
  }

  getDeviceName(): string {
    return this.deviceName
  }

  getBoundAt(): number {
    return this.boundAt
  }

  getLastSyncTs(): number {
    return this.lastSyncTs
  }

  /** 开始扫码/搜索附近的手机（演示版 1.5s 后发现"我的手机"） */
  startScan(): void {
    if (this.state !== BindState.UNBOUND || this.scanTimer >= 0) {
      return
    }
    this.state = BindState.SCANNING
    this.notify()
    this.scanTimer = setTimeout((): void => {
      this.scanTimer = -1
      this.deviceName = '我的手机'
      this.state = BindState.BOUND
      this.boundAt = Date.now()
      this.lastSyncTs = Date.now()
      this.persist()
      this.notify()
    }, 1500)
  }

  /** 解除绑定 */
  unbind(): void {
    if (this.scanTimer >= 0) {
      clearTimeout(this.scanTimer)
      this.scanTimer = -1
    }
    this.state = BindState.UNBOUND
    this.deviceName = ''
    this.boundAt = 0
    this.persist()
    this.notify()
  }

  /**
   * 立即同步：优先走真实分布式 KV 端端同步（可信组网设备）；
   * 单设备演示环境下返回 0，由 UI 层降级提示"本地数据已一致"。
   */
  syncNow(): number {
    const count: number = AccountSyncService.getInstance().syncNow()
    this.lastSyncTs = Date.now()
    this.persist()
    this.notify()
    return count
  }

  private persist(): void {
    this.putVal(KEY_BOUND, this.state === BindState.BOUND)
    this.putVal(KEY_DEVICE_NAME, this.deviceName)
    this.putVal(KEY_BOUND_AT, this.boundAt)
    this.putVal(KEY_LAST_SYNC_TS, this.lastSyncTs)
    this.flushStore()
  }

  private notify(): void {
    if (this.listener !== undefined) {
      this.listener()
    }
  }
}
