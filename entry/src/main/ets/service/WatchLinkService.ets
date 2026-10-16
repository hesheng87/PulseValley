/**
 * 脉动光谷 - 手表端蓝牙连接与账号服务（纯软件演示）
 * 手表端专属：
 * 1. 蓝牙快速连接手机：扫描 → 快速配对 → 自动回连已保存手机（生产环境替换为真实 BLE 扫描连接）
 * 2. 账号保存：连接后同步账号并经 Preferences 持久化，下次启动自动回连免登录
 * 3. 消息提醒中心：手表端统一消息入口（连接/账号/运动提醒），写入时震动
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { vibrator } from '@kit.SensorServiceKit'

const WATCH_STORE: string = 'watch_store'
const KEY_PAIRED_PHONE: string = 'watch_paired_phone'
const KEY_ACCOUNT: string = 'watch_account'
const SCAN_COST_MS: number = 1500

export enum WatchLinkStatus {
  DISCONNECTED = 0,
  SCANNING = 1,
  CONNECTED = 2
}

/** 已配对手机（蓝牙快速连接目标） */
export class PairedPhone {
  name: string = ''
  mac: string = ''
  autoConnect: boolean = true
  pairedTs: number = 0

  static of(name: string, mac: string, autoConnect: boolean, pairedTs: number): PairedPhone {
    const p: PairedPhone = new PairedPhone()
    p.name = name
    p.mac = mac
    p.autoConnect = autoConnect
    p.pairedTs = pairedTs
    return p
  }
}

/** 手表端保存的账号 */
export class WatchAccount {
  nickname: string = ''
  phoneNo: string = ''
  syncedTs: number = 0

  static of(nickname: string, phoneNo: string, syncedTs: number): WatchAccount {
    const a: WatchAccount = new WatchAccount()
    a.nickname = nickname
    a.phoneNo = phoneNo
    a.syncedTs = syncedTs
    return a
  }
}

/** 手表端消息条目 */
export class WatchMessage {
  id: number = 0
  emoji: string = '📣'
  text: string = ''
  ts: number = 0

  static of(id: number, emoji: string, text: string, ts: number): WatchMessage {
    const m: WatchMessage = new WatchMessage()
    m.id = id
    m.emoji = emoji
    m.text = text
    m.ts = ts
    return m
  }
}

export class WatchLinkService {
  private static instance: WatchLinkService | undefined = undefined

  private store: preferences.Preferences | undefined = undefined
  private status: WatchLinkStatus = WatchLinkStatus.DISCONNECTED
  private pairedPhone: PairedPhone = new PairedPhone()
  private account: WatchAccount = new WatchAccount()
  private messages: WatchMessage[] = []
  private nextMsgId: number = 1
  private scanTimer: number = -1

  static getInstance(): WatchLinkService {
    if (WatchLinkService.instance === undefined) {
      WatchLinkService.instance = new WatchLinkService()
    }
    return WatchLinkService.instance
  }

  init(context: common.UIAbilityContext): void {
    if (this.store === undefined) {
      try {
        this.store = preferences.getPreferencesSync(context, { name: WATCH_STORE })
      } catch (e) {
        console.error('[WatchLink] init preferences failed')
      }
      this.pairedPhone = this.loadPairedPhone()
      this.account = this.loadAccount()
      if (this.pairedPhone.name !== '') {
        this.pushMessage('🔗', `已保存配对手机 ${this.pairedPhone.name}，可快速回连`)
      }
      if (this.account.nickname !== '') {
        this.pushMessage('👤', `账号 ${this.account.nickname} 已保存`)
      }
    }
  }

  private ensureStore(): preferences.Preferences {
    if (this.store === undefined) {
      throw new Error('WatchLinkService not initialized')
    }
    return this.store
  }

  private getStr(key: string, def: string): string {
    try {
      return this.ensureStore().getSync(key, def) as string
    } catch (e) {
      return def
    }
  }

  private putVal(key: string, value: preferences.ValueType): void {
    try {
      this.ensureStore().putSync(key, value)
    } catch (e) {
    }
  }

  private delKey(key: string): void {
    try {
      this.ensureStore().deleteSync(key)
    } catch (e) {
    }
  }

  private flushStore(): void {
    try {
      this.ensureStore().flush()
    } catch (e) {
    }
  }

  /** ---------- 蓝牙快速连接 ---------- */

  getStatus(): WatchLinkStatus {
    return this.status
  }

  isConnected(): boolean {
    return this.status === WatchLinkStatus.CONNECTED
  }

  getPairedPhone(): PairedPhone {
    return this.pairedPhone
  }

  hasPairedPhone(): boolean {
    return this.pairedPhone.name !== ''
  }

