import { createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function GET() {
  const supabase = createClient()
  const { data, error } = await supabase.from('cap_rates').select('*')
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data)
}

export async function POST(req: NextRequest) {
  const supabase = createClient()
  const body = await req.json()
  if (!body.deal_name) return NextResponse.json({ error: 'deal_name required' }, { status: 400 })
  const { data, error } = await supabase
    .from('cap_rates')
    .upsert(body, { onConflict: 'deal_name' })
    .select()
    .single()
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data)
}

export async function DELETE(req: NextRequest) {
  const supabase = createClient()
  const dealName = req.nextUrl.searchParams.get('deal')
  if (!dealName) return NextResponse.json({ error: 'deal param required' }, { status: 400 })
  const { error } = await supabase.from('cap_rates').delete().eq('deal_name', dealName)
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
