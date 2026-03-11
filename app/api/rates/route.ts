import { NextResponse } from 'next/server'

function extractFrom(block: string, tag: string): number | null {
  const match = block.match(new RegExp(`<d:BC_${tag}>([\\d.]+)<`))
  return match ? parseFloat(match[1]) : null
}

function calcChange(latest: string, prev: string, tag: string): number | null {
  const a = extractFrom(latest, tag)
  const b = extractFrom(prev, tag)
  return a != null && b != null ? parseFloat((a - b).toFixed(3)) : null
}

export async function GET() {
  try {
    const [treasuryRes, sofrRes] = await Promise.all([
      fetch('https://home.treasury.gov/resource-center/data-chart-center/interest-rates/pages/xml?data=daily_treasury_yield_curve&field_tdr_date_value=202603', { next: { revalidate: 3600 } }),
      fetch('https://markets.newyorkfed.org/api/rates/sofr/last/2.json'),
    ])

    const xml = await treasuryRes.text()
    const sofrData = await sofrRes.json()

    const entries = xml.split('<entry>').slice(1)
    const latest = entries[entries.length - 1] ?? ''
    const prev   = entries[entries.length - 2] ?? ''

    const obs = sofrData.refRates ?? []
    const sofr     = obs[0]?.percentRate ?? null
    const sofrPrev = obs[1]?.percentRate ?? null

    const rates = [
      { key: 'SOFR',  label: 'SOFR',    rate: sofr,                          change: sofr != null && sofrPrev != null ? parseFloat((sofr - sofrPrev).toFixed(3)) : null },
      { key: 'DGS5',  label: '5Y UST',  rate: extractFrom(latest, '5YEAR'),  change: calcChange(latest, prev, '5YEAR')  },
      { key: 'DGS7',  label: '7Y UST',  rate: extractFrom(latest, '7YEAR'),  change: calcChange(latest, prev, '7YEAR')  },
      { key: 'DGS10', label: '10Y UST', rate: extractFrom(latest, '10YEAR'), change: calcChange(latest, prev, '10YEAR') },
    ]

    return NextResponse.json({ rates })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
