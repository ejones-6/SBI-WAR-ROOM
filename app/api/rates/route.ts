import { NextResponse } from 'next/server'

// US Treasury Fiscal Data API — completely free, no API key, official government source
// https://fiscaldata.treasury.gov/api-documentation/

export async function GET() {
  try {
    // Fetch last 2 days of yield curve data
    const url = 'https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/accounting/od/avg_interest_rates?fields=record_date,security_desc,avg_interest_rate_amt&filter=security_desc:in:(Treasury%20Notes,Treasury%20Bonds)&sort=-record_date&page[size]=20'

    // Actually use the daily treasury par yield curve endpoint
    const yieldUrl = 'https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/accounting/od/avg_interest_rates?sort=-record_date&page[size]=2&fields=record_date,security_desc,avg_interest_rate_amt'

    // Use the correct Treasury yield curve endpoint
    const res = await fetch(
      'https://home.treasury.gov/resource-center/data-chart-center/interest-rates/pages/xml?data=daily_treasury_yield_curve&field_tdr_date_value=all',
      { cache: 'no-store' }
    )

    // Fallback: use Yahoo Finance for UST + NY Fed for SOFR  
    const [ust5, ust7, ust10, sofr] = await Promise.all([
      fetch('https://query1.finance.yahoo.com/v8/finance/chart/%5EFVX?interval=1d&range=5d', { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store' }).then(r => r.json()),
      fetch('https://query1.finance.yahoo.com/v8/finance/chart/%5ETNX?interval=1d&range=5d', { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store' }).then(r => r.json()), // use 10Y as proxy for 7Y calculation
      fetch('https://query1.finance.yahoo.com/v8/finance/chart/%5ETNX?interval=1d&range=5d', { headers: { 'User-Agent': 'Mozilla/5.0' }, cache: 'no-store' }).then(r => r.json()),
      fetch('https://markets.newyorkfed.org/api/rates/sofr/last/2.json', { cache: 'no-store' }).then(r => r.json()).catch(() => null),
    ])

    function fromYahoo(data: any) {
      const meta = data?.chart?.result?.[0]?.meta
      if (!meta) return { rate: null, change: null }
      const rate = meta.regularMarketPrice ?? null
      const prev = meta.previousClose ?? null
      return { rate, change: rate != null && prev != null ? parseFloat((rate - prev).toFixed(3)) : null }
    }

    const sofrRate = sofr?.refRates?.[0]?.percentRate ?? null
    const sofrPrev = sofr?.refRates?.[1]?.percentRate ?? null

    const rates = [
      { key: 'SOFR',  label: 'SOFR',    rate: sofrRate, change: sofrRate != null && sofrPrev != null ? parseFloat((sofrRate - sofrPrev).toFixed(3)) : null },
      { key: 'DGS5',  label: '5Y UST',  ...fromYahoo(ust5)  },
      { key: 'DGS7',  label: '7Y UST',  rate: null, change: null }, // Yahoo has no 7Y — interpolate below
      { key: 'DGS10', label: '10Y UST', ...fromYahoo(ust10) },
    ]

    // Interpolate 7Y from 5Y and 10Y
    const r5  = rates[1].rate
    const r10 = rates[3].rate
    if (r5 != null && r10 != null) {
      rates[2].rate   = parseFloat((r5 + (r10 - r5) * (2 / 5)).toFixed(3))
      const c5  = rates[1].change
      const c10 = rates[3].change
      rates[2].change = c5 != null && c10 != null ? parseFloat((c5 + (c10 - c5) * (2 / 5)).toFixed(3)) : null
    }

    return NextResponse.json({ rates })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
