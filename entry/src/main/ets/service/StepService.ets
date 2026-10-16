/**
 * 脉动光谷 - 计步传感器服务
 * 对应概设 M1.2 数据采集：Sensor Service Kit 计步器
 */
import { sensor } from '@kit.SensorServiceKit'
import { BusinessError } from '@kit.BasicServicesKit'

export type StepCallback = (totalSteps: number) => void

export class StepService {
  private static instance: StepService | undefined = undefined
  private subscribed: boolean = false
  private listener: StepCallback | undefined = undefined

  static getInstance(): StepService {
    if (StepService.instance === undefined) {
      StepService.instance = new StepService()
    }
    return StepService.instance
  }

  /** 订阅系统计步器（累计值，设备重启清零） */
  subscribe(callback: StepCallback): boolean {
    this.listener = callback
    if (this.subscribed) {
      return true
    }
    try {
      sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        if (this.listener !== undefined) {
          this.listener(data.steps)
        }
      }, { interval: 200000000 })
      this.subscribed = true
      return true
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[StepService] pedometer unavailable: ${err.code} ${err.message}`)
      return false
    }
  }

  unsubscribe(): void {
    if (!this.subscribed) {
      return
    }
    try {
      sensor.off(sensor.SensorId.PEDOMETER)
      this.subscribed = false
    } catch (e) {
      const err: BusinessError = e as BusinessError
      console.error(`[StepService] off failed: ${err.code}`)
    }
  }
}
