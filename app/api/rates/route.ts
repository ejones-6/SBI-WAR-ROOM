// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
export const revalidate = 0

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

async function fetchSofr(): Promise<{ close: number; prev: number } | null> {
  // Primary: FRED CSV
  try {
    const res = await fetch(
      'https://fred.stlouisfed.org/graph/fredgraph.csv?id=SOFR',
      {
        headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'text/csv' },
        cache: 'no-store',
      }
    )
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

  // Fallback: NY Fed API
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

  return null
}

async function fetchTreasury(maturity: '5' | '7' | '10'): Promise<{ close: number; prev: number } | null> {
  // FRED series: DGS5, DGS7, DGS10
  try {
    const seriesId = `DGS${maturity}`
    const res = await fetch(
      `https://fred.stlouisfed.org/graph/fredgraph.csv?id=${seriesId}`,
      {
        headers: { 'User-Agent': 'Mozilla/5.0', 'Accept': 'text/csv' },
        cache: 'no-store',
      }
    )
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

  // Fallback: Yahoo Finance treasury symbols
  const yahooSymbol: Record<string, string> = { '5': '^FVX', '7': '^FVX', '10': '^TNX' }
  const result = await fetchYahoo(yahooSymbol[maturity])
  if (result) return { close: result.close / 10, prev: result.prev / 10 }
  return null
}

export async function GET() {
  const [sofr, fiveY, sevenY, tenY, sp500, dow, btc, avb, eqr, maa, ess] = await Promise.all([
    fetchSofr(),
    fetchTreasury('5'),
    fetchTreasury('7'),
    fetchTreasury('10'),
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
