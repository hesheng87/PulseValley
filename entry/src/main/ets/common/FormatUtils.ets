/**
 * 脉动光谷 - 格式化工具
 */
import { SportType } from './Types'

export class FormatUtils {
  /** 毫秒时间戳 → HH:mm */
  static timeOf(ts: number): string {
    const d: Date = new Date(ts)
    const h: string = d.getHours() < 10 ? `0${d.getHours()}` : `${d.getHours()}`
    const m: string = d.getMinutes() < 10 ? `0${d.getMinutes()}` : `${d.getMinutes()}`
    return `${h}:${m}`
  }

  /** 秒数 → HH:MM:SS */
  static durationOf(totalSec: number): string {
    const s: number = Math.floor(totalSec % 60)
    const m: number = Math.floor(totalSec / 60) % 60
    const h: number = Math.floor(totalSec / 3600)
    const ss: string = s < 10 ? `0${s}` : `${s}`
    const mm: string = m < 10 ? `0${m}` : `${m}`
    const hh: string = h < 10 ? `0${h}` : `${h}`
    return `${hh}:${mm}:${ss}`
  }

  /** 米 → "x.xx" 公里数值 */
  static kmOf(distanceM: number): string {
    return (distanceM / 1000).toFixed(2)
  }

  /** 秒/公里 → "M'S''" 配速文本 */
  static paceOf(paceSecPerKm: number): string {
    if (paceSecPerKm <= 0) {
      return "--'--''"
    }
    const m: number = Math.floor(paceSecPerKm / 60)
    const s: number = Math.floor(paceSecPerKm % 60)
    const ss: string = s < 10 ? `0${s}` : `${s}`
    return `${m}'${ss}''`
  }

  static sportNameOf(type: SportType): string {
    if (type === SportType.RUN) {
      return '跑步'
    }
    if (type === SportType.RIDE) {
      return '骑行'
    }
    return '健走'
  }

  static dateKeyOf(ts: number): string {
    const d: Date = new Date(ts)
    const m: number = d.getMonth() + 1
    const day: number = d.getDate()
    return `${d.getFullYear()}-${m < 10 ? `0${m}` : `${m}`}-${day < 10 ? `0${day}` : `${day}`}`
  }
}
