// ── Deal ──────────────────────────────────────────────
export interface Deal {
  id: string
  name: string
  status: string
  market: string
  units: number | null
  year_built: number | null
  price_per_unit: number | null
  purchase_price: number | null
  bid_due_date: string | null
  added: string
  modified: string
  comments: string | null
  flagged: boolean
  hot: boolean
  broker: string | null
  address: string | null
  buyer: string | null
  seller: string | null
  sold_price: number | null
  created_at?: string
  updated_at?: string
}

// ── BOE ───────────────────────────────────────────────
export interface BoeT12 {
  gpr: number; ltl: number; vac: number; bad: number
  conc: number; mod: number; emp: number; oi: number
  ga: number; mkt: number; rm: number; pay: number
  mgt: number; utl: number; tax: number; taxm: number
  ins: number
}

export interface BoeAdjs {
  gpr?: string; ltl?: string; vac?: string; bad?: string
  conc?: string; mod?: string; emp?: string; oi?: string
  ga?: string; mkt?: string; rm?: string; pay?: string
  mgt?: string; utl?: string; tax?: string; taxm?: string
  ins?: string
}

export type BoePayroll = Record<string, string>

export interface BoeData {
  id?: string
  deal_name: string
  t12: BoeT12
  adjs: BoeAdjs
  notes: Record<string, string>
  payroll: BoePayroll
  rmi: { 'rmi-rm'?: string; 'rmi-ct'?: string; 'rmi-tu'?: string }
  tax_helper: { 'tx-mil'?: string; 'tx-rat'?: string; 'tx-nad'?: string }
  period: string
  pf_noi_override?: number | null
  noi_badge?: string
  updated_at?: string
}

// ── Cap Rate ──────────────────────────────────────────
export interface CapRate {
  id?: string
  deal_name: string
  broker_cap_rate: number | null
  noi_cap_rate: number | null
  purchase_price: number | null
  sold_price: number | null
  delta: number | null
  updated_at?: string
}

// ── Auth ──────────────────────────────────────────────
export interface UserProfile {
  id: string
  email: string
  full_name: string | null
  role: 'admin' | 'analyst' | 'viewer'
}

// ── Computed / UI helpers ─────────────────────────────
export type StatusKey = '1 - New' | '2 - Active' | '5 - Dormant' | '6 - Passed' | '7 - Lost' | '9 - Exited' | '10 - Owned Property' | '11 - Property Comp'

export type Region = 'DC' | 'Carolinas' | 'GA' | 'TX' | 'TN' | 'FL' | 'Misc'

export type SortOrder =
  | 'modified-desc'
  | 'biddate-asc'
  | 'price-desc'
  | 'price-asc'
  | 'units-desc'
  | 'name-asc'
  | 'location-asc'
  | 'status'
