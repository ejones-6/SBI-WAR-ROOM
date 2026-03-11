// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const revalidate = 0 // no cache — always fresh

// Stooq provides free quote data, no auth, no IP blocking
// Format: https://stooq.com/q/l/?s=SYMBOL&f=sd2t2ohlcv&h&e=csv
const STOOQ_MAP: Record<string, string> = {
  '^TNX': '^tnx',   // 10Y treasury yield
  '^FVX': '^fvx',   // 5Y treasury yield  
  '^IRX': '^irx',   // 13-week T-bill (SOFR proxy)
  '^GSPC': '^spx',  // S&P 500
  '^DJI': '^dji',   // DOW
  'AVB': 'avb.us',
  'EQR': 'eqr.us',
  'MAA': 'maa.us',
  'ESS': 'ess.us',
  'BTC-USD': 'btc.v', // BTC/USD on Stooq
}

async function fetchStooq(symbol: string): Promise<number | null> {
  try {
    const url = `https://stooq.com/q/l/?s=${symbol}&f=sd2t2ohlcv&h&e=csv`
    const res = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
      next: { revalidate: 0 }
    })
    if (!res.ok) return null
    const text = await res.text()
    const lines = text.trim().split('\n')
    if (lines.length < 2) return null
    const cols = lines[1].split(',')
    // CSV: Symbol,Date,Time,Open,High,Low,Close,Volume
    const close = parseFloat(cols[6])
    return isNaN(close) ? null : close
  } catch {
    return null
  }
}

export async function GET() {
  // Fetch all symbols in parallel
  const symbols = Object.keys(STOOQ_MAP)
  const values = await Promise.all(symbols.map(s => fetchStooq(STOOQ_MAP[s])))
  
  const m: Record<string, number | null> = {}
  symbols.forEach((s, i) => { m[s] = values[i] })

  const fiveY = m['^FVX']
  const tenY  = m['^TNX']

  const rates = {
    sofr:   m['^IRX']  != null ? { rate: m['^IRX'] }  : null,
    fiveY:  m['^FVX']  != null ? { rate: m['^FVX'] }  : null,
    sevenY: fiveY && tenY      ? { rate: +(fiveY! * 0.4 + tenY! * 0.6).toFixed(3) } : null,
    tenY:   m['^TNX']  != null ? { rate: m['^TNX'] }  : null,
    sp500:  m['^GSPC'] != null ? { price: m['^GSPC'] } : null,
    dow:    m['^DJI']  != null ? { price: m['^DJI'] }  : null,
    btc:    m['BTC-USD'] != null ? { price: m['BTC-USD'] } : null,
    avb:    m['AVB']   != null ? { price: m['AVB'] }   : null,
    eqr:    m['EQR']   != null ? { price: m['EQR'] }   : null,
    maa:    m['MAA']   != null ? { price: m['MAA'] }   : null,
    ess:    m['ESS']   != null ? { price: m['ESS'] }   : null,
  }

  const hasData = Object.values(rates).some(v => v !== null)
  if (!hasData) {
    return NextResponse.json({ error: 'rates_unavailable' }, { status: 500 })
  }

  return NextResponse.json(rates, {
    headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' }
  })
}
