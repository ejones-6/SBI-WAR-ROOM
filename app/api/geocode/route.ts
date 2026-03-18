// app/api/geocode/route.ts
import { NextRequest, NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  const address = req.nextUrl.searchParams.get('address')
  if (!address) return NextResponse.json({ error: 'address required' }, { status: 400 })

  try {
    // US Census Geocoder — free, no key, no rate limit, US addresses only
    const url = `https://geocoding.geo.census.gov/geocoder/locations/onelineaddress?address=${encodeURIComponent(address)}&benchmark=Public_AR_Current&format=json`
    const res = await fetch(url, {
      headers: { 'User-Agent': 'SBI-WarRoom/1.0' },
      signal: AbortSignal.timeout(10000)
    })

    if (!res.ok) return NextResponse.json({ lat: null, lng: null })

    const data = await res.json()
    const match = data?.result?.addressMatches?.[0]

    if (match?.coordinates) {
      return NextResponse.json({
        lat: match.coordinates.y,
        lng: match.coordinates.x
      })
    }

    return NextResponse.json({ lat: null, lng: null })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
