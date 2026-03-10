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

      const { data: existing } = await supabase.from('deals').select('name, status').limit(5000)
      const existingMap = new Map((existing ?? []).map((d: any) => [d.name.trim(), d.status]))

      const LOCKED_PREFIXES = ['6', '7', '8', '9', '10']
      const ACTIVE_PREFIXES = ['1', '2', '3', '4', '5']

      const newDeals = incoming.filter(d => !existingMap.has(d.name.trim()))
      const existingDeals = incoming.filter(d => existingMap.has(d.name.trim()))

      // Insert new deals in chunks of 200
      let inserted = 0
      for (let i = 0; i < newDeals.length; i += 500) {
        const chunk = newDeals.slice(i, i + 200)
        const { data } = await supabase.from('deals').insert(chunk).select('id')
        if (data) inserted += data.length
      }

      // Upsert existing deals using upsert on name
      // Build update objects and upsert in bulk
      const toUpdate = existingDeals.map(deal => {
        const currentStatus = existingMap.get(deal.name.trim()) ?? ''
        const isLocked = LOCKED_PREFIXES.some(p => currentStatus.startsWith(p + ' -'))
        const isActive = ACTIVE_PREFIXES.some(p => currentStatus.startsWith(p + ' -'))

        const row: any = { name: deal.name.trim() }
        if (!isLocked) {
          if (deal.status)         row.status = deal.status
          if (deal.units)          row.units = deal.units
          if (deal.year_built)     row.year_built = deal.year_built
          if (deal.purchase_price) row.purchase_price = deal.purchase_price
          if (deal.price_per_unit) row.price_per_unit = deal.price_per_unit
          if (deal.broker)         row.broker = deal.broker
          if (deal.market)         row.market = deal.market
        }
        // Always sync bid_due_date for active/new deals
        if (isActive || !isLocked) {
          row.bid_due_date = deal.bid_due_date ?? null
        }
        return row
      })

      // Run updates in parallel batches of 50
      let updated = 0
      const batchSize = 100
      for (let i = 0; i < toUpdate.length; i += batchSize) {
        const batch = toUpdate.slice(i, i + batchSize)
        await Promise.all(batch.map(row => {
          const { name, ...fields } = row
          return supabase.from('deals').update(fields).eq('name', name)
        }))
        updated += batch.length
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
