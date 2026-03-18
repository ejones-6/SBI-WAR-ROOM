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

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabase()

    // Fetch all deals with address but no lat/lng
    const { data: deals, error } = await supabase
      .from('deals')
      .select('id, name, address')
      .not('address', 'is', null)
      .neq('address', '')
      .or('lat.is.null,lng.is.null')
      .limit(9500) // Census batch limit is 10,000

    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    if (!deals?.length) return NextResponse.json({ message: 'All deals already geocoded', count: 0 })

    // Build CSV: ID,Address,City,State,Zip
    // Census batch format: unique_id, street, city, state, zip
    const csvRows = deals.map((d, i) => {
      const parts = (d.address || '').split(',').map((s: string) => s.trim())
      const street = parts[0] || ''
      const city = parts[1] || ''
      const stateZip = parts[2] || ''
      const zip = parts[3] || ''
      // Extract state from "TX" or "TX 76155"
      const state = stateZip.replace(/\d/g, '').trim()
      const zipClean = zip || stateZip.replace(/[^\d]/g, '').trim()
      return `${i},${street},${city},${state},${zipClean}`
    })

    const csv = csvRows.join('\n')

    // POST to Census batch geocoder
    const formData = new FormData()
    const blob = new Blob([csv], { type: 'text/csv' })
    formData.append('addressFile', blob, 'addresses.csv')
    formData.append('benchmark', 'Public_AR_Current')
    formData.append('returntype', 'locations')

    const censusRes = await fetch(
      'https://geocoding.geo.census.gov/geocoder/locations/addressbatch',
      { method: 'POST', body: formData, signal: AbortSignal.timeout(55000) }
    )

    if (!censusRes.ok) {
      return NextResponse.json({ error: `Census API error: ${censusRes.status}` }, { status: 500 })
    }

    const resultText = await censusRes.text()
    const lines = resultText.trim().split('\n').filter(Boolean)

    // Parse results and save to DB
    // Census output: ID, input_address, match, matchtype, parsed_address, coords, tiger_id, side
    let saved = 0
    const updates: Promise<any>[] = []

    for (const line of lines) {
      const cols = line.split(',')
      const idx = parseInt(cols[0])
      const matched = cols[2]?.trim().toLowerCase() === 'match'
      const coords = cols[5]?.trim() // "lng,lat" format

      if (!matched || !coords || idx >= deals.length) continue

      const [lng, lat] = coords.replace(/"/g, '').split(',').map(Number)
      if (isNaN(lat) || isNaN(lng)) continue

      const deal = deals[idx]
      updates.push(
        supabase.from('deals').update({ lat, lng }).eq('id', deal.id).then()
      )
      saved++
    }

    await Promise.all(updates)

    return NextResponse.json({
      submitted: deals.length,
      geocoded: saved,
      failed: deals.length - saved
    })

  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
