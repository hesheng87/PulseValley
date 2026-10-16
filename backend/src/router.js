/**
 * 路由分发：/v1/* 全部端点 + CORS 预检 + GET / 接口索引
 */
import { ok, fail, readBody } from './response.js'
import { resolveUid } from './store.js'
import * as auth from './routes/auth.js'
import * as record from './routes/record.js'
import * as challenge from './routes/challenge.js'
import * as leaderboard from './routes/leaderboard.js'
import * as env from './routes/env.js'
import * as meta from './routes/meta.js'
import * as community from './routes/community.js'
import * as gym from './routes/gym.js'
import * as ai from './routes/ai.js'
import * as health from './routes/health.js'
import * as campus from './routes/campus.js'

const INDEX = {
  name: 'PulseValley Cloud API',
  domains: ['auth', 'record', 'challenge', 'leaderboard', 'env', 'meta', 'community', 'gym', 'ai', 'health', 'campus'],
  endpoints: [
    'GET  /v1/health',
    '--- 用户域 ---',
    'POST /v1/auth/login        {uid, nickname, phone, registerType} -> {token}',
    'GET  /v1/auth/profile',
    'POST /v1/auth/profile      更新昵称/头像 {nickname, avatar}',
    '--- 运动域 ---',
    'POST /v1/record/summary    运动摘要上报（风控校验，需 token）',
    'GET  /v1/record/list',
    '--- 挑战域 ---',
    'GET  /v1/challenge/list',
    'POST /v1/challenge/create  {title, emoji, typeDesc, targetKm, endDate}',
    'POST /v1/challenge/:id/join',
    'POST /v1/challenge/:id/progress  {addKm}',
    '--- 排行域 ---',
    'GET  /v1/leaderboard?scope=friends|campus|class|school|team',
    '--- 环境域 ---',
    'GET  /v1/env/aqi?lng=&lat=（和风天气代理，缺省校园合成源）',
    '--- 内容域 ---',
    'GET  /v1/route/list',
    'GET  /v1/config/route-weights',
    'GET  /v1/achievement/meta?since=',
    'POST /v1/achievement/unlock  {badgeId}',
    '--- 社交域 ---',
    'GET  /v1/community/runners          推荐跑友',
    'GET  /v1/community/friends          我的好友',
    'POST /v1/community/friend/add       {userId}',
    'GET  /v1/community/posts            动态流',
    'POST /v1/community/moment           发布图文动态 {text, images}',
    'POST /v1/community/share            分享运动记录 {recordId, aiContent, ...}',
    'POST /v1/community/post/:id/like    点赞/取消点赞',
    'POST /v1/community/post/:id/forward 转发',
    '--- 健身域 ---',
    'GET  /v1/gym/moves          器械动作库下发',
    'GET  /v1/gym/plan           AI 今日训练计划',
    'POST /v1/gym/workout        训练记录上报（服务端重算容量/卡路里）',
    'GET  /v1/gym/history        训练历史与累计统计',
    '--- AI 域 ---',
    'POST /v1/ai/route-narrate   路线推荐叙事 {aqi, temp, historyKm, routeName}',
    'POST /v1/ai/finish-analyze  赛后深度分析 {record, env, stats}',
    'POST /v1/ai/plan-generate   AI 训练计划生成 {requirement}（需求 → 计划）',
    'POST /v1/ai/week-plan      AI 一周训练计划生成（对话定制） {requirement}',
    'GET  /v1/ai/mate-match      智能组队匹配',
    '--- 健康域 ---',
    'POST /v1/health/snapshot    健康快照上报（步数/睡眠/心率/卡路里）',
    'GET  /v1/health/snapshot    最近快照与同步状态',
    '--- 校园域 ---',
    'GET  /v1/campus/schools     学校列表',
    'GET  /v1/campus/info        我的校园绑定',
    'POST /v1/campus/bind        校园实名绑定 {school, studentId, studentName}',
    'POST /v1/campus/unbind      解绑',
    'GET  /v1/campus/alumni      校友目录'
  ]
}

