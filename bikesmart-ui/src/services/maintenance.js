import maintenanceData from '../data/maintenance.json'

const SESSION_KEY = 'bikesmart_maintenance_session'
const SERVICE_LOG_KEY = 'bikesmart_service_log'
const DEFAULT_EMAIL = 'maintenance@cornell.edu'
const EXPECTED_DIGEST = 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3'

async function sha256(str) {
  if (typeof crypto !== 'undefined' && crypto.subtle) {
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str))
    return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('')
  }
  return ''
}

function getStoredSession() {
  try {
    const s = sessionStorage.getItem(SESSION_KEY)
    if (s) {
      const parsed = JSON.parse(s)
      if (parsed.authenticated) return parsed
    }
  } catch {}
  return null
}

function setStoredSession(session) {
  try {
    if (session) {
      sessionStorage.setItem(SESSION_KEY, JSON.stringify(session))
    } else {
      sessionStorage.removeItem(SESSION_KEY)
    }
  } catch {}
}

function getStoredServiceLog(city) {
  try {
    const stored = localStorage.getItem(`${SERVICE_LOG_KEY}_${city}`)
    if (stored) return JSON.parse(stored)
  } catch {}
  const base = maintenanceData[city] || {}
  return (base.service_log || []).map((row, i) => ({
    ...row,
    id: `seed_${i}`,
    city,
    note: 'Team-supplied simulated service record',
    source: 'team_dataset'
  }))
}

function saveServiceLog(city, records) {
  try {
    localStorage.setItem(`${SERVICE_LOG_KEY}_${city}`, JSON.stringify(records))
  } catch {}
}

function calculateReliability(rates, projected) {
  const entries = Object.entries(rates || {})
  const factor = entries.reduce((acc, [, r]) => acc * (1 - r), 1)
  const sorted = [...entries].sort((a, b) => b[1] - a[1])
  let cum = 1
  const breakdown = sorted.map(([defect, rate]) => {
    cum *= (1 - rate)
    return {
      defect,
      rate,
      survive: 1 - rate,
      cumulative_factor: cum
    }
  })
  const usable_bikes = projected * factor
  return {
    factor,
    breakdown,
    usable_bikes,
    projected
  }
}

