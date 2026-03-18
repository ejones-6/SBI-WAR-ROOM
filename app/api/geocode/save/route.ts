// app/api/geocode/save/route.ts
import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

function getSupabase() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )
}

export async function POST(req: NextRequest) {
  try {
    const { name, lat, lng } = await req.json()
    if (!name || !lat || !lng) return NextResponse.json({ error: 'name, lat, lng required' }, { status: 400 })
    const supabase = getSupabase()
    const { error } = await supabase
      .from('deals')
      .update({ lat, lng })  // Only update lat/lng — no modified timestamp
      .eq('name', name)
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json({ ok: true })
  } catch (e: any) {
    return NextResponse.json({ error: e.message }, { status: 500 })
  }
}