  /**
   * 蓝牙快速连接手机（纯软件演示）：
   * 扫描约 1.5 秒 → 优先回连已保存手机，否则发现新手机并配对保存。
   * 连接成功后自动同步账号并持久化，下次启动可免配对直连。
   */
  scanAndConnect(): void {
    if (this.status !== WatchLinkStatus.DISCONNECTED) {
      return
    }
    this.status = WatchLinkStatus.SCANNING
    if (this.scanTimer >= 0) {
      clearTimeout(this.scanTimer)
    }
    this.scanTimer = setTimeout((): void => {
      this.scanTimer = -1
      let phone: PairedPhone = this.pairedPhone
      if (phone.name === '') {
        phone = PairedPhone.of('我的手机 (PulseValley)', '8C:BF:EA:2D:71:06', true, Date.now())
        this.pairedPhone = phone
        this.savePairedPhone(phone)
      }
      this.status = WatchLinkStatus.CONNECTED
      this.vibrate(200)
      this.pushMessage('🔗', `蓝牙已快速连接 ${phone.name}`)
      if (this.account.nickname === '') {
        this.syncAccountFromPhone('跑者小光', '138****6688')
      }
    }, SCAN_COST_MS)
  }

  /** 断开蓝牙连接（配对与账号仍保留，可再次快速回连） */
  disconnect(): void {
    if (this.scanTimer >= 0) {
      clearTimeout(this.scanTimer)
      this.scanTimer = -1
    }
    this.status = WatchLinkStatus.DISCONNECTED
    this.pushMessage('⚪', '已断开手机连接，账号与配对信息仍已保存')
  }

  /** 解除配对并清除保存的账号 */
  unpairAndClearAccount(): void {
    this.disconnect()
    this.pairedPhone = new PairedPhone()
    this.account = new WatchAccount()
    this.delKey(KEY_PAIRED_PHONE)
    this.delKey(KEY_ACCOUNT)
    this.pushMessage('🗑️', '已解除配对并清除保存的账号')
  }

  /** ---------- 账号保存 ---------- */

  getAccount(): WatchAccount {
    return this.account
  }

  hasAccount(): boolean {
    return this.account.nickname !== ''
  }

  /** 连接手机后自动同步账号（演示：手机侧账号下发） */
  private syncAccountFromPhone(nickname: string, phoneNo: string): void {
    this.account = WatchAccount.of(nickname, phoneNo, Date.now())
    this.saveAccount(this.account.nickname, this.account.phoneNo)
    this.pushMessage('👤', `账号 ${nickname} 已从手机同步并保存`)
  }

  /** 手动修改账号并持久化保存 */
  saveAccount(nickname: string, phoneNo: string): void {
    this.account = WatchAccount.of(nickname, phoneNo, Date.now())
    this.putVal(KEY_ACCOUNT, JSON.stringify(this.account))
    this.flushStore()
  }

  private loadAccount(): WatchAccount {
    const raw: string = this.getStr(KEY_ACCOUNT, '')
    if (raw === '') {
      return new WatchAccount()
    }
    try {
      const o: Record<string, Object> = JSON.parse(raw) as Record<string, Object>
      return WatchAccount.of((o['nickname'] ?? '') as string, (o['phoneNo'] ?? '') as string,
        (o['syncedTs'] ?? 0) as number)
    } catch (e) {
      return new WatchAccount()
    }
  }

  private savePairedPhone(phone: PairedPhone): void {
    this.putVal(KEY_PAIRED_PHONE, JSON.stringify(phone))
    this.flushStore()
  }

  private loadPairedPhone(): PairedPhone {
    const raw: string = this.getStr(KEY_PAIRED_PHONE, '')
    if (raw === '') {
      return new PairedPhone()
    }
    try {
      const o: Record<string, Object> = JSON.parse(raw) as Record<string, Object>
      return PairedPhone.of((o['name'] ?? '') as string, (o['mac'] ?? '') as string,
        (o['autoConnect'] ?? true) as boolean, (o['pairedTs'] ?? 0) as number)
    } catch (e) {
      return new PairedPhone()
    }
  }

  /** ---------- 消息提醒 ---------- */

  getMessages(): WatchMessage[] {
    return this.messages
  }

  /** 写入一条手表消息并震动提醒 */
  pushMessage(emoji: string, text: string): WatchMessage {
    const msg: WatchMessage = WatchMessage.of(this.nextMsgId, emoji, text, Date.now())
    this.nextMsgId += 1
    this.messages.unshift(msg)
    if (this.messages.length > 20) {
      this.messages.splice(20, this.messages.length - 20)
    }
    this.vibrate(200)
    return msg
  }

  /** 手表震动（运动结束/消息/连接提醒） */
  vibrate(durationMs: number): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: durationMs
      }, {
        id: 0,
        usage: 'notification'
      }).then((): void => {
      }).catch((e: BusinessError): void => {
        console.error(`[WatchLink] vibrate failed: ${e.message}`)
      })
    } catch (e) {
      // 演示环境无震动马达时静默降级
    }
  }
}
