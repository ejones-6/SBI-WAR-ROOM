// app/api/geocode/batch/route.ts
import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'
export const maxDuration = 60

function getSupabase() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )
}

async function geocodeBatch(deals: { id: string; name: string; address: string }[]) {
  const csvRows = deals.map((d, i) => {
    const parts = (d.address || '').split(',').map((s: string) => s.trim())
    const street = parts[0] || ''
    const city = parts[1] || ''
    const state = (parts[2] || '').replace(/\d/g, '').trim()
    const zip = (parts[3] || (parts[2] || '').replace(/[^\d]/g, '')).trim()
    return `${i},"${street}","${city}","${state}","${zip}"`
  })

  const csv = csvRows.join('\n')
  const formData = new FormData()
  formData.append('addressFile', new Blob([csv], { type: 'text/csv' }), 'addresses.csv')
  formData.append('benchmark', 'Public_AR_Current')
  formData.append('returntype', 'locations')

  const res = await fetch('https://geocoding.geo.census.gov/geocoder/locations/addressbatch', {
    method: 'POST',
    body: formData,
    signal: AbortSignal.timeout(50000)
  })

  if (!res.ok) throw new Error(`Census API ${res.status}`)

  const text = await res.text()
  const results: { idx: number; lat: number; lng: number }[] = []

  for (const line of text.trim().split('\n').filter(Boolean)) {
    const cols = line.split(',')
    const idx = parseInt(cols[0])
    const matched = cols[2]?.trim().toLowerCase() === 'match'
    const coords = cols[5]?.trim().replace(/"/g, '')
    if (!matched || !coords || isNaN(idx)) continue
    const [lng, lat] = coords.split(',').map(Number)
    if (!isNaN(lat) && !isNaN(lng)) results.push({ idx, lat, lng })
  }

  return results
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabase()
    const body = await req.json().catch(() => ({}))
    const offset = body.offset ?? 0
    const batchSize = 500 // Safe chunk size that completes within 60s

    const { data: deals, error } = await supabase
      .from('deals')
      .select('id, name, address')
      .not('address', 'is', null)
      .neq('address', '')
      .or('lat.is.null,lng.is.null')
      .range(offset, offset + batchSize - 1)

    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    if (!deals?.length) return NextResponse.json({ done: true, geocoded: 0, remaining: 0 })

    const results = await geocodeBatch(deals)

    // Save all results
    await Promise.all(results.map(r =>
      Promise.resolve(supabase.from('deals')
        .update({ lat: r.lat, lng: r.lng })
        .eq('id', deals[r.idx].id))
    ))

    // Check how many still need geocoding
    const { count } = await supabase
      .from('deals')
      .select('id', { count: 'exact', head: true })
      .not('address', 'is', null)
      .neq('address', '')
      .or('lat.is.null,lng.is.null')

    return NextResponse.json({
      done: (count ?? 0) === 0,
      submitted: deals.length,
      geocoded: results.length,
      failed: deals.length - results.length,
      remaining: count ?? 0,
      nextOffset: offset + batchSize
    })

  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
