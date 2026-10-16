/**
 * 脉动光谷 - 用户账号服务（纯软件演示）
 * 1. 多账号注册：手机号注册（验证码演示 123456）/ 华为账号一键注册（模拟 Account Kit）
 *    注册过的账号全部保存在本地文件（preferences 持久化），一台设备可注册/登录多个账号
 * 2. 登录 / 退出登录：退出后可用本机任意已注册账号登录，当前登录态持久化，重启免登录
 * 3. 个人资料：换头像（emoji 头像）、个性签名（资料随账号保存）
 * 4. 身体数据：体重 / 体脂率记录，趋势对比（按账号隔离存储）
 * 生产环境替换为真实 Account Kit（华为账号）与短信验证码服务。
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { AccountSyncService } from './AccountSyncService'
import { StoreService } from './StoreService'
import { SportRecord, UserStats } from '../common/Types'

const USER_STORE: string = 'user_store'
const KEY_ACCOUNTS: string = 'user_accounts'
const KEY_ACTIVE_UID: string = 'user_active_uid'
const KEY_BODY_METRICS: string = 'body_metrics_'
const DEMO_VERIFY_CODE: string = '123456'

export enum RegisterType {
  PHONE = 0,
  HUAWEI = 1
}

/** 用户账号（含个人资料，登录态单独管理） */
export class UserAccount {
  uid: string = ''
  nickname: string = ''
  phone: string = ''
  registerType: RegisterType = RegisterType.PHONE
  avatar: string = '🏃'
  signature: string = ''
  registeredTs: number = 0
  updatedAt: number = 0

  static of(uid: string, nickname: string, phone: string, registerType: RegisterType,
    avatar: string, signature: string, registeredTs: number): UserAccount {
    const a: UserAccount = new UserAccount()
    a.uid = uid
    a.nickname = nickname
    a.phone = phone
    a.registerType = registerType
    a.avatar = avatar
    a.signature = signature
    a.registeredTs = registeredTs
    a.updatedAt = registeredTs
    return a
  }
}

/** 一条身体数据记录（体重 / 体脂率） */
export class BodyMetric {
  ts: number = 0
  weightKg: number = 0
  bodyFatPct: number = 0

  static of(ts: number, weightKg: number, bodyFatPct: number): BodyMetric {
    const m: BodyMetric = new BodyMetric()
    m.ts = ts
    m.weightKg = weightKg
    m.bodyFatPct = bodyFatPct
    return m
  }
}

export class UserService {
  private static instance: UserService | undefined = undefined

  private store: preferences.Preferences | undefined = undefined
  private accounts: UserAccount[] = []
  private activeUid: string = ''
  private loggedIn: boolean = false
  private metrics: BodyMetric[] = []

  static getInstance(): UserService {
    if (UserService.instance === undefined) {
      UserService.instance = new UserService()
    }
    return UserService.instance
  }

  init(context: common.UIAbilityContext): void {
    if (this.store === undefined) {
      try {
        this.store = preferences.getPreferencesSync(context, { name: USER_STORE })
      } catch (e) {
        console.error('[UserService] init preferences failed')
      }
      this.accounts = this.loadAccounts()
      const savedUid: string = this.getStr(KEY_ACTIVE_UID, '')
      if (savedUid !== '') {
        const acc: UserAccount | undefined = this.findByUid(savedUid)
        if (acc !== undefined) {
          this.activeUid = savedUid
          this.loggedIn = true
        }
      }
      this.metrics = this.loadMetrics()
      // 运动记录保存后自动发布到当前账号（跨设备同步）
      StoreService.getInstance().init(context)
      StoreService.getInstance().setOnRecordSaved((): void => {
        if (this.loggedIn) {
          this.publishSync(this.activeUid)
        }
      })
    }
  }