export async function handleRequest(req, res) {
  const url = new URL(req.url, 'http://localhost')
  const pathname = url.pathname
  const query = url.searchParams

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization'
    })
    res.end()
    return
  }

  if (pathname === '/' && req.method === 'GET') {
    ok(res, INDEX)
    return
  }

  if (pathname === '/v1/health') {
    ok(res, { status: 'up', ts: Date.now() })
    return
  }

  const routes = [
    ['POST', /^\/v1\/auth\/login$/, () => auth.login(req, res)],
    ['GET', /^\/v1\/auth\/profile$/, () => auth.profile(req, res, resolveUid(req))],
    ['POST', /^\/v1\/auth\/profile$/, () => auth.updateProfile(req, res, resolveUid(req))],

    ['POST', /^\/v1\/record\/summary$/, () => record.reportSummary(req, res, resolveUid(req))],
    ['GET', /^\/v1\/record\/list$/, () => record.listRecords(res, resolveUid(req))],

    ['GET', /^\/v1\/challenge\/list$/, () => challenge.list(res, resolveUid(req))],
    ['POST', /^\/v1\/challenge\/create$/, () => challenge.create(req, res, resolveUid(req))],
    ['POST', /^\/v1\/challenge\/([^/]+)\/join$/, (m) => challenge.join(res, m[1], resolveUid(req))],
    ['POST', /^\/v1\/challenge\/([^/]+)\/progress$/, (m) => challenge.progress(req, res, m[1], resolveUid(req))],

    ['GET', /^\/v1\/leaderboard$/, () => leaderboard.board(res, query.get('scope'), resolveUid(req))],

    ['GET', /^\/v1\/env\/aqi$/, () => env.aqi(res, query.get('lng'), query.get('lat'))],

    ['GET', /^\/v1\/route\/list$/, () => meta.routeList(res)],
    ['GET', /^\/v1\/config\/route-weights$/, () => meta.routeWeights(res)],
    ['POST', /^\/v1\/config\/route-weights$/, () => meta.updateRouteWeights(req, res)],
    ['GET', /^\/v1\/achievement\/meta$/, () => meta.achievementMeta(res, query.get('since'))],
    ['POST', /^\/v1\/achievement\/unlock$/, () => meta.unlockBadge(req, res, resolveUid(req))],

    ['GET', /^\/v1\/community\/runners$/, () => community.listRunners(res, resolveUid(req))],
    ['GET', /^\/v1\/community\/friends$/, () => community.listFriends(res, resolveUid(req))],
    ['POST', /^\/v1\/community\/friend\/add$/, () => community.addFriend(req, res, resolveUid(req))],
    ['GET', /^\/v1\/community\/posts$/, () => community.listPosts(res, resolveUid(req))],
    ['POST', /^\/v1\/community\/moment$/, () => community.publishMoment(req, res, resolveUid(req))],
    ['POST', /^\/v1\/community\/share$/, () => community.shareRecord(req, res, resolveUid(req))],
    ['POST', /^\/v1\/community\/post\/([^/]+)\/like$/, (m) => community.toggleLike(res, m[1], resolveUid(req))],
    ['POST', /^\/v1\/community\/post\/([^/]+)\/forward$/, (m) => community.forward(res, m[1], resolveUid(req))],

    ['GET', /^\/v1\/gym\/moves$/, () => gym.moves(res)],
    ['GET', /^\/v1\/gym\/plan$/, () => gym.plan(res)],
    ['POST', /^\/v1\/gym\/workout$/, () => gym.reportWorkout(req, res, resolveUid(req))],
    ['GET', /^\/v1\/gym\/history$/, () => gym.history(res, resolveUid(req))],

    ['POST', /^\/v1\/ai\/route-narrate$/, () => ai.routeNarrate(req, res)],
    ['POST', /^\/v1\/ai\/finish-analyze$/, () => ai.finishAnalyze(req, res)],
    ['POST', /^\/v1\/ai\/plan-generate$/, () => ai.planGenerate(req, res)],
    ['POST', /^\/v1\/ai\/week-plan$/, () => ai.weekPlanGenerate(req, res)],
    ['GET', /^\/v1\/ai\/mate-match$/, () => ai.mateMatch(res, resolveUid(req))],

    ['POST', /^\/v1\/health\/snapshot$/, () => health.reportSnapshot(req, res, resolveUid(req))],
    ['GET', /^\/v1\/health\/snapshot$/, () => health.getSnapshot(res, resolveUid(req))],

    ['GET', /^\/v1\/campus\/schools$/, () => campus.schools(res)],
    ['GET', /^\/v1\/campus\/info$/, () => campus.info(res, resolveUid(req))],
    ['POST', /^\/v1\/campus\/bind$/, () => campus.bind(req, res, resolveUid(req))],
    ['POST', /^\/v1\/campus\/unbind$/, () => campus.unbind(req, res, resolveUid(req))],
    ['GET', /^\/v1\/campus\/alumni$/, () => campus.alumni(res, resolveUid(req))]
  ]

  for (const [method, pattern, handler] of routes) {
    if (req.method !== method) {
      continue
    }
    const m = pathname.match(pattern)
    if (m) {
      await handler(m)
      return
    }
  }

  fail(res, 4004, `no route: ${req.method} ${pathname}`)
}

export { readBody }
