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

      // Fetch ALL existing deals — Supabase default page size is 1000, must paginate
      let allExisting: any[] = []
      let from = 0
      const PAGE = 500
      while (true) {
        const { data, error } = await supabase
          .from('deals')
          .select('name, status, market, units, year_built, purchase_price, price_per_unit, broker, address, added, modified, bid_due_date, comments, buyer, seller, sold_price')
          .range(from, from + PAGE - 1)
        if (error) {
          console.error('Fetch error at', from, ':', error.message)
          return NextResponse.json({ error: 'Failed to fetch existing deals: ' + error.message }, { status: 500 })
        }
        if (!data || data.length === 0) break
        allExisting = [...allExisting, ...data]
        if (data.length < PAGE) break
        from += PAGE
      }

      console.log('Fetched', allExisting.length, 'existing deals from DB')
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

          // Normalize a DB value to string for safe comparison
          // Supabase returns dates as strings like '2026-03-10', numbers as numbers
          const norm = (v: any) => (v == null ? '' : String(v).trim())

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
            if (norm(newVal) !== norm(ex[field])) {
              changes[field] = newVal
            }
          }

          // bid_due_date: ALWAYS write if file has a value — no conditions, no diff
          if (deal.bid_due_date && deal.bid_due_date !== '') {
            changes.bid_due_date = deal.bid_due_date
          }

          if (Object.keys(changes).length > 0) {
            toUpdate.push({ name, changes })
          }
        }
      }

      // Insert new deals — only send known columns, never surprise fields
      let inserted = 0
      const insertErrors: string[] = []
      const SAFE_COLS = ['name','status','market','units','year_built','purchase_price','price_per_unit','broker','address','added','modified','bid_due_date','flagged','hot','comments','buyer','seller','sold_price']
      for (const deal of toInsert) {
        const safe: any = {}
        for (const col of SAFE_COLS) if (col in deal) safe[col] = deal[col]
        const { data, error } = await supabase.from('deals').insert(safe).select('id')
        if (error) {
          console.error('Insert error for', deal.name, ':', error.message)
          insertErrors.push(deal.name + ': ' + error.message)
        }
        if (data && data.length > 0) inserted++
      }

      // Update only changed fields — run in parallel batches of 10 (fast, no rate limits)
      let updated = 0
      for (let i = 0; i < toUpdate.length; i += 10) {
        const batch = toUpdate.slice(i, i + 10)
        const results = await Promise.all(
          batch.map(({ name, changes }) =>
            supabase.from('deals').update(changes).eq('name', name).select('id')
          )
        )
        for (const { data, error } of results) {
          if (error) console.error('Update error:', error.message)
          if (data && data.length > 0) updated++
        }
      }

      const skipped = incoming.length - toInsert.length - toUpdate.length
      return NextResponse.json({ inserted, updated, skipped, insertErrors, dbFetched: allExisting.length })
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
