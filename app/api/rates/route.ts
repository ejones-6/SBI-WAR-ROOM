import { NextResponse } from 'next/server'

function fromYahoo(data: any): { rate: number | null; change: number | null } {
  const meta = data?.chart?.result?.[0]?.meta
  if (!meta) return { rate: null, change: null }
  const rate = meta.regularMarketPrice ?? null
  const prev = meta.previousClose ?? null
  return { rate, change: rate != null && prev != null ? parseFloat((rate - prev).toFixed(2)) : null }
}

async function yahooFetch(symbol: string) {
  const res = await fetch(
    `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=5d`,
    { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store' }
  )
  return res.json()
}

export async function GET() {
  try {
    const [sofrData, ust5Data, ust10Data, spxData, djiData, btcData, avbData, eqrData, maaData, essData] = await Promise.all([
      yahooFetch('^SOFR'),
      yahooFetch('^FVX'),
      yahooFetch('^TNX'),
      yahooFetch('^GSPC'),
      yahooFetch('^DJI'),
      yahooFetch('BTC-USD'),
      yahooFetch('AVB'),
      yahooFetch('EQR'),
      yahooFetch('MAA'),
      yahooFetch('ESS'),
    ])

    const ust5  = fromYahoo(ust5Data)
    const ust10 = fromYahoo(ust10Data)

    // Interpolate 7Y linearly between 5Y and 10Y
    const ust7Rate   = ust5.rate   != null && ust10.rate   != null ? parseFloat((ust5.rate   + (ust10.rate   - ust5.rate)   * 0.4).toFixed(3)) : null
    const ust7Change = ust5.change != null && ust10.change != null ? parseFloat((ust5.change + (ust10.change - ust5.change) * 0.4).toFixed(2)) : null

    const rates = [
      // Rates
      { key: 'SOFR',  label: 'SOFR',      ...fromYahoo(sofrData) },
      { key: 'DGS5',  label: '5Y UST',    ...ust5  },
      { key: 'DGS7',  label: '7Y UST',    rate: ust7Rate, change: ust7Change },
      { key: 'DGS10', label: '10Y UST',   ...ust10 },
      // Indices
      { key: 'SPX',   label: 'S&P 500',   ...fromYahoo(spxData) },
      { key: 'DJI',   label: 'Dow Jones', ...fromYahoo(djiData) },
      { key: 'BTC',   label: 'Bitcoin',   ...fromYahoo(btcData) },
      // REITs
      { key: 'AVB',   label: 'AvalonBay', ...fromYahoo(avbData) },
      { key: 'EQR',   label: 'Equity Res',...fromYahoo(eqrData) },
      { key: 'MAA',   label: 'MAA',       ...fromYahoo(maaData) },
      { key: 'ESS',   label: 'Essex Prop',...fromYahoo(essData) },
    ]

    return NextResponse.json({ rates })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
