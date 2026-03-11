// app/api/rates/route.ts
import { NextResponse } from 'next/server'

export const revalidate = 300

const SYMBOLS = ['^TNX', '^FVX', '^IRX', '^GSPC', '^DJI', 'BTC-USD', 'AVB', 'EQR', 'MAA', 'ESS']

const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'application/json',
  'Accept-Language': 'en-US,en;q=0.9',
  'Referer': 'https://finance.yahoo.com/',
  'Origin': 'https://finance.yahoo.com',
}

function buildResponse(results: any[]) {
  const m: Record<string, any> = {}
  for (const r of results) {
    m[r.symbol] = {
      price:  r.regularMarketPrice ?? null,
      change: r.regularMarketChange ?? null,
      pct:    r.regularMarketChangePercent ?? null,
    }
  }
  const fiveY = m['^FVX']?.price ?? null
  const tenY  = m['^TNX']?.price ?? null
  return {
    sofr:   m['^IRX']    ? { rate: m['^IRX'].price,    change: m['^IRX'].change   } : null,
    fiveY:  m['^FVX']    ? { rate: m['^FVX'].price,    change: m['^FVX'].change   } : null,
    sevenY: (fiveY && tenY) ? { rate: +(fiveY * 0.4 + tenY * 0.6).toFixed(3) }    : null,
    tenY:   m['^TNX']    ? { rate: m['^TNX'].price,    change: m['^TNX'].change   } : null,
    sp500:  m['^GSPC']   ? { price: m['^GSPC'].price,  change: m['^GSPC'].change,  pct: m['^GSPC'].pct  } : null,
    dow:    m['^DJI']    ? { price: m['^DJI'].price,   change: m['^DJI'].change,   pct: m['^DJI'].pct   } : null,
    btc:    m['BTC-USD'] ? { price: m['BTC-USD'].price, change: m['BTC-USD'].change, pct: m['BTC-USD'].pct } : null,
    avb:    m['AVB']     ? { price: m['AVB'].price,    change: m['AVB'].change,    pct: m['AVB'].pct    } : null,
    eqr:    m['EQR']     ? { price: m['EQR'].price,    change: m['EQR'].change,    pct: m['EQR'].pct    } : null,
    maa:    m['MAA']     ? { price: m['MAA'].price,    change: m['MAA'].change,    pct: m['MAA'].pct    } : null,
    ess:    m['ESS']     ? { price: m['ESS'].price,    change: m['ESS'].change,    pct: m['ESS'].pct    } : null,
  }
}

export async function GET() {
  const url = `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${SYMBOLS.join(',')}&fields=regularMarketPrice,regularMarketChange,regularMarketChangePercent`

  for (const fetchUrl of [url, url.replace('query1', 'query2')]) {
    try {
      const res = await fetch(fetchUrl, { headers: HEADERS, next: { revalidate: 300 } })
      if (!res.ok) continue
      const data = await res.json()
      const results: any[] = data?.quoteResponse?.result ?? []
      if (!results.length) continue
      return NextResponse.json(buildResponse(results), {
        headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=60' }
      })
    } catch (e: any) {
      console.warn('[rates] failed:', e?.message)
    }
  }

  return NextResponse.json({ error: 'rates_unavailable' }, { status: 500 })
}
