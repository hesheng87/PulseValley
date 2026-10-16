/**
 * 环境域：GET /v1/env/aqi?lng=&lat=
 * 和风天气双源冗余代理（架构文档 5.x）：
 *   1. 配置环境变量 QWEATHER_KEY 时走和风天气 API（3s 超时）
 *   2. 失败/未配置降级为校园合成源（与端侧演示曲线一致，保证降级链路可用）
 */
import https from 'node:https'
import { ok } from '../response.js'

const QWEATHER_HOST = 'devapi.qweather.com'
const QWEATHER_KEY = process.env.QWEATHER_KEY || ''
const QWEATHER_TIMEOUT_MS = 3000

/** 校园 AQI 日内曲线：早晚高峰偏高，午后偏低（与端侧 EnvService 演示源一致） */
function campusSynthetic(now) {
  const hour = new Date(now).getHours()
  const baseAqi = 42 + Math.round(38 * Math.sin((hour - 7) * Math.PI / 12))
  const aqi = Math.max(18, Math.min(baseAqi, 165))
  return {
    aqi,
    pm25: Math.round(aqi * 0.72),
    temp: 16 + Math.round(10 * Math.sin((hour - 9) * Math.PI / 13)),
    humidity: 45 + (hour % 5) * 6,
    uv: hour >= 10 && hour <= 15 ? 6 + (hour % 3) : 2,
    wind: 2 + (hour % 4),
    source: 'campus-synthetic',
    updatedAt: now,
    isStale: false
  }
}

/** 和风天气代理（geo 免费接口不支持 AQI 的场景下降级） */
function fetchQweather(lng, lat) {
  return new Promise((resolve, reject) => {
    if (!QWEATHER_KEY) {
      reject(new Error('QWEATHER_KEY not configured'))
      return
    }
    const path = `/v7/air/now?location=${encodeURIComponent(lng)},${encodeURIComponent(lat)}&key=${QWEATHER_KEY}`
    const req = https.get({ host: QWEATHER_HOST, path, timeout: QWEATHER_TIMEOUT_MS }, (resp) => {
      let raw = ''
      resp.on('data', (c) => { raw += c })
      resp.on('end', () => {
        try {
          const data = JSON.parse(raw)
          if (data.code !== '200' || !data.now) {
            reject(new Error(`qweather code ${data.code}`))
            return
          }
          resolve({
            aqi: Number(data.now.aqi || 50),
            pm25: Number(data.now.pm2p5 || 20),
            temp: 24,
            humidity: 55,
            uv: 3,
            wind: 3,
            source: 'qweather-proxy',
            updatedAt: Date.now(),
            isStale: false
          })
        } catch (e) {
          reject(e)
        }
      })
    })
    req.on('timeout', () => { req.destroy(new Error('qweather timeout')) })
    req.on('error', reject)
  })
}

export async function aqi(res, lng, lat) {
  const now = Date.now()
  try {
    const snapshot = await fetchQweather(lng || '114.42', lat || '30.52')
    ok(res, snapshot)
  } catch (e) {
    // 降级链路：第三方源失败 → 最近已知值/合成源（概设 6.3）
    ok(res, campusSynthetic(now), 'degraded to campus-synthetic source')
  }
}
