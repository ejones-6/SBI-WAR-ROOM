import { NextResponse } from 'next/server'

const YAHOO_SYMBOLS = [
  { key: 'DGS5',  label: '5Y UST',  symbol: '^FVX' },
  { key: 'DGS10', label: '10Y UST', symbol: '^TNX' },
  { key: 'DGS30', label: '30Y UST', symbol: '^TYX' },
]

async function fetchYahoo(symbol: string): Promise<{ rate: number | null; change: number | null }> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=5d`
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store' })
  const json = await res.json()
  const meta = json?.chart?.result?.[0]?.meta
  if (!meta) return { rate: null, change: null }
  const rate = meta.regularMarketPrice ?? null
  const prev = meta.previousClose ?? null
  return {
    rate,
    change: rate != null && prev != null ? parseFloat((rate - prev).toFixed(3)) : null
  }
}

async function fetchSOFR(): Promise<{ rate: number | null; change: number | null }> {
  // NY Fed SOFR — published daily
  const res = await fetch('https://markets.newyorkfed.org/api/rates/all/last/2.json', { cache: 'no-store' })
  const json = await res.json()
  const rates = (json.refRates ?? []).filter((r: any) => r.type === 'SOFR')
  const latest = rates[0]?.percentRate ?? null
  const prev   = rates[1]?.percentRate ?? null
  return {
    rate:   latest,
    change: latest != null && prev != null ? parseFloat((latest - prev).toFixed(3)) : null
  }
}

export async function GET() {
  try {
    const [sofrData, ...yahooData] = await Promise.all([
      fetchSOFR(),
      ...YAHOO_SYMBOLS.map(s => fetchYahoo(s.symbol))
    ])

    const rates = [
      { key: 'SOFR', label: 'SOFR', ...sofrData },
      ...YAHOO_SYMBOLS.map((s, i) => ({ key: s.key, label: s.label, ...yahooData[i] }))
    ]

    return NextResponse.json({ rates })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
