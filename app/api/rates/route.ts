// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const revalidate = 3600 // 1 hour

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

export async function GET() {
  const [sofr, fiveY, sevenY, tenY, sp500, dow, btc, avb, eqr, maa, ess] = await Promise.all([
    fetchStooq('fedfunds.b'),   // Fed Funds Effective Rate — tracks SOFR within ~5bps
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

  return NextResponse.json({
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
  }, {
    headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' }
  })
}
