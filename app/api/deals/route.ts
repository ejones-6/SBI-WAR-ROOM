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

    if (body._batch) {
      const incoming: any[] = body.deals
      if (!incoming?.length) return NextResponse.json({ inserted: 0, updated: 0 })

      const { data: existing } = await supabase.from('deals').select('name, status')
      const existingMap = new Map((existing ?? []).map((d: any) => [d.name.trim(), d.status]))

      const LOCKED_PREFIXES = ['6', '7', '8', '9', '10']
      const ACTIVE_PREFIXES = ['1', '2', '3', '4', '5']

      const newDeals = incoming.filter(d => !existingMap.has(d.name.trim()))
      const existingDeals = incoming.filter(d => existingMap.has(d.name.trim()))

      // Insert new deals in chunks of 200
      let inserted = 0
      const chunkSize = 200
      for (let i = 0; i < newDeals.length; i += chunkSize) {
        const chunk = newDeals.slice(i, i + chunkSize)
        const { data, error } = await supabase.from('deals').insert(chunk).select('id')
        if (!error && data) inserted += data.length
      }

      // Update existing deals
      let updated = 0
      for (const deal of existingDeals) {
        const currentStatus = existingMap.get(deal.name.trim()) ?? ''
        const isLocked = LOCKED_PREFIXES.some(p => currentStatus.startsWith(p + ' -'))
        const isActive = ACTIVE_PREFIXES.some(p => currentStatus.startsWith(p + ' -'))

        const updates: any = { modified: new Date().toISOString().slice(0, 10) }

        // Never touch status/info on locked deals
        if (!isLocked) {
          if (deal.status)         updates.status = deal.status
          if (deal.units)          updates.units = deal.units
          if (deal.year_built)     updates.year_built = deal.year_built
          if (deal.purchase_price) updates.purchase_price = deal.purchase_price
          if (deal.price_per_unit) updates.price_per_unit = deal.price_per_unit
          if (deal.broker)         updates.broker = deal.broker
          if (deal.market)         updates.market = deal.market
        }

        // Always update bid_due_date for active/new deals even if null (to clear stale dates)
        if (isActive) {
          updates.bid_due_date = deal.bid_due_date ?? null
        }

        const { error } = await supabase.from('deals').update(updates).eq('name', deal.name.trim())
        if (!error) updated++
      }

      return NextResponse.json({ inserted, updated })
    }

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
