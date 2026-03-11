import { NextResponse } from 'next/server'

export const revalidate = 300

const TICKERS = ['^TNX', '^FVX', '^IRX', '^GSPC', '^DJI', 'BTC-USD', 'AVB', 'EQR', 'MAA', 'ESS']

function extractQuote(r: any) {
  if (!r) return null
  return {
    price:  r.regularMarketPrice           ?? null,
    change: r.regularMarketChange          ?? null,
    pct:    r.regularMarketChangePercent   ?? null,
  }
}

async function fetchFromYahoo(base: string) {
  const url = `${base}/v7/finance/quote?symbols=${TICKERS.join(',')}&fields=regularMarketPrice,regularMarketChange,regularMarketChangePercent`
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36' },
    next: { revalidate: 300 }
  })
  if (!res.ok) throw new Error(`${res.status}`)
  const data = await res.json()
  const results: any[] = data?.quoteResponse?.result ?? []
  const map: Record<string, any> = {}
  for (const r of results) map[r.symbol] = extractQuote(r)
  return map
}

function buildResponse(m: Record<string, any>) {
  const fiveY = m['^FVX']?.price ?? null
  const tenY  = m['^TNX']?.price ?? null
  return {
    sofr:   m['^IRX']   ? { rate: m['^IRX'].price,   change: m['^IRX'].change  } : null,
    fiveY:  m['^FVX']   ? { rate: m['^FVX'].price,   change: m['^FVX'].change  } : null,
    sevenY: (fiveY && tenY) ? { rate: fiveY * 0.4 + tenY * 0.6 }               : null,
    tenY:   m['^TNX']   ? { rate: m['^TNX'].price,   change: m['^TNX'].change  } : null,
    sp500:  m['^GSPC']  ? { price: m['^GSPC'].price,  change: m['^GSPC'].change,  pct: m['^GSPC'].pct  } : null,
    dow:    m['^DJI']   ? { price: m['^DJI'].price,   change: m['^DJI'].change,   pct: m['^DJI'].pct   } : null,
    btc:    m['BTC-USD']? { price: m['BTC-USD'].price, change: m['BTC-USD'].change, pct: m['BTC-USD'].pct } : null,
    avb:    m['AVB']    ? { price: m['AVB'].price,    change: m['AVB'].change,    pct: m['AVB'].pct    } : null,
    eqr:    m['EQR']    ? { price: m['EQR'].price,    change: m['EQR'].change,    pct: m['EQR'].pct    } : null,
    maa:    m['MAA']    ? { price: m['MAA'].price,    change: m['MAA'].change,    pct: m['MAA'].pct    } : null,
    ess:    m['ESS']    ? { price: m['ESS'].price,    change: m['ESS'].change,    pct: m['ESS'].pct    } : null,
  }
}

export async function GET() {
  // Try query1 then query2 as fallback
  for (const base of ['https://query1.finance.yahoo.com', 'https://query2.finance.yahoo.com']) {
    try {
      const map = await fetchFromYahoo(base)
      const hasData = Object.values(map).some(v => v !== null)
      if (hasData) {
        return NextResponse.json(buildResponse(map), {
          headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' }
        })
      }
    } catch (e: any) {
      console.warn(`Rates fetch failed (${base}):`, e?.message)
    }
  }

  // Both failed
  console.error('All rates sources failed')
  return NextResponse.json({ error: 'rates_unavailable' }, { status: 500 })
}