  private ensureStore(): preferences.Preferences {
    if (this.store === undefined) {
      throw new Error('UserService not initialized')
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

  /** ---------- 注册 / 登录 / 退出 ---------- */

  /** 本机是否已注册过任意账号 */
  hasAccount(): boolean {
    return this.accounts.length > 0
  }

  isLoggedIn(): boolean {
    return this.loggedIn
  }

  getAccount(): UserAccount {
    const acc: UserAccount | undefined = this.findByUid(this.activeUid)
    if (acc === undefined) {
      return new UserAccount()
    }
    return acc
  }

  /** 本机已注册的全部账号（新注册的在前） */
  getLocalAccounts(): UserAccount[] {
    return this.accounts
  }

  private findByUid(uid: string): UserAccount | undefined {
    for (let i = 0; i < this.accounts.length; i++) {
      if (this.accounts[i].uid === uid) {
        return this.accounts[i]
      }
    }
    return undefined
  }

  private findByPhone(phone: string): UserAccount | undefined {
    for (let i = 0; i < this.accounts.length; i++) {
      if (this.accounts[i].registerType === RegisterType.PHONE && this.accounts[i].phone === phone) {
        return this.accounts[i]
      }
    }
    return undefined
  }

  /**
   * 手机号注册并自动登录（允许同一设备注册多个账号，手机号不可重复）
   * 返回 '' 表示成功，否则为错误提示
   */
  registerWithPhone(nickname: string, phone: string, code: string): string {
    if (nickname.trim() === '') {
      return '请输入昵称'
    }
    if (!this.isValidPhone(phone)) {
      return '请输入正确的 11 位手机号'
    }
    if (this.findByPhone(phone) !== undefined) {
      return '该手机号已在本机注册，请直接登录'
    }
    if (code !== DEMO_VERIFY_CODE) {
      return `验证码错误（演示验证码 ${DEMO_VERIFY_CODE}）`
    }
    const acc: UserAccount = UserAccount.of(`p_${phone}`, nickname.trim(), phone, RegisterType.PHONE,
      '🏃', '运动使我快乐！', Date.now())
    this.accounts.unshift(acc)
    this.saveAccounts()
    this.setActive(acc.uid)
    this.publishSync(acc.uid)
    return ''
  }

  /** 华为账号一键注册并自动登录（演示：模拟 Account Kit 授权回传，可注册多个） */
  registerWithHuawei(): string {
    const suffix: number = 1000 + Math.floor(Math.random() * 9000)
    const acc: UserAccount = UserAccount.of(`h_${Date.now()}_${suffix}`, `华为用户${suffix}`, '',
      RegisterType.HUAWEI, '🎧', '来自华为账号一键注册', Date.now())
    this.accounts.unshift(acc)
    this.saveAccounts()
    this.setActive(acc.uid)
    this.publishSync(acc.uid)
    return ''
  }

  /** 手机号 + 验证码登录（可用本机任意已注册账号；未找到时自动从组网设备拉取） */
  loginByPhone(phone: string, code: string): string {
    const acc: UserAccount | undefined = this.findByPhone(phone)
    if (acc === undefined) {
      // 本机没有该账号：尝试从可信组网设备（如手机）拉取账号数据
      const pulled: number = AccountSyncService.getInstance().syncNow()
      return pulled > 0
        ? '该手机号未在本机注册，正在从组网设备拉取账号，请稍后在下方账号列表点击登录'
        : '该手机号未在本机注册，请先注册（或确认两台设备已登录同一华为账号组网）'
    }
    if (code !== DEMO_VERIFY_CODE) {
      return `验证码错误（演示验证码 ${DEMO_VERIFY_CODE}）`
    }
    this.setActive(acc.uid)
    return ''
  }

  /** 演示快选登录：点击本机已注册账号直接登录（免验证） */
  quickLogin(uid: string): string {
    const acc: UserAccount | undefined = this.findByUid(uid)
    if (acc === undefined) {
      return '账号不存在'
    }
    this.setActive(acc.uid)
    return ''
  }

  /** 华为账号一键登录（登录本机最近注册的华为账号） */
  loginByHuawei(): string {
    for (let i = 0; i < this.accounts.length; i++) {
      if (this.accounts[i].registerType === RegisterType.HUAWEI) {
        this.setActive(this.accounts[i].uid)
        return ''
      }
    }
    return '本机尚未注册华为账号，请先注册'
  }

  /** 切换当前账号（登录态） */
  private setActive(uid: string): void {
    this.activeUid = uid
    this.loggedIn = true
    this.putVal(KEY_ACTIVE_UID, uid)
    this.flushStore()
    this.metrics = this.loadMetrics()
  }

  /** 退出登录（保留本机注册的所有账号，下次可用任意账号登录） */
  logout(): void {
    this.loggedIn = false
    this.activeUid = ''
    this.metrics = []
    this.delKey(KEY_ACTIVE_UID)
    this.flushStore()
  }

  private isValidPhone(phone: string): boolean {
    if (phone.length !== 11 || phone[0] !== '1') {
      return false
    }
    for (let i = 0; i < phone.length; i++) {
      if (phone[i] < '0' || phone[i] > '9') {
        return false
      }
    }
    return true
  }

  /** ---------- 个人资料：头像 / 个性签名 ---------- */

  updateAvatar(avatar: string): void {
    const acc: UserAccount | undefined = this.findByUid(this.activeUid)
    if (acc === undefined) {
      return
    }
    acc.avatar = avatar
    acc.updatedAt = Date.now()
    this.saveAccounts()
    this.publishSync(acc.uid)
  }

  updateSignature(signature: string): void {
    const acc: UserAccount | undefined = this.findByUid(this.activeUid)
    if (acc === undefined) {
      return
    }
    acc.signature = signature
    acc.updatedAt = Date.now()
    this.saveAccounts()
    this.publishSync(acc.uid)
  }

  /** ---------- 身体数据：体重 / 体脂率（按账号隔离） ---------- */

  /** 新增一条记录，返回 '' 表示成功，否则为错误提示 */
  addBodyMetric(weightKg: number, bodyFatPct: number): string {
    if (Number.isNaN(weightKg) || weightKg < 20 || weightKg > 300) {
      return '请输入正确的体重（20-300 kg）'
    }
    if (Number.isNaN(bodyFatPct) || bodyFatPct < 2 || bodyFatPct > 60) {
      return '请输入正确的体脂率（2-60 %）'
    }
    this.metrics.unshift(BodyMetric.of(Date.now(),
      Math.round(weightKg * 10) / 10, Math.round(bodyFatPct * 10) / 10))
    if (this.metrics.length > 50) {
      this.metrics.splice(50, this.metrics.length - 50)
    }
    this.saveMetrics()
    const acc: UserAccount | undefined = this.findByUid(this.activeUid)
    if (acc !== undefined) {
      acc.updatedAt = Date.now()
      this.saveAccounts()
      this.publishSync(acc.uid)
    }
    return ''
  }

  getBodyMetrics(): BodyMetric[] {
    return this.metrics
  }

  getLatestMetric(): BodyMetric | undefined {
    if (this.metrics.length === 0) {
      return undefined
    }
    return this.metrics[0]
  }

  /** 较上次体重变化（kg），无对比记录返回 0 */
  weightDeltaKg(): number {
    if (this.metrics.length < 2) {
      return 0
    }
    return Math.round((this.metrics[0].weightKg - this.metrics[1].weightKg) * 10) / 10
  }

  /** ---------- 持久化 ---------- */

  private saveAccounts(): void {
    this.putVal(KEY_ACCOUNTS, JSON.stringify(this.accounts))
    this.flushStore()
  }

  private loadAccounts(): UserAccount[] {
    const raw: string = this.getStr(KEY_ACCOUNTS, '')
    if (raw === '') {
      return []
    }
    try {
      const arr: object[] = JSON.parse(raw) as object[]
      const list: UserAccount[] = []
      for (let i = 0; i < arr.length; i++) {
        const o: Record<string, Object> = arr[i] as Record<string, Object>
        const registerTypeNum: number = (o['registerType'] ?? 0) as number
        list.push(UserAccount.of(
          (o['uid'] ?? '') as string,
          (o['nickname'] ?? '') as string,
          (o['phone'] ?? '') as string,
          registerTypeNum === RegisterType.HUAWEI ? RegisterType.HUAWEI : RegisterType.PHONE,
          (o['avatar'] ?? '🏃') as string,
          (o['signature'] ?? '') as string,
          (o['registeredTs'] ?? 0) as number))
        const loaded: UserAccount = list[list.length - 1]
        loaded.updatedAt = (o['updatedAt'] ?? loaded.registeredTs) as number
      }
      return list
    } catch (e) {
      return []
    }
  }

  private metricsKey(uid: string): string {
    return KEY_BODY_METRICS + uid
  }

  private saveMetrics(): void {
    this.saveMetricsFor(this.activeUid, this.metrics)
  }

  private saveMetricsFor(uid: string, list: BodyMetric[]): void {
    this.putVal(this.metricsKey(uid), JSON.stringify(list))
    this.flushStore()
  }

  private loadMetrics(): BodyMetric[] {
    return this.loadMetricsFor(this.activeUid)
  }

  private loadMetricsFor(uid: string): BodyMetric[] {
    if (uid === '') {
      return []
    }
    const raw: string = this.getStr(this.metricsKey(uid), '[]')
    try {
      const arr: object[] = JSON.parse(raw) as object[]
      const list: BodyMetric[] = []
      for (let i = 0; i < arr.length; i++) {
        const o: Record<string, Object> = arr[i] as Record<string, Object>
        list.push(BodyMetric.of((o['ts'] ?? 0) as number,
          (o['weightKg'] ?? 0) as number, (o['bodyFatPct'] ?? 0) as number))
      }
      return list
    } catch (e) {
      return []
    }
  }

  /** ---------- 跨设备同步（分布式 KV 库） ---------- */

  /** 账号同步数据包（账号资料 + 身体数据 + 运动记录） */
  private buildSyncPayload(acc: UserAccount, metrics: BodyMetric[]): string {
    const payload: Record<string, Object> = {
      'uid': acc.uid,
      'nickname': acc.nickname,
      'phone': acc.phone,
      'registerType': acc.registerType as number,
      'avatar': acc.avatar,
      'signature': acc.signature,
      'registeredTs': acc.registeredTs,
      'updatedAt': acc.updatedAt,
      'metrics': metrics as Object,
      'records': StoreService.getInstance().getRecords() as Object
    }
    return JSON.stringify(payload)
  }

  /** 将账号数据发布到分布式 KV 库（等待端端同步） */
  private publishSync(uid: string): void {
    const acc: UserAccount | undefined = this.findByUid(uid)
    if (acc === undefined) {
      return
    }
    const metrics: BodyMetric[] = uid === this.activeUid ? this.metrics : this.loadMetricsFor(uid)
    AccountSyncService.getInstance().publishAccount(uid, this.buildSyncPayload(acc, metrics))
  }

  /** 手动触发端端同步（登录后拉取其他设备上的该账号数据） */
  syncNow(): number {
    return AccountSyncService.getInstance().syncNow()
  }

  /**
   * 合并远端设备同步来的账号数据（由 AccountSyncService 回调）
   * 冲突规则：updatedAt 新者胜；返回 true 表示本地数据已更新
   */
  applyRemoteAccountJson(json: string): boolean {
    try {
      const o: Record<string, Object> = JSON.parse(json) as Record<string, Object>
      const uid: string = (o['uid'] ?? '') as string
      if (uid === '') {
        return false
      }
      const registerTypeNum: number = (o['registerType'] ?? 0) as number
      const remoteUpdatedAt: number = (o['updatedAt'] ?? 0) as number
      const remoteMetrics: BodyMetric[] = this.parseMetricList((o['metrics'] ?? []) as object[])
      const remoteRecords: SportRecord[] =
        StoreService.getInstance().parseRecordObjects((o['records'] ?? []) as object[])
      const local: UserAccount | undefined = this.findByUid(uid)
      if (local === undefined) {
        const acc: UserAccount = UserAccount.of(uid,
          (o['nickname'] ?? '') as string,
          (o['phone'] ?? '') as string,
          registerTypeNum === RegisterType.HUAWEI ? RegisterType.HUAWEI : RegisterType.PHONE,
          (o['avatar'] ?? '🏃') as string,
          (o['signature'] ?? '') as string,
          (o['registeredTs'] ?? Date.now()) as number)
        acc.updatedAt = remoteUpdatedAt
        this.accounts.unshift(acc)
        this.saveMetricsFor(uid, remoteMetrics)
        if (uid === this.activeUid) {
          this.metrics = remoteMetrics.slice()
        }
        this.saveAccounts()
        StoreService.getInstance().mergeRecords(remoteRecords)
        return true
      }
      // 运动记录按 id 去重合并（幂等，随时可合）
      const recordsMerged: boolean = StoreService.getInstance().mergeRecords(remoteRecords)
      if (remoteUpdatedAt <= local.updatedAt) {
        return recordsMerged
      }
      local.nickname = (o['nickname'] ?? local.nickname) as string
      local.phone = (o['phone'] ?? local.phone) as string
      local.avatar = (o['avatar'] ?? local.avatar) as string
      local.signature = (o['signature'] ?? local.signature) as string
      local.updatedAt = remoteUpdatedAt
      this.saveMetricsFor(uid, remoteMetrics)
      if (uid === this.activeUid) {
        this.metrics = remoteMetrics.slice()
      }
      this.saveAccounts()
      return true
    } catch (e) {
      return false
    }
  }

  private parseMetricList(arr: object[]): BodyMetric[] {
    const list: BodyMetric[] = []
    for (let i = 0; i < arr.length; i++) {
      const o: Record<string, Object> = arr[i] as Record<string, Object>
      list.push(BodyMetric.of((o['ts'] ?? 0) as number,
        (o['weightKg'] ?? 0) as number, (o['bodyFatPct'] ?? 0) as number))
    }
    return list
  }
}