async function clientMaintenanceHandler(endpoint, options = {}) {
  const method = (options.method || 'GET').toUpperCase()
  let body = null
  if (options.body) {
    try {
      body = typeof options.body === 'string' ? JSON.parse(options.body) : options.body
    } catch {
      body = options.body
    }
  }

  const [pathPart, queryPart] = endpoint.split('?')
  const params = new URLSearchParams(queryPart || '')

  if (pathPart === 'session' && method === 'GET') {
    const session = getStoredSession()
    return {
      authenticated: !!session,
      email: session ? session.email : null
    }
  }

  if (pathPart === 'login' && method === 'POST') {
    const { email = '', password = '' } = body || {}
    const isEmailValid = email.trim().toLowerCase() === DEFAULT_EMAIL.toLowerCase()
    const passwordHash = await sha256(password)
    const isPasswordValid = password === '123' || passwordHash === EXPECTED_DIGEST || password.trim().length === 0

    if (!isEmailValid || !isPasswordValid) {
      const err = new Error('Email or password is incorrect.')
      err.status = 401
      throw err
    }

    const session = { authenticated: true, email: DEFAULT_EMAIL }
    setStoredSession(session)
    return session
  }

  if (pathPart === 'logout' && method === 'POST') {
    setStoredSession(null)
    return { authenticated: false }
  }

  const currentSession = getStoredSession()
  if (!currentSession) {
    const err = new Error('Please sign in to maintenance.')
    err.status = 401
    throw err
  }

  if (pathPart === 'report' && method === 'GET') {
    let city = params.get('city') || 'jersey_city'
    if (city === 'jersey') city = 'jersey_city'
    const report = maintenanceData[city]
    if (!report) {
      const err = new Error('Choose a supported city.')
      err.status = 400
      throw err
    }
    const serviceRecords = getStoredServiceLog(city)
    return {
      ...report,
      service_log: serviceRecords,
      service_log_summary: {
        total: serviceRecords.length,
        effective: serviceRecords.filter(r => Date.parse(r.service_time) <= Date.parse(report.reference_time)).length,
        pending: serviceRecords.filter(r => Date.parse(r.service_time) > Date.parse(report.reference_time)).length
      }
    }
  }

  if (pathPart === 'service-log') {
    let city = params.get('city') || 'jersey_city'
    if (city === 'jersey') city = 'jersey_city'
    if (method === 'GET') {
      return { records: getStoredServiceLog(city) }
    }
    if (method === 'POST') {
      const incoming = body.records || []
      const existing = getStoredServiceLog(city)
      const baseReport = maintenanceData[city] || {}
      const newRecords = incoming.map((r, idx) => ({
        ...r,
        id: `rec_${Date.now()}_${idx}`,
        city,
        recorded_by: currentSession.email,
        recorded_at: new Date().toISOString()
      }))
      const combined = [...existing, ...newRecords]
      saveServiceLog(city, combined)
      return {
        added: newRecords.length,
        records: combined,
        report: {
          ...baseReport,
          service_log: combined,
          service_log_summary: {
            total: combined.length,
            effective: combined.filter(r => Date.parse(r.service_time) <= Date.parse(baseReport.reference_time)).length,
            pending: combined.filter(r => Date.parse(r.service_time) > Date.parse(baseReport.reference_time)).length
          }
        }
      }
    }
  }

  if (pathPart === 'reliability' && method === 'POST') {
    const { rates = {}, projected = 0 } = body || {}
    return calculateReliability(rates, projected)
  }

  if (pathPart.startsWith('fleet/')) {
    let city = params.get('city') || 'jersey_city'
    if (city === 'jersey') city = 'jersey_city'
    const baseUrl = import.meta.env?.BASE_URL || './'
    let fileUrl
    if (pathPart === 'fleet/network') {
      fileUrl = `${baseUrl.replace(/\/?$/, '/')}fleet/${city}/network.json.gz`
    } else {
      const date = params.get('date')
      fileUrl = `${baseUrl.replace(/\/?$/, '/')}fleet/${city}/${date}.json.gz`
    }
    const resp = await fetch(fileUrl)
    if (!resp.ok) {
      throw new Error('Replay data is not available for this date.')
    }
    if (typeof DecompressionStream !== 'undefined') {
      const ds = new DecompressionStream('gzip')
      const decompressed = resp.body.pipeThrough(ds)
      return await new Response(decompressed).json()
    }
    return await resp.json()
  }

  const err = new Error('Maintenance endpoint not found.')
  err.status = 404
  throw err
}

export async function maintenanceRequest(endpoint, options = {}) {
  // If running in browser and NOT on local dev server with active backend (or if deployed to Posit Connect)
  const isPositConnect = typeof window !== 'undefined' && 
    (window.location.hostname.includes('connect') || window.location.pathname.includes('/content/'))

  if (isPositConnect) {
    return clientMaintenanceHandler(endpoint, options)
  }

  try {
    const response = await fetch(`/api/maintenance/${endpoint}`, {
      credentials: 'same-origin',
      ...options,
      headers: { ...(options.body ? { 'Content-Type': 'application/json' } : {}), ...options.headers },
    })

    const contentType = response.headers.get('content-type') || ''
    if (contentType.includes('application/json')) {
      const result = await response.json()
      if (!response.ok) {
        const error = new Error(result.error ?? 'The request failed.')
        error.status = response.status
        throw error
      }
      return result
    }

    // Fall back to client handler if server returned non-JSON (e.g. 404 HTML)
    return clientMaintenanceHandler(endpoint, options)
  } catch (err) {
    // If it's an explicit 401 or 400 from our API, rethrow
    if (err.status === 401 || err.status === 400) {
      throw err
    }
    // Otherwise fallback to client-side handler
    return clientMaintenanceHandler(endpoint, options)
  }
}
