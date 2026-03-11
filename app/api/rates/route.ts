import { NextResponse } from 'next/server'

function fromYahoo(data: any): { rate: number | null; change: number | null } {
  const meta = data?.chart?.result?.[0]?.meta
  if (!meta) return { rate: null, change: null }
  const rate = meta.regularMarketPrice ?? null
  const prev = meta.previousClose ?? null
  return { rate, change: rate != null && prev != null ? parseFloat((rate - prev).toFixed(3)) : null }
}

export async function GET() {
  try {
    const [ust5Data, ust10Data, sofrData] = await Promise.all([
      fetch('https://query1.finance.yahoo.com/v8/finance/chart/%5EFVX?interval=1d&range=5d', { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store' }).then(r => r.json()),
      fetch('https://query1.finance.yahoo.com/v8/finance/chart/%5ETNX?interval=1d&range=5d', { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store' }).then(r => r.json()),
      fetch('https://markets.newyorkfed.org/api/rates/sofr/last/2.json', { cache: 'no-store' }).then(r => r.json()).catch(() => null),
    ])

    const ust5  = fromYahoo(ust5Data)
    const ust10 = fromYahoo(ust10Data)

    const sofrRate = sofrData?.refRates?.[0]?.percentRate ?? null
    const sofrPrev = sofrData?.refRates?.[1]?.percentRate ?? null

    // Interpolate 7Y from 5Y and 10Y (standard market approximation)
    const ust7Rate   = ust5.rate   != null && ust10.rate   != null ? parseFloat((ust5.rate   + (ust10.rate   - ust5.rate)   * 0.4).toFixed(3)) : null
    const ust7Change = ust5.change != null && ust10.change != null ? parseFloat((ust5.change + (ust10.change - ust5.change) * 0.4).toFixed(3)) : null

    const rates = [
      { key: 'SOFR',  label: 'SOFR',    rate: sofrRate, change: sofrRate != null && sofrPrev != null ? parseFloat((sofrRate - sofrPrev).toFixed(3)) : null },
      { key: 'DGS5',  label: '5Y UST',  ...ust5  },
      { key: 'DGS7',  label: '7Y UST',  rate: ust7Rate,  change: ust7Change  },
      { key: 'DGS10', label: '10Y UST', ...ust10 },
    ]

    return NextResponse.json({ rates })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
