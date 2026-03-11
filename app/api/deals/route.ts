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

    // ── Batch upload from Rediq Deal Log ─────────────────────────────────────
    //
    // PHILOSOPHY: Mirror the deal log exactly for Rediq-owned fields.
    // Never touch War-Room-owned fields (comments, buyer, seller, sold_price, BOE, cap rates).
    //
    // Rediq owns:  name, status, market, units, year_built, purchase_price,
    //              price_per_unit, broker, address, added, modified, bid_due_date
    //
    // War Room owns: comments, buyer, seller, sold_price
    //                (boe_data and cap_rates are separate tables, never touched here)
    //
    // bid_due_date special rule: mirror from file IF file has a value.
    //   If file has no date yet, leave whatever is in the DB untouched.
    //   This means: add the date in Rediq → upload → it appears. Never wiped.
    //
    if (body._batch) {
      const incoming: any[] = body.deals
      if (!incoming?.length) return NextResponse.json({ inserted: 0, updated: 0, skipped: 0 })

      // Fetch ALL existing deals so we can diff
      let allExisting: any[] = []
      let pg = 0
      while (true) {
        const { data } = await supabase
          .from('deals')
          .select('*')
          .range(pg * 1000, (pg + 1) * 1000 - 1)
        if (!data || data.length === 0) break
        allExisting = [...allExisting, ...data]
        if (data.length < 1000) break
        pg++
      }

      const existingMap = new Map(allExisting.map((d: any) => [d.name.trim(), d]))

      const toInsert: any[] = []
      const toUpdate: any[] = []  // { name, fields } — only the fields that changed

      for (const deal of incoming) {
        const name = deal.name.trim()
        const ex = existingMap.get(name)

        if (!ex) {
          // Brand new — insert with all fields
          toInsert.push({
            name,
            status:         deal.status         ?? null,
            market:         deal.market         ?? null,
            units:          deal.units          ?? null,
            year_built:     deal.year_built     ?? null,
            purchase_price: deal.purchase_price ?? null,
            price_per_unit: deal.price_per_unit ?? null,
            broker:         deal.broker         ?? null,
            address:        deal.address        ?? null,
            added:          deal.added          ?? null,
            modified:       deal.modified       ?? null,
            bid_due_date:   (deal.bid_due_date && deal.bid_due_date !== '') ? deal.bid_due_date : null,
            flagged:        false,
            hot:            false,
            comments:       null,
            buyer:          null,
            seller:         null,
            sold_price:     null,
          })
        } else {
          // Build a partial update with only fields that changed
          const changes: any = {}

          // Simple string/number fields — direct comparison
          const rediqFields: [string, any][] = [
            ['status',         deal.status         ?? null],
            ['market',         deal.market         ?? null],
            ['units',          deal.units          ?? null],
            ['year_built',     deal.year_built     ?? null],
            ['purchase_price', deal.purchase_price ?? null],
            ['price_per_unit', deal.price_per_unit ?? null],
            ['broker',         deal.broker         ?? null],
            ['address',        deal.address        ?? null],
            ['modified',       deal.modified       ?? null],
          ]

          for (const [field, newVal] of rediqFields) {
            // Use loose comparison to handle number/string type differences from DB
            // eslint-disable-next-line eqeqeq
            if (newVal != (ex[field] ?? null)) {
              changes[field] = newVal
            }
          }

          // bid_due_date: only update if file has a value AND it differs from DB
          if (deal.bid_due_date && deal.bid_due_date !== '') {
            if (deal.bid_due_date !== (ex.bid_due_date ?? null)) {
              changes.bid_due_date = deal.bid_due_date
            }
          }

          if (Object.keys(changes).length > 0) {
            toUpdate.push({ name, changes })
          }
        }
      }

      // Insert new deals in chunks of 100
      let inserted = 0
      for (let i = 0; i < toInsert.length; i += 100) {
        const chunk = toInsert.slice(i, i + 100)
        const { data, error } = await supabase.from('deals').insert(chunk).select('id')
        if (error) console.error('Insert error:', error.message)
        if (data) inserted += data.length
      }

      // Update only changed fields on changed deals — targeted, no risk of overwriting anything
      let updated = 0
      for (const { name, changes } of toUpdate) {
        const { data, error } = await supabase
          .from('deals')
          .update(changes)
          .eq('name', name)
          .select('id')
        if (error) console.error('Update error for', name, ':', error.message)
        if (data && data.length > 0) updated++
      }

      const skipped = incoming.length - toInsert.length - toUpdate.length
      return NextResponse.json({ inserted, updated, skipped })
    }

    // ── Single deal insert (Add Deal button in UI) ────────────────────────────
    const { data, error } = await supabase.from('deals').insert(body).select()
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json(data?.[0])

  } catch (e: any) {
    return NextResponse.json({ error: e?.message ?? 'unknown' }, { status: 500 })
  }
}

// ── PATCH: manual edits saved from DealModal ─────────────────────────────────
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
