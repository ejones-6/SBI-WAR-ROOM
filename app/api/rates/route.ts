// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const revalidate = 3600

async function fetchStooq(symbol: string): Promise<{ close: number; prev: number } | null> {
  try {
    const res = await fetch(`https://stooq.com/q/d/l/?s=${symbol}&i=d`, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
      next: { revalidate: 0 }
    })
    if (!res.ok) return null
    const text = await res.text()
    const lines = text.trim().split('\n').filter(l => l && !l.startsWith('Date'))
    if (lines.length < 2) return null
    const latest = lines[lines.length - 1].split(',')
    const prev   = lines[lines.length - 2].split(',')
    const close = parseFloat(latest[4])
    const prevClose = parseFloat(prev[4])
    if (isNaN(close)) return null
    return { close, prev: isNaN(prevClose) ? close : prevClose }
  } catch { return null }
}

async function fetchSofr(): Promise<{ close: number; prev: number } | null> {
  // Try Stooq symbols in order
  for (const sym of ['sofr.b', 'sofrrate.b', 'usdfisr.b']) {
    const result = await fetchStooq(sym)
    if (result) return result
  }
  // Fallback: NY Fed published SOFR data
  try {
    const res = await fetch('https://markets.newyorkfed.org/api/rates/sofr/last/2.json', {
      next: { revalidate: 0 }
    })
    if (!res.ok) return null
    const data = await res.json()
    const rates = data?.refRates
    if (!rates || rates.length < 2) return null
    const close = parseFloat(rates[0]?.percentRate)
    const prev  = parseFloat(rates[1]?.percentRate)
    if (isNaN(close)) return null
    return { close, prev: isNaN(prev) ? close : prev }
  } catch { return null }
}

export async function GET() {
  const [sofr, fiveY, sevenY, tenY, sp500, dow, btc, avb, eqr, maa, ess] = await Promise.all([
    fetchSofr(),
    fetchStooq('5yusy.b'),
    fetchStooq('7yusy.b'),
    fetchStooq('10yusy.b'),
    fetchStooq('^spx'),
    fetchStooq('^dji'),
    fetchStooq('btc.v'),
    fetchStooq('avb.us'),
    fetchStooq('eqr.us'),
    fetchStooq('maa.us'),
    fetchStooq('ess.us'),
  ])

  const rate = (d: { close: number; prev: number } | null) =>
    d ? { rate: d.close, change: parseFloat((d.close - d.prev).toFixed(3)) } : null

  const price = (d: { close: number; prev: number } | null) =>
    d ? { price: d.close, change: parseFloat((d.close - d.prev).toFixed(2)), pct: parseFloat(((d.close - d.prev) / d.prev * 100).toFixed(2)) } : null

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
  }, {
    headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' }
  })
}
