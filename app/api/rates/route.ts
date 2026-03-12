// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const revalidate = 3600 // 1 hour — treasuries update daily, SOFR changes ~8x/year

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

// Fetch real SOFR from NY Fed public API (no API key required)
// Docs: https://markets.newyorkfed.org/static/docs/markets-api.html
async function fetchSOFR(): Promise<number | null> {
  try {
    const res = await fetch(
      'https://markets.newyorkfed.org/api/rates/sofr/last/1.json',
      { next: { revalidate: 0 } }
    )
    if (!res.ok) return null
    const json = await res.json()
    const rate = json?.refRates?.[0]?.percentRate
    return typeof rate === 'number' ? rate : null
  } catch { return null }
}

export async function GET() {
  // Fetch SOFR from NY Fed + all Stooq symbols in parallel
  const [sofrReal, fedFunds, fiveY, sevenY, tenY, sp500, dow, btc, avb, eqr, maa, ess] = await Promise.all([
    fetchSOFR(),
    fetchStooq('fedfunds.b'),  // Fed Funds fallback if NY Fed is down
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

  // Use real SOFR from NY Fed; fall back to Fed Funds if NY Fed is unavailable
  const sofrRate = sofrReal ?? fedFunds

  return NextResponse.json({
    sofr:   sofrRate != null ? { rate: sofrRate } : null,
    fiveY:  fiveY    != null ? { rate: fiveY }    : null,
    sevenY: sevenY   != null ? { rate: sevenY }   : null,
    tenY:   tenY     != null ? { rate: tenY }      : null,
    sp500:  sp500    != null ? { price: sp500 }   : null,
    dow:    dow      != null ? { price: dow }      : null,
    btc:    btc      != null ? { price: btc }      : null,
    avb:    avb      != null ? { price: avb }      : null,
    eqr:    eqr      != null ? { price: eqr }      : null,
    maa:    maa      != null ? { price: maa }      : null,
    ess:    ess      != null ? { price: ess }       : null,
  }, {
    headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' }
  })
}
