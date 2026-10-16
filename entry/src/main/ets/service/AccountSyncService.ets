/**
 * 脉动光谷 - 跨设备账号数据同步服务
 * 基于 @kit.ArkData 分布式键值数据库（SingleKVStore）：
 * 1. 登录/注册/改资料/记录身体数据后，将账号数据（含身体数据）写入分布式 KV 库
 * 2. 调用 sync() 与可信组网内设备（登录同一华为账号的手机/平板）端端同步
 * 3. 订阅 dataChange，远端设备修改数据后自动合并到本地 UserService
 * 同步粒度：按账号 uid 一个 key（pv_sync_acc_<uid>），单版本库按时间最新保留，
 * 各设备登录态（activeUid/loggedIn）不同步，仅同步账号资料与身体数据。
 * 生产环境可替换为 AGC Cloud DB 云端同步。
 */
import { distributedKVStore } from '@kit.ArkData'
import { distributedDeviceManager } from '@kit.DistributedServiceKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'

const SYNC_STORE_ID: string = 'pulse_valley_sync_store'
const SYNC_KEY_PREFIX: string = 'pv_sync_acc_'
const APP_BUNDLE_NAME: string = 'com.maidong.valley'

export class AccountSyncService {
  private static instance: AccountSyncService | undefined = undefined

  private store: distributedKVStore.SingleKVStore | undefined = undefined
  private ready: boolean = false
  private lastSyncTs: number = 0
  private lastSyncDeviceCount: number = 0
  private remoteMergedCount: number = 0
  private lastError: string = ''
  private onRemoteMerged: (() => void) | undefined = undefined
  private applyRemote: ((json: string) => boolean) | undefined = undefined

  static getInstance(): AccountSyncService {
    if (AccountSyncService.instance === undefined) {
      AccountSyncService.instance = new AccountSyncService()
    }
    return AccountSyncService.instance
  }

  private constructor() {
  }

  /**
   * 初始化分布式 KV 库并订阅远端变更
   * @param applyRemote 远端数据合并回调（由 UserService 提供），返回 true 表示数据已合入本地
   * @param onMerged 合并完成后的 UI 刷新回调
   */
  init(context: common.UIAbilityContext,
    applyRemote: (json: string) => boolean,
    onMerged: () => void): void {
    this.applyRemote = applyRemote
    this.onRemoteMerged = onMerged
    if (this.ready) {
      return
    }
    try {
      const config: distributedKVStore.KVManagerConfig = {
        context: context,
        bundleName: APP_BUNDLE_NAME
      }
      const manager: distributedKVStore.KVManager = distributedKVStore.createKVManager(config)
      const options: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: true,
        backup: false,
        autoSync: false,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S1
      }
      manager.getKVStore<distributedKVStore.SingleKVStore>(SYNC_STORE_ID, options,
        (err: BusinessError, store: distributedKVStore.SingleKVStore) => {
          if (err) {
            this.lastError = `getKVStore失败 ${err.code}: ${err.message}`
            console.error(`[AccountSync] ${this.lastError}`)
            return
          }
          this.store = store
          this.ready = true
          console.info('[AccountSync] kvstore ready')
          this.subscribe()
        })
    } catch (e) {
      const error: BusinessError = e as BusinessError
      this.lastError = `初始化失败 ${error.code}: ${error.message}`
      console.error(`[AccountSync] ${this.lastError}`)
    }
  }

  isReady(): boolean {
    return this.ready
  }

  /** 最近一次错误信息（用于界面诊断提示，空串表示无错误） */
  getLastError(): string {
    return this.lastError
  }

  getLastSyncTs(): number {
    return this.lastSyncTs
  }

  getLastSyncDeviceCount(): number {
    return this.lastSyncDeviceCount
  }

  getRemoteMergedCount(): number {
    return this.remoteMergedCount
  }

  /** 订阅分布式数据变化（本地 + 远端），远端数据自动合并到本地 */
  private subscribe(): void {
    if (this.store === undefined) {
      return
    }
    try {
      this.store.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_REMOTE,
        (data: distributedKVStore.ChangeNotification) => {
          const entries: distributedKVStore.Entry[] = data.insertEntries
            .concat(data.updateEntries)
          for (let i = 0; i < entries.length; i++) {
            const key: string = entries[i].key
            if (!key.startsWith(SYNC_KEY_PREFIX)) {
              continue
            }
            const value: string = entries[i].value.value as string
            if (this.applyRemote !== undefined && this.applyRemote(value)) {
              this.remoteMergedCount += 1
            }
          }
          if (this.remoteMergedCount > 0 && this.onRemoteMerged !== undefined) {
            this.onRemoteMerged()
          }
        })
    } catch (e) {
      const error: BusinessError = e as BusinessError
      console.error(`[AccountSync] subscribe failed: ${error.code} ${error.message}`)
    }
  }

  /** 发布账号数据到分布式 KV 库（写入即可被 sync 推送到组网设备） */
  publishAccount(uid: string, json: string): void {
    if (!this.ready || this.store === undefined) {
      return
    }
    try {
      this.store.put(SYNC_KEY_PREFIX + uid, json, (err: BusinessError) => {
        if (err) {
          console.error(`[AccountSync] put failed: ${err.code} ${err.message}`)
        }
      })
    } catch (e) {
      const error: BusinessError = e as BusinessError
      console.error(`[AccountSync] put exception: ${error.code} ${error.message}`)
    }
  }

  /** 可信组网内设备列表（networkId） */
  private getDeviceIds(): string[] {
    const ids: string[] = []
    try {
      const manager: distributedDeviceManager.DeviceManager =
        distributedDeviceManager.createDeviceManager(APP_BUNDLE_NAME)
      const devices: Array<distributedDeviceManager.DeviceBasicInfo> =
        manager.getAvailableDeviceListSync()
      for (let i = 0; i < devices.length; i++) {
        const networkId: string | undefined = devices[i].networkId
        if (networkId !== undefined && networkId !== '') {
          ids.push(networkId)
        }
      }
      distributedDeviceManager.releaseDeviceManager(manager)
      console.info(`[AccountSync] trusted devices online: ${ids.length}`)
      if (ids.length === 0) {
        this.lastError = '组网内没有可信设备：请确认两台设备已登录同一华为账号并开启多设备协同'
      }
    } catch (e) {
      const error: BusinessError = e as BusinessError
      this.lastError = `获取可信设备失败 ${error.code}: ${error.message}`
      console.error(`[AccountSync] deviceManager failed: ${this.lastError}`)
    }
    return ids
  }

  /**
   * 端端同步：将本端账号数据推送到组网设备，同时拉取远端账号数据
   * 返回同步的设备数（0 表示组网内无其他设备）
   */
  syncNow(): number {
    if (!this.ready || this.store === undefined) {
      return 0
    }
    const deviceIds: string[] = this.getDeviceIds()
    if (deviceIds.length === 0) {
      return 0
    }
    try {
      this.store.sync(deviceIds, distributedKVStore.SyncMode.PUSH_PULL, 1000)
      this.lastSyncTs = Date.now()
      this.lastSyncDeviceCount = deviceIds.length
      this.lastError = ''
    } catch (e) {
      const error: BusinessError = e as BusinessError
      this.lastError = `端端同步失败 ${error.code}: ${error.message}`
      console.error(`[AccountSync] ${this.lastError}`)
      return 0
    }
    return deviceIds.length
  }
}
