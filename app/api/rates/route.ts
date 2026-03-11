import { NextResponse } from 'next/server'

const FRED_KEY = 'b1a5cb8e99b546eb01d5c67e3c3bc2ef'

const SERIES = [
  { key: 'SOFR',  label: 'SOFR',   id: 'SOFR'  },
  { key: 'DGS5',  label: '5Y UST', id: 'DGS5'  },
  { key: 'DGS7',  label: '7Y UST', id: 'DGS7'  },
  { key: 'DGS10', label: '10Y UST',id: 'DGS10' },
]

export async function GET() {
  try {
    const results = await Promise.all(
      SERIES.map(async ({ key, label, id }) => {
        const url = `https://api.stlouisfed.org/fred/series/observations?series_id=${id}&api_key=${FRED_KEY}&sort_order=desc&limit=2&file_type=json`
        const res = await fetch(url, { next: { revalidate: 3600 } })
        const data = await res.json()
        const obs = (data.observations ?? []).filter((o: any) => o.value !== '.')
        const latest = obs[0] ? parseFloat(obs[0].value) : null
        const prev   = obs[1] ? parseFloat(obs[1].value) : null
        return {
          key, label,
          rate:   latest,
          change: latest != null && prev != null ? parseFloat((latest - prev).toFixed(3)) : null,
          date:   obs[0]?.date ?? null,
        }
      })
    )
    return NextResponse.json({ rates: results })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
