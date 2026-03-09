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
  DC: ['Washington, DC-MD-VA','Baltimore, MD','Richmond-Petersburg, VA','Charlottesville, VA','Norfolk-Virginia Beach-Newport News, VA-NC','Lynchburg, VA'],
  NC: ['Raleigh-Durham-Chapel Hill, NC','Charlotte-Gastonia-Rock Hill, NC-SC','Greensboro--Winston-Salem--High Point, NC','Asheville, NC','Wilmington, NC','Fayetteville, NC','Hickory-Morganton-Lenoir, NC'],
  SC: ['Charleston-North Charleston, SC','Greenville-Spartanburg-Anderson, SC','Myrtle Beach, SC'],
  GA: ['Atlanta, GA','Athens, GA','Savannah, GA','Macon, GA','Chattanooga, TN-GA'],
  TX: ['Dallas-Fort Worth, TX','Fort Worth, TX','Houston, TX','San Antonio, TX','Austin-San Marcos, TX','Brazoria, TX','Galveston-Texas City, TX'],
  Nashville: ['Nashville, TN','Knoxville, TN'],
  Orlando: ['Orlando, FL','Daytona Beach, FL','Gainesville, FL','Ocala, FL','Melbourne-Titusville-Palm Bay, FL','Lakeland-Winter Haven, FL'],
  Tampa: ['Tampa-St. Petersburg-Clearwater, FL','Sarasota-Bradenton, FL','Fort Myers-Cape Coral, FL','Punta Gorda, FL'],
  SFL: ['Miami, FL','Fort Lauderdale-Hollywood, FL','West Palm Beach-Boca Raton, FL','Naples, FL','Fort Pierce-Port St. Lucie, FL'],
  Misc: [],
}

export function getRegion(market: string): Region {
  for (const [region, markets] of Object.entries(REGION_MAP)) {
    if ((markets as string[]).includes(market)) return region as Region
  }
  return 'Misc'
}

export const REGION_LABELS: Record<Region, string> = {
  DC: 'DC MSA', NC: 'N. Carolina', SC: 'S. Carolina', GA: 'Georgia',
  TX: 'Texas', Nashville: 'Nashville', Orlando: 'Orlando', Tampa: 'Tampa',
  SFL: 'S. Florida', Misc: 'Misc',
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
