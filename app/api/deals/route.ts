import { createServerSupabaseClient as createClient } from '@/lib/supabase/server'
import { NextRequest, NextResponse } from 'next/server'

export async function GET() {
  const supabase = createClient()
  const { data, error } = await supabase.from('deals').select('*').order('modified', { ascending: false })
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data)
}

export async function POST(req: NextRequest) {
  const supabase = createClient()
  const body = await req.json()
  const { data, error } = await supabase.from('deals').insert(body).select().single()
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data)
}

export async function PATCH(req: NextRequest) {
  const supabase = createClient()
  const body = await req.json()
  const { name, ...updates } = body
  if (!name) return NextResponse.json({ error: 'name required' }, { status: 400 })
  updates.modified = new Date().toISOString().slice(0, 10)
  const { data, error } = await supabase.from('deals').update(updates).eq('name', name).select().limit(1).single()
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json(data)
}
