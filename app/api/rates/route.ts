import { NextResponse } from 'next/server'

export async function GET() {
  try {
    // US Treasury publishes daily yield curve data — free, no key needed
    const res = await fetch(
      'https://home.treasury.gov/resource-center/data-chart-center/interest-rates/pages/xml?data=daily_treasury_yield_curve&field_tdr_date_value=202603',
      { next: { revalidate: 3600 } }
    )
    const xml = await res.text()

    // Parse XML for 5Y, 7Y, 10Y yields
    function extract(tag: string): number | null {
      const match = xml.match(new RegExp(`<d:BC_${tag}>([\\d.]+)<`))
      return match ? parseFloat(match[1]) : null
    }

    // Get last two entries for change calculation
    const entries = xml.split('<entry>').slice(1)
    const latest = entries[entries.length - 1] ?? ''
    const prev   = entries[entries.length - 2] ?? ''

    function extractFrom(block: string, tag: string): number | null {
      const match = block.match(new RegExp(`<d:BC_${tag}>([\\d.]+)<`))
      return match ? parseFloat(match[1]) : null
    }

    // SOFR from NY Fed
    let sofr: number | null = null
    let sofrPrev: number | null = null
    try {
      const sofrRes = await fetch('https://markets.newyorkfed.org/api/rates/sofr/last/2.json')
      const sofrData = await sofrRes.json()
      const obs = sofrData.refRates ?? []
      sofr     = obs[0]?.percentRate ?? null
      sofrPrev = obs[1]?.percentRate ?? null
    } catch {}

    const rates = [
      {
        key: 'SOFR', label: 'SOFR',
        rate: sofr,
        change: sofr != null && sofrPrev != null ? parseFloat((sofr - sofrPrev).toFixed(3)) : null,
      },
      {
        key: 'DGS5', label: '5Y UST',
        rate: extractFrom(latest, '5YEAR'),
        change: (() => {
          const a = extractFrom(latest, '5YEAR'), b = extractFrom(prev, '5YEAR')
          return a != null && b != null ? parseFloat((a - b).toFixed(3)) : null
        })(),
      },
      {
        key: 'DGS7', label: '7Y UST',
        rate: extractFrom(latest, '7YEAR'),
        change: (() => {
          const a = extractFrom(latest, '7YEAR'), b = extractFrom(prev, '7YEAR')
          return a != null && b != null ? parseFloat((a - b).toFixed(3)) : null
        })(),
      },
      {
        key: 'DGS10', label: '10Y UST',
        rate: extractFrom(latest, '10YEAR'),
        change: (() => {
          const a = extractFrom(latest, '10YEAR'), b = extractFrom(prev, '10YEAR')
          return a != null && b != null ? parseFloat((a - b).toFixed(3)) : null
        })(),
      },
    ]

    return NextResponse.json({ rates })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
