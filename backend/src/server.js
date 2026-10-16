/**
 * 脉动光谷 - 后端服务入口
 * 对应《架构设计文档》AGC 云端四部分的本地等价实现（零依赖，Node.js 原生 http）：
 *   用户域：/v1/auth/*            账号登录、token 签发、资料
 *   运动域：/v1/record/*          运动摘要上报（风控防作弊校验）、记录列表
 *   挑战域：/v1/challenge/*       挑战列表、创建、加入、进度结算（以后端重算为准）
 *   排行域：/v1/leaderboard       五维榜单（Redis ZSet 等价实现）
 *   环境域：/v1/env/aqi           和风天气代理（QWEATHER_KEY 环境变量，缺省走校园合成源）
 *   内容域：/v1/route/list、/v1/achievement/meta、/v1/config/route-weights  云端可热更下发
 *   社交域：/v1/community/*       跑友交友、动态流、点赞/转发、图文动态、记录分享
 *   健身域：/v1/gym/*             器械动作库下发、AI 训练计划、训练记录上报（服务端重算）
 *   AI  域：/v1/ai/*              路线推荐叙事、赛后深度分析、智能组队匹配
 *   健康域：/v1/health/snapshot   运动健康快照上报/拉取（步数/睡眠/心率/卡路里）
 *   校园域：/v1/campus/*          学校列表、校园实名绑定、校友目录
 * 启动：npm start  （或 node src/server.js，默认端口 3000，PORT 环境变量可覆盖）
 */
import http from 'node:http'
import { handleRequest } from './router.js'

const PORT = Number(process.env.PORT || 3000)
const HOST = '0.0.0.0'

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((err) => {
    console.error('[server] unhandled error:', err)
    if (!res.headersSent) {
      res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' })
    }
    res.end(JSON.stringify({ code: 5000, msg: 'internal error', data: null, trace_id: '' }))
  })
})

server.listen(PORT, HOST, () => {
  console.log(`[PulseValley] backend listening on http://${HOST}:${PORT}`)
  console.log('[PulseValley] env source:', process.env.QWEATHER_KEY ? 'qweather-proxy' : 'campus-synthetic')
})
