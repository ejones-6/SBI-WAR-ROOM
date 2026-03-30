// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
export const revalidate = 0

// ── Yahoo Finance — equities, REITs, BTC ─────────────────────────────────────
async function fetchYahoo(symbol: string): Promise<{ close: number; prev: number } | null> {
  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=5d`
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
      cache: 'no-store',
    })
    if (!res.ok) return null
    const data = await res.json()
    const closes: number[] = data?.chart?.result?.[0]?.indicators?.quote?.[0]?.close ?? []
    const valid = closes.filter((v: number) => v != null && !isNaN(v))
    if (valid.length < 2) return null
    return { close: valid[valid.length - 1], prev: valid[valid.length - 2] }
  } catch { return null }
}

// ── US Treasury XML — all yields including 7Y, updated ~4:30pm ET daily ──────
async function fetchTreasuryYields(): Promise<{
  fiveY: number | null; sevenY: number | null; tenY: number | null
  fiveYPrev: number | null; sevenYPrev: number | null; tenYPrev: number | null
}> {
  const empty = { fiveY: null, sevenY: null, tenY: null, fiveYPrev: null, sevenYPrev: null, tenYPrev: null }
  try {
    const today = new Date()
    const year = today.getFullYear()
    const month = String(today.getMonth() + 1).padStart(2, '0')
    const url = `https://home.treasury.gov/resource-center/data-chart-center/interest-rates/pages/xml?data=daily_treasury_yield_curve&field_tdr_date_value=${year}${month}`
    const res = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/xml, text/xml' },
      cache: 'no-store',
    })
    if (!res.ok) return empty
    const xml = await res.text()
    const entries: { date: string; fiveY: number | null; sevenY: number | null; tenY: number | null }[] = []
    const entryMatches = xml.match(/<entry>[\s\S]*?<\/entry>/g) ?? []
    for (const entry of entryMatches) {
      const dateMatch = entry.match(/<d:NEW_DATE[^>]*>([\d-]+)/)
      const fiveMatch = entry.match(/<d:BC_5YEAR[^>]*>([\d.]+)/)
      const sevenMatch = entry.match(/<d:BC_7YEAR[^>]*>([\d.]+)/)
      const tenMatch = entry.match(/<d:BC_10YEAR[^>]*>([\d.]+)/)
      if (!dateMatch) continue
      entries.push({
        date: dateMatch[1],
        fiveY: fiveMatch ? parseFloat(fiveMatch[1]) : null,
        sevenY: sevenMatch ? parseFloat(sevenMatch[1]) : null,
        tenY: tenMatch ? parseFloat(tenMatch[1]) : null,
      })
    }
    entries.sort((a, b) => b.date.localeCompare(a.date))
    if (entries.length === 0) return empty
    const latest = entries[0]
    const prev = entries[1] ?? entries[0]
    return {
      fiveY: latest.fiveY, sevenY: latest.sevenY, tenY: latest.tenY,
      fiveYPrev: prev.fiveY, sevenYPrev: prev.sevenY, tenYPrev: prev.tenY,
    }
  } catch { return empty }
}

// ── SOFR — FRED primary, NY Fed fallback ─────────────────────────────────────
async function fetchSofr(): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch('https://fred.stlouisfed.org/graph/fredgraph.csv?id=SOFR', {
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'text/csv' },
      cache: 'no-store',
    })
    if (res.ok) {
      const text = await res.text()
      const lines = text.trim().split('\n').filter(l => l && !l.startsWith('DATE') && !l.includes('ND'))
      if (lines.length >= 2) {
        const close = parseFloat(lines[lines.length - 1].split(',')[1])
        const prev  = parseFloat(lines[lines.length - 2].split(',')[1])
        if (!isNaN(close)) return { close, prev: isNaN(prev) ? close : prev }
      }
    }
  } catch {}
  try {
    const res = await fetch('https://markets.newyorkfed.org/api/rates/sofr/last/2.json', {
      headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
      cache: 'no-store',
    })
    if (res.ok) {
      const data = await res.json()
      const rates = data?.refRates
      if (rates?.length >= 2) {
        const close = parseFloat(rates[0]?.percentRate)
        const prev  = parseFloat(rates[1]?.percentRate)
        if (!isNaN(close)) return { close, prev: isNaN(prev) ? close : prev }
      }
    }
  } catch {}
  return null
}

export async function GET() {
  const [sofr, treasuries, sp500, dow, btc, avb, eqr, maa, ess] = await Promise.all([
    fetchSofr(),
    fetchTreasuryYields(),
    fetchYahoo('^GSPC'),
    fetchYahoo('^DJI'),
    fetchYahoo('BTC-USD'),
    fetchYahoo('AVB'),
    fetchYahoo('EQR'),
    fetchYahoo('MAA'),
    fetchYahoo('ESS'),
  ])

  const rate = (d: { close: number; prev: number } | null) =>
    d ? { rate: d.close, change: parseFloat((d.close - d.prev).toFixed(3)) } : null

  const rateFromVal = (close: number | null, prev: number | null) =>
    close != null ? { rate: close, change: parseFloat(((close - (prev ?? close))).toFixed(3)) } : null

  const price = (d: { close: number; prev: number } | null) =>
    d ? { price: d.close, change: parseFloat((d.close - d.prev).toFixed(2)), pct: parseFloat(((d.close - d.prev) / d.prev * 100).toFixed(2)) } : null

  return NextResponse.json({
    sofr:   rate(sofr),
    fiveY:  rateFromVal(treasuries.fiveY,   treasuries.fiveYPrev),
    sevenY: rateFromVal(treasuries.sevenY,  treasuries.sevenYPrev),
    tenY:   rateFromVal(treasuries.tenY,    treasuries.tenYPrev),
    sp500:  price(sp500),
    dow:    price(dow),
    btc:    price(btc),
    avb:    price(avb),
    eqr:    price(eqr),
    maa:    price(maa),
    ess:    price(ess),
  })
}
