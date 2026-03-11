import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

// Smart city-based market resolver
function resolveMarket(market: string): string | null {
  if (!market) return null
  const m = market.toLowerCase().trim()

  // ── MID-ATLANTIC ──────────────────────────────────────────────
  // Washington DC
  if (m === 'washington, dc' || m === 'washington dc' || m === 'washington, dc-md-va') return 'Washington, DC'

  // Suburban Maryland
  const subMD = ['baltimore','columbia, md','owings mills','bethesda','silver spring','rockville','gaithersburg','germantown','bowie','laurel','college park','greenbelt','hyattsville','takoma park','chevy chase','potomac','north bethesda','kensington','wheaton']
  if (subMD.some(c => m.includes(c))) return 'Suburban Maryland'

  // Northern Virginia (suburbs closest to DC)
  const noVA = ['herndon','reston','arlington','alexandria','fairfax','tysons','mclean','vienna, va','woodbridge','manassas','sterling','ashburn','leesburg','chantilly','centreville','burke','springfield, va','falls church','annandale','lorton','dulles','rosslyn','ballston','crystal city','pentagon city','clarendon','shirlington','merrifield','oakton','nova','northern va','northern virginia']
  if (noVA.some(c => m.includes(c))) return 'Northern Virginia'

  // Richmond
  const richmondCities = ['richmond','henrico','chesterfield','midlothian','short pump','glen allen','mechanicsville','chester, va','colonial heights','petersburg, va','hopewell']
  if (richmondCities.some(c => m.includes(c))) return 'Richmond, VA'

  // Charlottesville
  if (m.includes('charlottesville')) return 'Charlottesville, VA'

  // Virginia Beach / Hampton Roads
  const hrCities = ['virginia beach','norfolk','chesapeake','hampton, va','newport news','portsmouth, va','suffolk, va','hampton roads']
  if (hrCities.some(c => m.includes(c))) return 'Virginia Beach, VA'

  // Fredericksburg area → Northern Virginia
  if (m.includes('fredericksburg') || m.includes('stafford') || m.includes('spotsylvania')) return 'Northern Virginia'

  // ── CAROLINAS ─────────────────────────────────────────────────
  const charlotteCities = ['charlotte','fort mill','rock hill','gastonia','concord, nc','kannapolis','huntersville','cornelius','davidson, nc','mooresville','mint hill','matthews, nc','ballantyne','pineville, nc']
  if (charlotteCities.some(c => m.includes(c))) return 'Charlotte, NC'

  const rduCities = ['raleigh','durham','chapel hill','cary','apex','morrisville','wake forest','garner','clayton, nc','holly springs','fuquay','pittsboro','hillsborough','carrboro','fayetteville, nc']
  if (rduCities.some(c => m.includes(c))) return 'Raleigh/Durham, NC'

  const gsoCities = ['greensboro','winston-salem','winston salem','high point','burlington, nc','graham, nc','asheboro','hickory','statesville','salisbury, nc']
  if (gsoCities.some(c => m.includes(c))) return 'Greensboro/Winston-Salem, NC'

  if (m.includes('wilmington, nc') || m.includes('wilmington nc')) return 'Wilmington, NC'

  const charlestonCities = ['charleston, sc','north charleston','summerville','goose creek','mount pleasant','hanahan','ladson','moncks corner']
  if (charlestonCities.some(c => m.includes(c))) return 'Charleston, SC'

  const greenvilleCities = ['greenville, sc','spartanburg','anderson, sc','simpsonville','mauldin','greer','taylors','easley','seneca']
  if (greenvilleCities.some(c => m.includes(c))) return 'Greenville, SC'

  if (m.includes('myrtle beach') || m.includes('mrytle beach') || m.includes('conway, sc') || m.includes('pawleys island')) return 'Misc - Carolinas'
  if (m.includes('asheville') || m.includes('hendersonville, nc')) return 'Misc - Carolinas'
  if (m.includes(', nc') || m.includes(', sc') || m.includes('north carolina') || m.includes('south carolina')) return 'Misc - Carolinas'

  // ── GEORGIA ───────────────────────────────────────────────────
  const atlantaCities = ['atlanta','buckhead','midtown','decatur','sandy springs','alpharetta','roswell, ga','marietta','smyrna, ga','dunwoody','johns creek','peachtree','norcross','duluth, ga','kennesaw','acworth','lawrenceville','snellville','athens, ga','macon','auburn, ga','cartersville','rome, ga','gainesville, ga','fayetteville, ga','newnan','chattanooga, tn-ga']
  if (atlantaCities.some(c => m.includes(c))) return 'Atlanta, GA'

  const savannahCities = ['savannah','pooler','richmond hill','hinesville','brunswick, ga','valdosta','statesboro']
  if (savannahCities.some(c => m.includes(c))) return 'Savannah, GA'

  if (m.includes(', ga') || m.includes('georgia')) return 'Misc - Georgia'

  // ── TEXAS ─────────────────────────────────────────────────────
  const dallasCities = ['dallas','fort worth','frisco','plano','mckinney','garland','irving','arlington, tx','denton','lewisville','carrollton','richardson, tx','allen, tx','wylie','rockwall','mansfield, tx','grand prairie','mesquite','rowlett','flower mound','southlake','grapevine','euless','bedford, tx']
  if (dallasCities.some(c => m.includes(c))) return 'Dallas, TX'

  const houstonCities = ['houston','sugar land','the woodlands','pearland','pasadena, tx','katy','league city','baytown','galveston','beaumont','conroe','humble, tx','spring, tx','cypress, tx','tomball','missouri city','stafford, tx','friendswood','brazoria']
  if (houstonCities.some(c => m.includes(c))) return 'Houston, TX'

  const austinCities = ['austin','round rock','cedar park','pflugerville','georgetown, tx','kyle, tx','buda','san marcos','leander','hutto']
  if (austinCities.some(c => m.includes(c))) return 'Austin, TX'

  const saCities = ['san antonio','new braunfels','seguin','schertz','universal city','converse, tx']
  if (saCities.some(c => m.includes(c))) return 'San Antonio, TX'

  if (m.includes(', tx') || m.includes('texas')) return 'Misc - Texas'

  // ── TENNESSEE ─────────────────────────────────────────────────
  const nashvilleCities = ['nashville','brentwood','franklin, tn','murfreesboro','smyrna, tn','la vergne','hendersonville, tn','gallatin','mount juliet','clarksville','columbia, tn','cookeville','knoxville','memphis','chattanooga','johnson city','kingsport']
  if (nashvilleCities.some(c => m.includes(c))) return 'Nashville, TN'

  if (m.includes(', tn') || m.includes('tennessee')) return 'Nashville, TN'

  // ── FLORIDA ───────────────────────────────────────────────────
  const jaxCities = ['jacksonville','jacksonville-st. augustine','st. augustine','fernandina beach','orange park','fleming island']
  if (jaxCities.some(c => m.includes(c))) return 'Jacksonville, FL'

  const orlandoCities = ['orlando','gainesville, fl','daytona beach','daytonabeach','ocala','space coast','palm bay','sanford, fl','ormond beach','deltona','lake mary','oviedo','longwood','kissimmee','osceola','brevard','melbourne, fl','titusville','cocoa','new smyrna','deland','leesburg, fl','ocoee','winter garden','apopka','altamonte','casselberry','maitland','winter park','winter haven','auburndale','bartow','lakeland']
  if (orlandoCities.some(c => m.includes(c))) return 'Orlando, FL'

  const tampaCities = ['tampa','st. petersburg','saint petersburg','clearwater','sarasota','bradenton','lakeland','destin','fort walton','pensacola','panama city','brooksville','spring hill, fl','wesley chapel','brandon','riverview, fl','sun city','apollo beach','ruskin','plant city','new port richey','port richey','tarpon springs','dunedin','largo, fl','pinellas park','palmetto, fl']
  if (tampaCities.some(c => m.includes(c))) return 'Tampa, FL'

  const naplesCities = ['naples, fl','fort myers','fort myers-cape coral','cape coral','bonita springs','marco island','punta gorda','port charlotte','englewood, fl','venice, fl','north port','estero']
  if (naplesCities.some(c => m.includes(c))) return 'Naples/Fort Myers, FL'

  const sflCities = ['miami','fort lauderdale','west palm beach','boca raton','boynton beach','delray beach','coconut creek','davie','pembroke pines','hollywood, fl','deerfield beach','pompano beach','coral springs','margate','tamarac','sunrise, fl','plantation, fl','miramar','hallandale','aventura','doral','hialeah','homestead','kendall','south florida','jupiter, fl','palm beach','lake worth','port st. lucie','port st lucie','fort pierce','stuart, fl','vero beach','treasure coast','wellington','greenacres','riviera beach','lake park','north palm beach','palm beach gardens']
  if (sflCities.some(c => m.includes(c))) return 'South Florida'

  if (m.includes(', fl') || m.includes('florida')) return 'Misc - Florida'

  return null // unknown — leave as-is
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
    const newMarket = resolveMarket(deal.market)
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
