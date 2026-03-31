// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
export const revalidate = 0

// ── Yahoo Finance — equities, REITs, BTC, and treasury indices ───────────────
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

// ── FRED — treasury yields and SOFR ─────────────────────────────────────────
// Returns values already in percent (e.g. 4.153)
async function fetchFred(seriesId: string): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(
      `https://fred.stlouisfed.org/graph/fredgraph.csv?id=${seriesId}`,
      {
        headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'text/csv' },
        cache: 'no-store',
      }
    )
    if (!res.ok) return null
    const text = await res.text()
    const lines = text.trim().split('\n').filter(l => l && !l.startsWith('DATE') && !l.includes('ND'))
    if (lines.length < 2) return null
    const close = parseFloat(lines[lines.length - 1].split(',')[1])
    const prev  = parseFloat(lines[lines.length - 2].split(',')[1])
    if (isNaN(close)) return null
    return { close, prev: isNaN(prev) ? close : prev }
  } catch { return null }
}

// ── SOFR — NY Fed primary, FRED fallback ─────────────────────────────────────
async function fetchSofr(): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(
      'https://markets.newyorkfed.org/api/rates/sofr/last/2.json',
      {
        headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
        cache: 'no-store',
      }
    )
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
  return fetchFred('SOFR')
}

export async function GET() {
  // ^FVX = 5Y, ^TNX = 10Y — Yahoo returns these already in percent (e.g. 4.08)
  // NO divide by 10 needed
  const [sofr, fiveY, tenY, sp500, dow, btc, avb, eqr, maa, ess] = await Promise.all([
    fetchSofr(),
    fetchYahoo('^FVX'),    // 5Y — real time
    fetchYahoo('^TNX'),    // 10Y — real time
    fetchYahoo('^GSPC'),
    fetchYahoo('^DJI'),
    fetchYahoo('BTC-USD'),
    fetchYahoo('AVB'),
    fetchYahoo('EQR'),
    fetchYahoo('MAA'),
    fetchYahoo('ESS'),
  ])

  // 7Y interpolated from live 5Y and 10Y — no real-time symbol exists
  const sevenY = (fiveY && tenY) ? {
    close: parseFloat(((fiveY.close + tenY.close) / 2).toFixed(3)),
    prev:  parseFloat(((fiveY.prev  + tenY.prev)  / 2).toFixed(3)),
  } : null

  const rate = (d: { close: number; prev: number } | null) =>
    d ? { rate: d.close, change: parseFloat((d.close - d.prev).toFixed(3)) } : null

  const price = (d: { close: number; prev: number } | null) =>
    d ? {
      price: d.close,
      change: parseFloat((d.close - d.prev).toFixed(2)),
      pct: parseFloat(((d.close - d.prev) / d.prev * 100).toFixed(2)),
    } : null

  return NextResponse.json({
    sofr:   rate(sofr),
    fiveY:  rate(fiveY),
    sevenY: rate(sevenY),
    tenY:   rate(tenY),
    sp500:  price(sp500),
    dow:    price(dow),
    btc:    price(btc),
    avb:    price(avb),
    eqr:    price(eqr),
    maa:    price(maa),
    ess:    price(ess),
  })
}
