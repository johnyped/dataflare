import http from 'node:http'

const port = Number(process.env.MOCK_LICENSE_PORT ?? 9123)

const server = http.createServer((req, res) => {
    const headers = { 'Content-Type': 'application/json' }
    const origin = req.headers.origin
    if (origin !== undefined) {
        headers['Access-Control-Allow-Origin'] = origin
        headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'Content-Type'
    }
    if (req.method === 'OPTIONS') {
        res.writeHead(204, headers)
        return res.end()
    }
    const url = new URL(req.url, `http://${req.headers.host}`)
    if (req.method === 'POST' && url.pathname === '/license/activate') {
        let body = ''
        req.on('data', (chunk) => (body += chunk))
        req.on('end', () => {
            res.writeHead(200, headers)
            res.end(JSON.stringify({ token: 'dev-mock-token' }))
        })
        return
    }
    if (req.method === 'GET' && url.pathname === '/license/verify') {
        const license = url.searchParams.get('license') ?? ''
        const token = url.searchParams.get('token') ?? ''
        const status = license.startsWith('dev') || token === 'dev-mock-token'
        res.writeHead(200, headers)
        res.end(JSON.stringify({ status }))
        return
    }
    res.writeHead(404, headers)
    res.end(JSON.stringify({ message: 'Not found' }))
})

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`Mock license server could not bind 127.0.0.1:${port}: address already in use`)
        console.error('Stop the process holding the port, or set MOCK_LICENSE_PORT to a free port.')
    } else {
        console.error(`Mock license server failed to start: ${err.message}`)
    }
    process.exit(1)
})

for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => server.close(() => process.exit(0)))
}

server.listen(port, '127.0.0.1', () => {
    console.log(`Mock license API listening on http://127.0.0.1:${port}`)
    console.log('Enter a license key starting with "dev" in the activate window')
})
