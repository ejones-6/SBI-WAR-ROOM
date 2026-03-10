import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'

function getSupabase() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )
}

export async function GET() {
  try {
    const supabase = getSupabase()
    const { data, error } = await supabase.from('cap_rates').select('*')
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json(data)
  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? 'unknown' }, { status: 500 })
  }
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabase()
    const body = await req.json()
    if (!body.deal_name) return NextResponse.json({ error: 'deal_name required' }, { status: 400 })
    const { data, error } = await supabase
      .from('cap_rates')
      .upsert(body, { onConflict: 'deal_name' })
      .select()
      .single()
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json(data)
  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? 'unknown' }, { status: 500 })
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const supabase = getSupabase()
    const dealName = req.nextUrl.searchParams.get('deal')
    if (!dealName) return NextResponse.json({ error: 'deal param required' }, { status: 400 })
    const { error } = await supabase.from('cap_rates').delete().eq('deal_name', dealName)
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json({ ok: true })
  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? 'unknown' }, { status: 500 })
  }
}
