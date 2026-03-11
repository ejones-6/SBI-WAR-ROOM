import type { Deal, Region } from './types'

export function fmtShort(n: number | null | undefined): string {
  if (!n) return '—'
  if (n >= 1_000_000_000) return '$' + (n / 1_000_000_000).toFixed(2) + 'B'
  if (n >= 1_000_000) return '$' + (n / 1_000_000).toFixed(1) + 'M'
  if (n >= 1_000) return '$' + (n / 1_000).toFixed(0) + 'K'
  return '$' + n.toLocaleString()
}

export function fmtUnit(n: number | null | undefined): string {
  if (!n) return '—'
  return '$' + Math.round(n).toLocaleString()
}

export function fmtPct(n: number): string {
  return n.toFixed(2) + '%'
}

export function fmtCurrency(n: number | null | undefined): string {
  if (!n) return '—'
  return '$' + n.toLocaleString()
}

export const REGION_MAP: Record<Region, string[]> = {
  DC: [
    'Washington, DC','Baltimore, MD','Columbia, MD','Owings Mills, MD',
    'Richmond, VA','Charlottesville, VA','Fredericksburg, VA','Waynesboro, VA','Virginia Beach, VA',
  ],
  Carolinas: [
    'Charlotte, NC','Raleigh/Durham, NC','Greensboro, NC','Asheville, NC','Wilmington, NC','Cary, NC','Chapel Hill, NC','Durham, NC',
    'Charleston, SC','Greenville, SC','Myrtle Beach, SC','Summerville, SC','Fort Mill, SC',
  ],
  GA: [
    'Atlanta, GA','Savannah, GA','Macon, GA',
  ],
  TX: [
    'Dallas, TX','Houston, TX',
  ],
  TN: [
    'Nashville, TN',
  ],
  FL: [
    'Orlando, FL','Tampa, FL','Miami, FL','Fort Lauderdale, FL','West Palm Beach, FL',
    'Jacksonville, FL','Sarasota, FL','Fort Myers, FL','Naples, FL','Gainesville, FL',
    'Daytona Beach, FL','Ocala, FL','Lakeland, FL','St. Petersburg, FL','Clearwater, FL',
    'Boynton Beach, FL','Delray Beach, FL','Coconut Creek, FL','Davie, FL','Pembroke Pines, FL',
    'Jupiter, FL','Palm Beach, FL','Lake Worth, FL','Port St. Lucie, FL','Stuart, FL','Vero Beach, FL',
    'Destin, FL','Space Coast, FL','Palm Bay, FL','Sanford, FL','Ormond Beach, FL',
  ],
  Misc: [],
}

// Legacy market string aliases — maps old Rediq MSA strings to new clean city names
export const MARKET_ALIAS: Record<string, string> = {
  // DC region
  'Washington, DC-MD-VA': 'Washington, DC',
  'Richmond-Petersburg, VA': 'Richmond, VA',
  'Norfolk-Virginia Beach-Newport News, VA-NC': 'Virginia Beach, VA',
  'Lynchburg, VA': 'Waynesboro, VA',
  // Carolinas
  'Raleigh-Durham-Chapel Hill, NC': 'Raleigh/Durham, NC',
  'Raleigh / Durham, NC': 'Raleigh/Durham, NC',
  'Raleigh, NC': 'Raleigh/Durham, NC',
  'Durham, NC': 'Raleigh/Durham, NC',
  'Charlotte-Gastonia-Rock Hill, NC-SC': 'Charlotte, NC',
  'Greensboro--Winston-Salem--High Point, NC': 'Greensboro, NC',
  'Fayetteville, NC': 'Raleigh/Durham, NC',
  'Hickory-Morganton-Lenoir, NC': 'Greensboro, NC',
  'Charleston-North Charleston, SC': 'Charleston, SC',
  'Greenville-Spartanburg-Anderson, SC': 'Greenville, SC',
  // GA
  'Athens, GA': 'Atlanta, GA',
  'Chattanooga, TN-GA': 'Atlanta, GA',
  // TX
  'Dallas-Fort Worth, TX': 'Dallas, TX',
  'Dallas / Fort Worth, TX': 'Dallas, TX',
  'Fort Worth, TX': 'Dallas, TX',
  'San Antonio, TX': 'Dallas, TX',
  'Austin-San Marcos, TX': 'Dallas, TX',
  'Austin, TX': 'Dallas, TX',
  'Brazoria, TX': 'Houston, TX',
  'Galveston-Texas City, TX': 'Houston, TX',
  // TN
  'Knoxville, TN': 'Nashville, TN',
  'Memphis, TN': 'Nashville, TN',
  'Chattanooga, TN': 'Nashville, TN',
  // FL
  'DaytonaBeach, FL': 'Daytona Beach, FL',
  'Ormond Beach, FL': 'Daytona Beach, FL',
  'Melbourne-Titusville-Palm Bay, FL': 'Space Coast, FL',
  'Lakeland-Winter Haven, FL': 'Lakeland, FL',
  'Jacksonville-St. Augustine, FL': 'Jacksonville, FL',
  'Tampa-St. Petersburg-Clearwater, FL': 'Tampa, FL',
  'Sarasota-Bradenton, FL': 'Sarasota, FL',
  'Fort Myers-Cape Coral, FL': 'Fort Myers, FL',
  'Punta Gorda, FL': 'Fort Myers, FL',
  'Fort Lauderdale-Hollywood, FL': 'Fort Lauderdale, FL',
  'West Palm Beach-Boca Raton, FL': 'West Palm Beach, FL',
  'Fort Pierce-Port St. Lucie, FL': 'Port St. Lucie, FL',
  'Port St Lucie, FL': 'Port St. Lucie, FL',
  'Mrytle Beach, SC': 'Myrtle Beach, SC',
}

