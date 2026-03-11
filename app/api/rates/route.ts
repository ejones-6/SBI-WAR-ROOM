import { NextResponse } from 'next/server'

// Yahoo Finance symbols for treasury rates and SOFR
const SYMBOLS = [
  { key: 'SOFR',  label: 'SOFR',    symbol: '^SOFR'  },
  { key: 'DGS5',  label: '5Y UST',  symbol: '^FVX'   },
  { key: 'DGS10', label: '10Y UST', symbol: '^TNX'   },
  { key: 'DGS30', label: '30Y UST', symbol: '^TYX'   },
]

async function fetchQuote(symbol: string): Promise<{ rate: number | null; change: number | null }> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=5d`
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0' },
    cache: 'no-store'
  })
  const json = await res.json()
  const meta = json?.chart?.result?.[0]?.meta
  if (!meta) return { rate: null, change: null }
  const rate = meta.regularMarketPrice ?? null
  const prev = meta.previousClose ?? null
  const change = rate != null && prev != null ? parseFloat((rate - prev).toFixed(3)) : null
  return { rate, change }
}

export async function GET() {
  try {
    const results = await Promise.all(
      SYMBOLS.map(async ({ key, label, symbol }) => {
        const data = await fetchQuote(symbol)
        return { key, label, ...data }
      })
    )
    return NextResponse.json({ rates: results })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
