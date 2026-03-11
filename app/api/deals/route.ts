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
      if (!incoming?.length) return NextResponse.json({ inserted: 0, updated: 0 })

      // Fetch ALL existing deals (paginated — DB may have 2000+ rows)
      let allExisting: any[] = []
      let pg = 0
      while (true) {
        const { data } = await supabase
          .from('deals')
          .select('name, comments, buyer, seller, sold_price')
          .range(pg * 1000, (pg + 1) * 1000 - 1)
        if (!data || data.length === 0) break
        allExisting = [...allExisting, ...data]
        if (data.length < 1000) break
        pg++
      }

      const existingMap = new Map(allExisting.map((d: any) => [d.name.trim(), d]))

      const toInsert: any[] = []
      const toUpdate: any[] = []

      for (const deal of incoming) {
        const name = deal.name.trim()
        const existing = existingMap.get(name)

        // Always mirror these from Rediq
        const rediqFields: any = {
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
        }

        // bid_due_date: only write if the file has a value — never wipe a date
        if (deal.bid_due_date != null && deal.bid_due_date !== '') {
          rediqFields.bid_due_date = deal.bid_due_date
        }

        if (!existing) {
          // New deal — insert with blank War Room fields
          toInsert.push({
            ...rediqFields,
            flagged:    false,
            hot:        false,
            comments:   null,
            buyer:      null,
            seller:     null,
            sold_price: null,
          })
        } else {
          // Existing deal — mirror Rediq fields, preserve War Room fields
          toUpdate.push({
            ...rediqFields,
            comments:   existing.comments   ?? null,
            buyer:      existing.buyer      ?? null,
            seller:     existing.seller     ?? null,
            sold_price: existing.sold_price ?? null,
          })
        }
      }

      // Insert new deals in chunks of 200
      let inserted = 0
      for (let i = 0; i < toInsert.length; i += 200) {
        const chunk = toInsert.slice(i, i + 200)
        const { data, error } = await supabase.from('deals').insert(chunk).select('id')
        if (error) console.error('Batch insert error:', error.message)
        if (data) inserted += data.length
      }

      // Update existing deals in parallel batches of 100
      let updated = 0
      for (let i = 0; i < toUpdate.length; i += 100) {
        const batch = toUpdate.slice(i, i + 100)
        const results = await Promise.all(
          batch.map(({ name, ...fields }) =>
            supabase.from('deals').update(fields).eq('name', name).select('id')
          )
        )
        updated += results.filter(r => r.data && r.data.length > 0).length
      }

      return NextResponse.json({ inserted, updated })
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
