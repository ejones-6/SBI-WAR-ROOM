// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const revalidate = 0

// Stooq CSV for equities/REITs — works great from Vercel
async function fetchStooq(symbol: string): Promise<number | null> {
  try {
    const res = await fetch(`https://stooq.com/q/l/?s=${symbol}&f=sd2t2ohlcv&h&e=csv`, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
      next: { revalidate: 0 }
    })
    if (!res.ok) return null
    const text = await res.text()
    const lines = text.trim().split('\n')
    if (lines.length < 2) return null
    const close = parseFloat(lines[1].split(',')[6])
    return isNaN(close) ? null : close
  } catch { return null }
}

// FRED public graph CSV — no API key needed, authoritative Fed data
// URL: https://fred.stlouisfed.org/graph/fredgraph.csv?id=SERIES_ID
async function fetchFRED(seriesId: string): Promise<number | null> {
  try {
    const res = await fetch(`https://fred.stlouisfed.org/graph/fredgraph.csv?id=${seriesId}`, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
      next: { revalidate: 0 }
    })
    if (!res.ok) return null
    const text = await res.text()
    const lines = text.trim().split('\n').filter(l => l && !l.startsWith('DATE'))
    // Walk backwards to find last non-missing value
    for (let i = lines.length - 1; i >= 0; i--) {
      const val = parseFloat(lines[i].split(',')[1])
      if (!isNaN(val)) return val
    }
    return null
  } catch { return null }
}

export async function GET() {
  // Fetch rates from FRED + equities/REITs from Stooq in parallel
  const [sofr, fiveY, sevenY, tenY, sp500, dow, btc, avb, eqr, maa, ess] = await Promise.all([
    fetchFRED('SOFR'),      // Secured Overnight Financing Rate
    fetchFRED('DGS5'),      // 5-Year Treasury
    fetchFRED('DGS7'),      // 7-Year Treasury
    fetchFRED('DGS10'),     // 10-Year Treasury
    fetchStooq('^spx'),     // S&P 500
    fetchStooq('^dji'),     // DOW
    fetchStooq('btc.v'),    // BTC/USD
    fetchStooq('avb.us'),
    fetchStooq('eqr.us'),
    fetchStooq('maa.us'),
    fetchStooq('ess.us'),
  ])

  const rates = {
    sofr:   sofr   != null ? { rate: sofr }   : null,
    fiveY:  fiveY  != null ? { rate: fiveY }  : null,
    sevenY: sevenY != null ? { rate: sevenY } : null,
    tenY:   tenY   != null ? { rate: tenY }   : null,
    sp500:  sp500  != null ? { price: sp500 } : null,
    dow:    dow    != null ? { price: dow }   : null,
    btc:    btc    != null ? { price: btc }   : null,
    avb:    avb    != null ? { price: avb }   : null,
    eqr:    eqr    != null ? { price: eqr }   : null,
    maa:    maa    != null ? { price: maa }   : null,
    ess:    ess    != null ? { price: ess }   : null,
  }

  return NextResponse.json(rates, {
    headers: { 'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=300' }
  })
}
