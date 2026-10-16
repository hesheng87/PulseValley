/**
 * 脉动光谷 - 分布式同步通道
 * 基于 @ohos.data.distributedDataObject（软总线）：
 * 手机(MAIN)与手表/平板(COLLECTOR)共享同一 SportSyncSource，字段级实时互刷。
 * 对应《架构设计文档》5.1 / 《详细设计文档》3.3
 */
import { distributedDataObject } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { SportSyncSource } from '../common/Types'

export type SyncChangeCallback = (fields: string[]) => void

export class SyncChannel {
  private static instance: SyncChannel | undefined = undefined
  private source: SportSyncSource = new SportSyncSource()
  private ddo: distributedDataObject.DataObject | undefined = undefined
  private sessionId: string = ''
  private online: boolean = false
  private changeListener: SyncChangeCallback | undefined = undefined

  static getInstance(): SyncChannel {
    if (SyncChannel.instance === undefined) {
      SyncChannel.instance = new SyncChannel()
    }
    return SyncChannel.instance
  }

  getSource(): SportSyncSource {
    return this.source
  }

  isOnline(): boolean {
    return this.online
  }

  /** 创建分布式数据对象并加入会话组网；失败降级为仅本机模式 */
  open(context: common.UIAbilityContext, sessionId: string, onChange: SyncChangeCallback): boolean {
    this.changeListener = onChange
    this.sessionId = sessionId
    try {
      if (this.ddo === undefined) {
        this.ddo = distributedDataObject.create(context, this.source)
        this.ddo.on('change', (sid: string, fields: Array<string>) => {
          if (this.changeListener !== undefined) {
            this.changeListener(fields)
          }
        })
      }
      this.source.sessionId = sessionId
      this.ddo.setSessionId(sessionId, (): void => {
        this.online = true
        console.info(`[SyncChannel] joined session ${sessionId}`)
      })
      return true
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[SyncChannel] open failed: ${err.code} ${err.message}，降级为仅本机模式`)
      this.online = false
      return false
    }
  }

  /** 写入共享字段（单一写者原则：distanceM/pace 仅 MAIN 写） */
  publish(): void {
    this.source.lastBeatTs = Date.now()
  }

  /** 退出组网 */
  close(): void {
    if (this.ddo === undefined) {
      return
    }
    try {
      this.ddo.setSessionId('', (): void => {
        console.info('[SyncChannel] left session')
      })
    } catch (e) {
      console.error('[SyncChannel] close failed')
    }
    this.online = false
  }
}