export function getRegion(market: string): Region {
  // Direct match
  for (const [region, markets] of Object.entries(REGION_MAP)) {
    if ((markets as string[]).includes(market)) return region as Region
  }
  // Alias match (legacy Rediq MSA strings)
  const canonical = MARKET_ALIAS[market]
  if (canonical) {
    for (const [region, markets] of Object.entries(REGION_MAP)) {
      if ((markets as string[]).includes(canonical)) return region as Region
    }
  }
  return 'Misc'
}

export const REGION_LABELS: Record<Region, string> = {
  DC: 'DC MSA', Carolinas: 'Carolinas', GA: 'Georgia',
  TX: 'Texas', TN: 'Tennessee', FL: 'Florida', Misc: 'Misc',
}

export const STATUS_CLASS: Record<string, string> = {
  '1 - New': 's-new',
  '2 - Active': 's-active',
  '5 - Dormant': 's-dormant',
  '6 - Passed': 's-passed',
  '7 - Lost': 's-lost',
  '9 - Exited': 's-exited',
  '10 - Owned Property': 's-owned',
  '11 - Property Comp': 's-comp',
}

export function statusClass(s: string) {
  for (const [k, v] of Object.entries(STATUS_CLASS)) {
    if (s.includes(k.split(' - ')[0] + ' -')) return v
  }
  return 's-passed'
}

export function statusLabel(s: string): string {
  const parts = s.split(' - ')
  return parts.slice(1).join(' - ') || s
}

export function bidDateClass(d: string | null): string {
  if (!d) return ''
  const days = Math.ceil((new Date(d).getTime() - Date.now()) / 86400000)
  if (days < 0) return 'text-red-500'
  if (days <= 3) return 'text-red-500 font-bold'
  if (days <= 7) return 'text-amber-600 font-semibold'
  return 'text-slate-600'
}

export function formatBidDate(d: string | null): string {
  if (!d) return '—'
  const date = new Date(d + 'T12:00:00')
  const days = Math.ceil((date.getTime() - Date.now()) / 86400000)
  const str = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  if (days < 0) return str + ' (past)'
  if (days === 0) return str + ' (TODAY)'
  if (days <= 7) return str + ` (${days}d)`
  return str
}

export const ALL_STATUSES = [
  '1 - New','2 - Active','5 - Dormant','6 - Passed','7 - Lost','9 - Exited','10 - Owned Property','11 - Property Comp'
]

export function sortDeals(deals: Deal[], order: string): Deal[] {
  const d = [...deals]
  switch (order) {
    case 'modified-desc': return d.sort((a, b) => (b.modified ?? '').localeCompare(a.modified ?? ''))
    case 'biddate-asc':   return d.sort((a, b) => {
      if (!a.bid_due_date && !b.bid_due_date) return 0
      if (!a.bid_due_date) return 1
      if (!b.bid_due_date) return -1
      return a.bid_due_date.localeCompare(b.bid_due_date)
    })
    case 'price-desc':    return d.sort((a, b) => (b.purchase_price ?? 0) - (a.purchase_price ?? 0))
    case 'price-asc':     return d.sort((a, b) => (a.purchase_price ?? 0) - (b.purchase_price ?? 0))
    case 'units-desc':    return d.sort((a, b) => (b.units ?? 0) - (a.units ?? 0))
    case 'name-asc':      return d.sort((a, b) => a.name.localeCompare(b.name))
    case 'location-asc':  return d.sort((a, b) => (a.market ?? '').localeCompare(b.market ?? ''))
    default: return d
  }
}
