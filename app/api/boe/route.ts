import { createServerSupabaseClient as createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function GET(req: NextRequest) {
  const supabase = createClient()
  const dealName = req.nextUrl.searchParams.get('deal')
  if (!dealName) return NextResponse.json({ error: 'deal param required' }, { status: 400 })
  const { data, error } = await supabase.from('boe_data').select('*').eq('deal_name', dealName).single()
  if (error && error.code !== 'PGRST116') return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data ?? null)
}

export async function POST(req: NextRequest) {
  const supabase = createClient()
  const body = await req.json()
  if (!body.deal_name) return NextResponse.json({ error: 'deal_name required' }, { status: 400 })
  const { data, error } = await supabase
    .from('boe_data')
    .upsert(body, { onConflict: 'deal_name' })
    .select()
    .single()
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data)
}
