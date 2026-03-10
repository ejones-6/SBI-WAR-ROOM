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
    const { data, error } = await supabase.from('deals').select('*').order('modified', { ascending: false })
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

    // Batch import — only insert new deals
    if (body._batch) {
      const incoming: any[] = body.deals
      if (!incoming?.length) return NextResponse.json({ inserted: 0, skipped: 0 })

      // Fetch all existing deal names in one query
      const { data: existing } = await supabase
        .from('deals')
        .select('name')
      const existingNames = new Set((existing ?? []).map((d: any) => d.name.trim()))

      // Filter to only new deals
      const newDeals = incoming.filter(d => !existingNames.has(d.name.trim()))

      if (newDeals.length === 0) {
        return NextResponse.json({ inserted: 0, skipped: incoming.length })
      }

      // Insert in chunks of 200 to avoid payload limits
      let inserted = 0
      const chunkSize = 200
      for (let i = 0; i < newDeals.length; i += chunkSize) {
        const chunk = newDeals.slice(i, i + chunkSize)
        const { data, error } = await supabase.from('deals').insert(chunk).select('id')
        if (!error && data) inserted += data.length
      }

      return NextResponse.json({ inserted, skipped: incoming.length - inserted })
    }

    // Regular single deal insert (from Add Deal form)
    const { data, error } = await supabase.from('deals').insert(body).select()
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json(data?.[0])
  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? 'unknown' }, { status: 500 })
  }
}

export async function PATCH(req: NextRequest) {
  try {
    const supabase = getSupabase()
    const body = await req.json()
    const { name, id, ...updates } = body
    if (!name && !id) return NextResponse.json({ error: 'name or id required' }, { status: 400 })
    updates.modified = new Date().toISOString().slice(0, 10)
    let data, error
    if (id) {
      ({ data, error } = await supabase.from('deals').update(updates).eq('id', id).select())
    } else {
      ({ data, error } = await supabase.from('deals').update(updates).eq('name', name).select())
    }
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    if (!data || data.length === 0) return NextResponse.json({ error: 'no rows updated' }, { status: 404 })
    return NextResponse.json(data[0])
  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? 'unknown' }, { status: 500 })
  }
}
