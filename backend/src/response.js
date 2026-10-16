/**
 * 统一响应包：{ code, msg, data, trace_id }
 * 对应《架构设计文档》6.1 网关协议。code = 0 表示成功。
 */
export function traceId() {
  return 'tr_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
}

export function writeJson(res, status, payload) {
  const body = JSON.stringify(payload)
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization'
  })
  res.end(body)
}

export function ok(res, data, msg = 'ok') {
  writeJson(res, 200, { code: 0, msg, data, trace_id: traceId() })
}

export function fail(res, code, msg, status = 200) {
  writeJson(res, status, { code, msg, data: null, trace_id: traceId() })
}

/** 读取 JSON 请求体（上限 256KB） */
export function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []
    let size = 0
    req.on('data', (chunk) => {
      size += chunk.length
      if (size > 256 * 1024) {
        reject(new Error('body too large'))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => {
      if (chunks.length === 0) {
        resolve({})
        return
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf-8')))
      } catch (e) {
        reject(new Error('invalid json body'))
      }
    })
    req.on('error', reject)
  })
}
