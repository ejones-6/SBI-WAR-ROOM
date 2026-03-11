// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const revalidate = 300

// ── Finnhub (free public key, 60 req/min) ─────────────────
// Sign up free at finnhub.io and set FINNHUB_API_KEY in Vercel env vars
// Or use the demo key below (may rate-limit under heavy use)
const FINNHUB_KEY = process.env.FINNHUB_API_KEY || 'demo'

async function finnhub(symbol: string) {
  try {
    const res = await fetch(
      `https://finnhub.io/api/v1/quote?symbol=${encodeURIComponent(symbol)}&token=${FINNHUB_KEY}`,
      { next: { revalidate: 300 } }
    )
    if (!res.ok) return null
    const d = await res.json()
    if (!d.c || d.c === 0) return null
    return { price: d.c, change: +(d.c - d.pc).toFixed(2), pct: +((d.c - d.pc) / d.pc * 100).toFixed(2) }
  } catch { return null }
}

// ── FRED API (Federal Reserve — free, no key, authoritative) ──────
async function fred(series: string): Promise<number | null> {
  try {
    const res = await fetch(
      `https://fred.stlouisfed.org/graph/fredgraph.json?id=${series}`,
      { next: { revalidate: 3600 } }  // Rates update once daily
    )
    if (!res.ok) return null
    const rows: [string, string][] = await res.json()
    for (let i = rows.length - 1; i >= 0; i--) {
      const v = parseFloat(rows[i][1])
      if (!isNaN(v) && v > 0) return v
    }
    return null
  } catch { return null }
}

// ── Yahoo Finance fallback ─────────────────────────────────
async function yahoo() {
  const tickers = ['^TNX', '^FVX', '^IRX', '^GSPC', '^DJI', 'BTC-USD', 'AVB', 'EQR', 'MAA', 'ESS']
  for (const host of ['query1', 'query2']) {
    try {
      const res = await fetch(
        `https://${host}.finance.yahoo.com/v7/finance/quote?symbols=${tickers.join(',')}&fields=regularMarketPrice,regularMarketChange,regularMarketChangePercent`,
        { headers: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://finance.yahoo.com' }, next: { revalidate: 300 } }
      )
      if (!res.ok) continue
      const data = await res.json()
      const results: any[] = data?.quoteResponse?.result ?? []
      if (!results.length) continue
      const m: Record<string, any> = {}
      for (const r of results) m[r.symbol] = { price: r.regularMarketPrice, change: r.regularMarketChange, pct: r.regularMarketChangePercent }
      return m
    } catch {}
  }
  return null
}

export async function GET() {
  try {
    // Fetch everything in parallel
    const [
      tenYRate, fiveYRate, sevenYRate, sofrRate,
      sp500, dow, btc,
      avb, eqr, maa, ess,
    ] = await Promise.all([
      fred('DGS10'), fred('DGS5'), fred('DGS7'), fred('SOFR'),
      finnhub('SPY'),
      finnhub('DIA'),
      finnhub('BTC-USD'),
      finnhub('AVB'), finnhub('EQR'), finnhub('MAA'), finnhub('ESS'),
    ])

    const gotRates  = !!(tenYRate || fiveYRate || sofrRate)
    const gotEquity = !!(sp500 || dow || avb)

    if (!gotRates && !gotEquity) {
      // Full fallback to Yahoo
      const y = await yahoo()
      if (!y) return NextResponse.json({ error: 'rates_unavailable' }, { status: 500 })
      const fY = y['^FVX']?.price ?? null, tY = y['^TNX']?.price ?? null
      return NextResponse.json({
        sofr:   y['^IRX']    ? { rate: y['^IRX'].price,    change: y['^IRX'].change   } : null,
        fiveY:  y['^FVX']    ? { rate: y['^FVX'].price,    change: y['^FVX'].change   } : null,
        sevenY: (fY && tY)   ? { rate: +(fY * 0.4 + tY * 0.6).toFixed(3) }            : null,
        tenY:   y['^TNX']    ? { rate: y['^TNX'].price,    change: y['^TNX'].change   } : null,
        sp500:  y['^GSPC']   ? { price: y['^GSPC'].price,  change: y['^GSPC'].change,  pct: y['^GSPC'].pct  } : null,
        dow:    y['^DJI']    ? { price: y['^DJI'].price,   change: y['^DJI'].change,   pct: y['^DJI'].pct   } : null,
        btc:    y['BTC-USD'] ? { price: y['BTC-USD'].price, change: y['BTC-USD'].change, pct: y['BTC-USD'].pct } : null,
        avb:    y['AVB']     ? { price: y['AVB'].price,    change: y['AVB'].change,    pct: y['AVB'].pct    } : null,
        eqr:    y['EQR']     ? { price: y['EQR'].price,    change: y['EQR'].change,    pct: y['EQR'].pct    } : null,
        maa:    y['MAA']     ? { price: y['MAA'].price,    change: y['MAA'].change,    pct: y['MAA'].pct    } : null,
        ess:    y['ESS']     ? { price: y['ESS'].price,    change: y['ESS'].change,    pct: y['ESS'].pct    } : null,
      }, { headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' } })
    }

    // SPY ≈ S&P/10, DIA ≈ DJIA/100 — scale back to index values
    const sp500Val = sp500 ? { price: +(sp500.price * 10).toFixed(2), change: +(sp500.change * 10).toFixed(2), pct: sp500.pct } : null
    const dowVal   = dow   ? { price: +(dow.price * 100).toFixed(0),  change: +(dow.change * 100).toFixed(0),  pct: dow.pct  } : null

    return NextResponse.json({
      sofr:   sofrRate   ? { rate: sofrRate }   : null,
      fiveY:  fiveYRate  ? { rate: fiveYRate }  : null,
      sevenY: sevenYRate ? { rate: sevenYRate } : (fiveYRate && tenYRate) ? { rate: +(fiveYRate * 0.4 + tenYRate * 0.6).toFixed(3) } : null,
      tenY:   tenYRate   ? { rate: tenYRate }   : null,
      sp500: sp500Val, dow: dowVal, btc, avb, eqr, maa, ess,
    }, { headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' } })

  } catch (e: any) {
    console.error('[rates] error:', e?.message)
    return NextResponse.json({ error: 'rates_unavailable' }, { status: 500 })
  }
}
