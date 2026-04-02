// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
export const revalidate = 0

const FINNHUB_KEY = 'd778f7pr01qp6afkknjgd778f7pr01qp6afkknk0'

// ── Finnhub — reliable, real-time, works from Vercel ─────────────────────────
async function fetchFinnhub(symbol: string): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(
      `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(symbol)}&token=${FINNHUB_KEY}`,
      { cache: 'no-store' }
    )
    if (!res.ok) return null
    const d = await res.json()
    // c = current price, pc = previous close
    if (!d.c || d.c === 0) return null
    return { close: d.c, prev: d.pc ?? d.c }
  } catch { return null }
}

// ── FRED — treasuries fallback ────────────────────────────────────────────────
async function fetchFred(seriesId: string): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(
      `https://fred.stlouisfed.org/graph/fredgraph.csv?id=${seriesId}`,
      { headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'text/csv' }, cache: 'no-store' }
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
      { headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' }, cache: 'no-store' }
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

// ── Treasury: Finnhub primary, FRED fallback ──────────────────────────────────
// Finnhub uses different symbols for treasury indices
async function fetchTreasury(finnhubSymbol: string, fredId: string): Promise<{ close: number; prev: number } | null> {
  const fh = await fetchFinnhub(finnhubSymbol)
  if (fh) return fh
  return fetchFred(fredId)
}

export async function GET() {
  // Finnhub symbols: ^FVX=5Y, ^TNX=10Y, ^GSPC=S&P, ^DJI=Dow
  // REITs and BTC use standard tickers
  const [sofr, fiveY, tenY, sp500, dow, btc, avb, eqr, maa, ess, eurusd] = await Promise.all([
    fetchSofr(),
    fetchTreasury('^FVX', 'DGS5'),
    fetchTreasury('^TNX', 'DGS10'),
    fetchFinnhub('^GSPC'),
    fetchFinnhub('^DJI'),
    fetchFinnhub('BINANCE:BTCUSDT'),
    fetchFinnhub('AVB'),
    fetchFinnhub('EQR'),
    fetchFinnhub('MAA'),
    fetchFinnhub('ESS'),
    fetchFinnhub('OANDA:EUR_USD'),
  ])

  // 7Y interpolated from 5Y + 10Y
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
    eurusd: price(eurusd),
  })
}
