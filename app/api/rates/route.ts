// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
export const revalidate = 0

const FH = 'd778f7pr01qp6afkknjgd778f7pr01qp6afkknk0'

async function fhQuote(symbol: string): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(
      `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(symbol)}&token=${FH}`,
      { cache: 'no-store', signal: AbortSignal.timeout(5000) }
    )
    if (!res.ok) return null
    const d = await res.json()
    if (!d.c || d.c === 0) return null
    return { close: d.c, prev: d.pc ?? d.c }
  } catch { return null }
}

async function fetchFred(id: string): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(
      `https://fred.stlouisfed.org/graph/fredgraph.csv?id=${id}`,
      { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store', signal: AbortSignal.timeout(5000) }
    )
    if (!res.ok) return null
    const lines = (await res.text()).trim().split('\n').filter(l => l && !l.startsWith('DATE') && !l.includes('ND'))
    if (lines.length < 2) return null
    const close = parseFloat(lines[lines.length - 1].split(',')[1])
    const prev  = parseFloat(lines[lines.length - 2].split(',')[1])
    if (isNaN(close)) return null
    return { close, prev: isNaN(prev) ? close : prev }
  } catch { return null }
}

async function fetchSofr(): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch('https://markets.newyorkfed.org/api/rates/sofr/last/2.json',
      { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store', signal: AbortSignal.timeout(5000) })
    if (!res.ok) return null
    const rates = (await res.json())?.refRates
    if (rates?.length >= 2) {
      const close = parseFloat(rates[0]?.percentRate)
      const prev  = parseFloat(rates[1]?.percentRate)
      if (!isNaN(close)) return { close, prev: isNaN(prev) ? close : prev }
    }
  } catch {}
  return fetchFred('SOFR')
}

async function fhForex(): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(
      `https://finnhub.io/api/v1/forex/rates?base=USD&token=${FH}`,
      { cache: 'no-store', signal: AbortSignal.timeout(5000) }
    )
    if (!res.ok) return null
    const d = await res.json()
    const rate = d?.quote?.EUR
    if (!rate) return null
    // Convert USD/EUR to EUR/USD
    const eurusd = parseFloat((1 / rate).toFixed(5))
    return { close: eurusd, prev: eurusd }
  } catch { return null }
}

export async function GET() {
  const [sofr, fiveY, tenY, sp500, dow, btc, avb, eqr, maa, ess, eurusd] = await Promise.all([
    fetchSofr(),
    fetchFred('DGS5'),    // 5Y Treasury — daily
    fetchFred('DGS10'),   // 10Y Treasury — daily
    fhQuote('SPY'),     // S&P 500 — real time
    fhQuote('DIA'),      // Dow — real time
    fhQuote('BINANCE:BTCUSDT'), // BTC — real time
    fhQuote('AVB'),       // REITs — real time
    fhQuote('EQR'),
    fhQuote('MAA'),
    fhQuote('ESS'),
    fhForex(), // EUR/USD — real time
  ])

  const sevenY = (fiveY && tenY) ? {
    close: parseFloat(((fiveY.close + tenY.close) / 2).toFixed(3)),
    prev:  parseFloat(((fiveY.prev  + tenY.prev)  / 2).toFixed(3)),
  } : null

  const rate  = (d: { close: number; prev: number } | null) =>
    d ? { rate: d.close, change: parseFloat((d.close - d.prev).toFixed(3)) } : null
  const price = (d: { close: number; prev: number } | null) =>
    d ? { price: d.close, change: parseFloat((d.close - d.prev).toFixed(2)), pct: parseFloat(((d.close - d.prev) / d.prev * 100).toFixed(2)) } : null

  return NextResponse.json({
    sofr: rate(sofr), fiveY: rate(fiveY), sevenY: rate(sevenY), tenY: rate(tenY),
    sp500: price(sp500), dow: price(dow), btc: price(btc),
    avb: price(avb), eqr: price(eqr), maa: price(maa), ess: price(ess),
    eurusd: price(eurusd),
  })
}
