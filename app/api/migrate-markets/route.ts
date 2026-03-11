import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const MARKET_MIGRATION: Record<string, string> = {
  // Mid-Atlantic
  'Washington, DC-MD-VA': 'Washington, DC',
  'Baltimore, MD': 'Suburban Maryland',
  'Columbia, MD': 'Suburban Maryland',
  'Owings Mills, MD': 'Suburban Maryland',
  'Richmond-Petersburg, VA': 'Richmond, VA',
  'Richmond, VA': 'Richmond, VA',
  'Norfolk-Virginia Beach-Newport News, VA-NC': 'Virginia Beach, VA',
  'Virginia Beach, VA': 'Virginia Beach, VA',
  'Charlottesville, VA': 'Charlottesville, VA',
  'Fredericksburg, VA': 'Northern Virginia',
  'Northern Virginia, VA': 'Northern Virginia',
  'Hampton Roads, VA': 'Virginia Beach, VA',
  'Waynesboro, VA': 'Misc - Mid-Atlantic',
  'Lynchburg, VA': 'Misc - Mid-Atlantic',
  // Carolinas
  'Charlotte-Gastonia-Rock Hill, NC-SC': 'Charlotte, NC',
  'Charlotte, NC': 'Charlotte, NC',
  'Fort Mill, SC': 'Charlotte, NC',
  'Raleigh-Durham-Chapel Hill, NC': 'Raleigh/Durham, NC',
  'Raleigh / Durham, NC': 'Raleigh/Durham, NC',
  'Raleigh, NC': 'Raleigh/Durham, NC',
  'Durham, NC': 'Raleigh/Durham, NC',
  'Cary, NC': 'Raleigh/Durham, NC',
  'Chapel Hill, NC': 'Raleigh/Durham, NC',
  'Fayetteville, NC': 'Raleigh/Durham, NC',
  'Greensboro--Winston-Salem--High Point, NC': 'Greensboro/Winston-Salem, NC',
  'Greensboro, NC': 'Greensboro/Winston-Salem, NC',
  'Hickory-Morganton-Lenoir, NC': 'Greensboro/Winston-Salem, NC',
  'Wilmington, NC': 'Wilmington, NC',
  'Asheville, NC': 'Misc - Carolinas',
  'Charleston-North Charleston, SC': 'Charleston, SC',
  'Charleston, SC': 'Charleston, SC',
  'Summerville, SC': 'Charleston, SC',
  'Greenville-Spartanburg-Anderson, SC': 'Greenville, SC',
  'Greenville, SC': 'Greenville, SC',
  'Myrtle Beach, SC': 'Misc - Carolinas',
  'Mrytle Beach, SC': 'Misc - Carolinas',
  // Georgia
  'Atlanta, GA': 'Atlanta, GA',
  'Athens, GA': 'Atlanta, GA',
  'Macon, GA': 'Atlanta, GA',
  'Chattanooga, TN-GA': 'Atlanta, GA',
  'Savannah, GA': 'Savannah, GA',
  // Texas
  'Dallas-Fort Worth, TX': 'Dallas, TX',
  'Dallas / Fort Worth, TX': 'Dallas, TX',
  'Dallas, TX': 'Dallas, TX',
  'Fort Worth, TX': 'Dallas, TX',
  'Houston, TX': 'Houston, TX',
  'Brazoria, TX': 'Houston, TX',
  'Galveston-Texas City, TX': 'Houston, TX',
  'Austin-San Marcos, TX': 'Austin, TX',
  'Austin, TX': 'Austin, TX',
  'San Antonio, TX': 'San Antonio, TX',
  // Tennessee
  'Nashville, TN': 'Nashville, TN',
  'Knoxville, TN': 'Nashville, TN',
  'Memphis, TN': 'Nashville, TN',
  'Chattanooga, TN': 'Nashville, TN',
  // Florida
  'Jacksonville, FL': 'Jacksonville, FL',
  'Jacksonville-St. Augustine, FL': 'Jacksonville, FL',
  'Orlando, FL': 'Orlando, FL',
  'Gainesville, FL': 'Orlando, FL',
  'Daytona Beach, FL': 'Orlando, FL',
  'DaytonaBeach, FL': 'Orlando, FL',
  'Ocala, FL': 'Orlando, FL',
  'Space Coast, FL': 'Orlando, FL',
  'Melbourne-Titusville-Palm Bay, FL': 'Orlando, FL',
  'Palm Bay, FL': 'Orlando, FL',
  'Sanford, FL': 'Orlando, FL',
  'Ormond Beach, FL': 'Orlando, FL',
  'Lakeland-Winter Haven, FL': 'Tampa, FL',
  'Lakeland, FL': 'Tampa, FL',
  'Tampa-St. Petersburg-Clearwater, FL': 'Tampa, FL',
  'Tampa, FL': 'Tampa, FL',
  'St. Petersburg, FL': 'Tampa, FL',
  'Clearwater, FL': 'Tampa, FL',
  'Sarasota-Bradenton, FL': 'Tampa, FL',
  'Sarasota, FL': 'Tampa, FL',
  'Destin, FL': 'Tampa, FL',
  'Miami, FL': 'South Florida',
  'Fort Lauderdale, FL': 'South Florida',
  'Fort Lauderdale-Hollywood, FL': 'South Florida',
  'West Palm Beach, FL': 'South Florida',
  'West Palm Beach-Boca Raton, FL': 'South Florida',
  'Boynton Beach, FL': 'South Florida',
  'Delray Beach, FL': 'South Florida',
  'Coconut Creek, FL': 'South Florida',
  'Davie, FL': 'South Florida',
  'Pembroke Pines, FL': 'South Florida',
  'Jupiter, FL': 'South Florida',
  'Palm Beach, FL': 'South Florida',
  'Lake Worth, FL': 'South Florida',
  'Port St. Lucie, FL': 'South Florida',
  'Port St Lucie, FL': 'South Florida',
  'Fort Pierce-Port St. Lucie, FL': 'South Florida',
  'Stuart, FL': 'South Florida',
  'Vero Beach, FL': 'South Florida',
  'Fort Myers-Cape Coral, FL': 'Naples/Fort Myers, FL',
  'Fort Myers, FL': 'Naples/Fort Myers, FL',
  'Naples, FL': 'Naples/Fort Myers, FL',
  'Punta Gorda, FL': 'Naples/Fort Myers, FL',
}

export async function GET() {
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )

  let allDeals: any[] = []
  let page = 0
  while (true) {
    const { data, error } = await supabase.from('deals').select('name, market').range(page * 500, page * 500 + 499)
    if (error || !data?.length) break
    allDeals = allDeals.concat(data)
    if (data.length < 500) break
    page++
  }

  let updated = 0, skipped = 0
  const unknown: string[] = []
  const changes: { name: string; from: string; to: string }[] = []

  for (const deal of allDeals) {
    const newMarket = MARKET_MIGRATION[deal.market]
    if (!newMarket) {
      if (deal.market && !unknown.includes(deal.market)) unknown.push(deal.market)
      skipped++
      continue
    }
    if (newMarket === deal.market) { skipped++; continue }
    const { error } = await supabase.from('deals').update({ market: newMarket }).eq('name', deal.name)
    if (!error) { updated++; changes.push({ name: deal.name, from: deal.market, to: newMarket }) }
  }

  return NextResponse.json({ updated, skipped, unknown, changes })
}
