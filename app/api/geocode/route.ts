// app/api/geocode/route.ts
import { NextRequest, NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  const address = req.nextUrl.searchParams.get('address')
  if (!address) return NextResponse.json({ error: 'address required' }, { status: 400 })

  try {
    const parts = address.split(',').map(s => s.trim())
    const street = parts[0] || ''
    const rest = parts.slice(1).join(', ')

    // Try structured search first (more accurate with zip)
    const structuredUrl = `https://nominatim.openstreetmap.org/search?street=${encodeURIComponent(street)}&q=${encodeURIComponent(rest)}&countrycodes=us&format=json&limit=1`
    let res = await fetch(structuredUrl, {
      headers: { 'User-Agent': 'SBI-WarRoom/1.0 (private acquisitions tool)' },
      signal: AbortSignal.timeout(8000)
    })

    // Pass through rate limit status
    if (res.status === 429) {
      return NextResponse.json({ error: 'rate limited' }, { status: 429 })
    }

    let data = await res.json()

    // Fallback to free-text search
    if (!data?.[0]) {
      const fallbackUrl = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(address + ', USA')}&countrycodes=us&format=json&limit=1`
      res = await fetch(fallbackUrl, {
        headers: { 'User-Agent': 'SBI-WarRoom/1.0 (private acquisitions tool)' },
        signal: AbortSignal.timeout(8000)
      })
      if (res.status === 429) return NextResponse.json({ error: 'rate limited' }, { status: 429 })
      data = await res.json()
    }

    if (data?.[0]) {
      return NextResponse.json({ lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) })
    }
    return NextResponse.json({ lat: null, lng: null })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
