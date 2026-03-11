'use client'
import { useMemo, useState, useEffect } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, statusLabel, formatBidDate, bidDateClass, getRegion, REGION_LABELS } from '@/lib/utils'
import dynamic from 'next/dynamic'
const DealsMap = dynamic(() => import('./DealsMap'), { ssr: false })

interface Props {
  deals: Deal[]
  capRateMap: Record<string, CapRate>
  boeMap: Record<string, BoeData>
  onOpenDeal: (d: Deal) => void
}

const REGION_COLORS: Record<string, string> = {
  'Mid-Atlantic': '#C9A84C', 'Carolinas': '#2E6B9E', 'Georgia': '#2E7D50',
  'Texas': '#8B4513', 'Tennessee': '#6B3FA0', 'Florida': '#1E7A6E', 'Misc': '#8A9BB0'
}

const BROKER_COLORS = ['#C9A84C','#2E6B9E','#2E7D50','#6B3FA0','#1E7A6E','#8B4513','#C0392B','#2C8C8C','#8A4BAF','#5D6D7E']

// Short display names for long market strings
const MARKET_SHORT: Record<string, string> = {
  'Washington, DC-MD-VA': 'Washington DC',
  'Baltimore, MD': 'Baltimore',
  'Richmond-Petersburg, VA': 'Richmond',
  'Charlottesville, VA': 'Charlottesville',
  'Norfolk-Virginia Beach-Newport News, VA-NC': 'Virginia Beach',
  'Raleigh-Durham-Chapel Hill, NC': 'Raleigh/Durham',
  'Charlotte-Gastonia-Rock Hill, NC-SC': 'Charlotte',
  'Greensboro--Winston-Salem--High Point, NC': 'Greensboro',
  'Wilmington, NC': 'Wilmington NC',
  'Charleston-North Charleston, SC': 'Charleston SC',
  'Greenville-Spartanburg-Anderson, SC': 'Greenville SC',
  'Atlanta, GA': 'Atlanta',
  'Savannah, GA': 'Savannah',
  'Dallas-Fort Worth, TX': 'Dallas/Fort Worth',
  'Houston, TX': 'Houston',
  'Austin-San Marcos, TX': 'Austin',
  'San Antonio, TX': 'San Antonio',
  'Nashville, TN': 'Nashville',
  'Orlando, FL': 'Orlando',
  'Tampa-St. Petersburg-Clearwater, FL': 'Tampa',
  'Fort Myers-Cape Coral, FL': 'Fort Myers',
  'Sarasota-Bradenton, FL': 'Sarasota',
  'Naples, FL': 'Naples',
  'Miami-Fort Lauderdale, FL': 'South Florida',
  'Jacksonville, FL': 'Jacksonville',
}

function shortMarket(m: string) { return MARKET_SHORT[m] || m.split(',')[0].replace(/--/g, '/') }

function BrokerLeaderboard({ deals }: { deals: Deal[] }) {
  // Filter to 2026 only
  const deals2026 = useMemo(() => deals.filter(d => {
    if (!d.added) return false
    const y = typeof d.added === 'string' ? d.added : String(d.added)
    return y.includes('2026')
  }), [deals])

  // Build market list sorted by 2026 deal count
  const marketList = useMemo(() => {
    const counts: Record<string, number> = {}
    deals2026.forEach(d => { if (d.broker && d.market) counts[d.market] = (counts[d.market] || 0) + 1 })
    return [
      { market: 'All Markets', count: deals2026.filter(d => d.broker).length },
      ...Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([market, count]) => ({ market, count }))
    ]
  }, [deals2026])

  const [selectedMarket, setSelectedMarket] = useState<string>('All Markets')

  const brokerRanking = useMemo(() => {
    const filtered = selectedMarket === 'All Markets'
      ? deals2026
      : deals2026.filter(d => d.market === selectedMarket)
    const counts: Record<string, number> = {}
    filtered.forEach(d => { if (d.broker) counts[d.broker.trim()] = (counts[d.broker.trim()] || 0) + 1 })
    return Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .map(([name, count], i) => ({ name, count, color: BROKER_COLORS[i % BROKER_COLORS.length] }))
  }, [deals2026, selectedMarket])

  const maxCount = brokerRanking[0]?.count || 1
  const totalInView = brokerRanking.reduce((s, b) => s + b.count, 0)

  return (
    <div style={{ background: '#0D1B2E', borderRadius: 12, border: '1px solid rgba(201,168,76,0.15)', overflow: 'hidden', marginBottom: 16, display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div style={{ padding: '14px 20px', borderBottom: '1px solid rgba(201,168,76,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={{ fontSize: 9, fontWeight: 700, color: 'rgba(201,168,76,0.55)', letterSpacing: '0.2em', textTransform: 'uppercase' as const }}>Intelligence · 2026 YTD</div>
          <div style={{ fontSize: 15, fontWeight: 700, color: '#F5F4EF', fontFamily: "'Cormorant Garamond',serif", marginTop: 2 }}>Broker Activity by Market</div>
        </div>
        <div style={{ fontSize: 11, color: 'rgba(245,244,239,0.3)' }}>{deals2026.filter(d=>d.broker).length} deals tracked</div>
      </div>

      <div style={{ display: 'flex' }}>
        {/* Market sidebar */}
        <div style={{ width: 230, borderRight: '1px solid rgba(201,168,76,0.1)', overflowY: 'auto' as const, maxHeight: 460, flexShrink: 0 }}>
          {marketList.map(({ market, count }) => {
            const isSelected = selectedMarket === market
            const isAll = market === 'All Markets'
            return (
              <button
                key={market}
                onClick={() => setSelectedMarket(market)}
                style={{
                  width: '100%', textAlign: 'left' as const, padding: '9px 14px',
                  background: isSelected ? 'rgba(201,168,76,0.1)' : 'transparent',
                  borderLeft: `3px solid ${isSelected ? '#C9A84C' : 'transparent'}`,
                  border: 'none', borderBottom: '1px solid rgba(255,255,255,0.04)',
                  cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center'
                }}
                onMouseEnter={e => { if (!isSelected) e.currentTarget.style.background = 'rgba(255,255,255,0.04)' }}
                onMouseLeave={e => { if (!isSelected) e.currentTarget.style.background = 'transparent' }}
              >
                <span style={{ fontSize: 11, fontWeight: isSelected ? 700 : 400, color: isSelected ? '#C9A84C' : '#F5F4EF', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const, maxWidth: 160 }}>
                  {isAll ? 'All Markets' : shortMarket(market)}
                </span>
                <span style={{ fontSize: 12, fontWeight: 700, color: isSelected ? '#C9A84C' : 'rgba(245,244,239,0.3)', fontFamily: "'DM Mono',monospace", flexShrink: 0, marginLeft: 6 }}>{count}</span>
              </button>
            )
          })}
        </div>

        {/* Rankings */}
        <div style={{ flex: 1, overflow: 'hidden' }}>
          {/* Panel subheader */}
          <div style={{ padding: '10px 18px', borderBottom: '1px solid rgba(201,168,76,0.08)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontSize: 12, fontWeight: 700, color: '#F5F4EF', fontFamily: "'Cormorant Garamond',serif" }}>
              {selectedMarket === 'All Markets' ? 'All Markets' : shortMarket(selectedMarket)}
            </div>
            <div style={{ fontSize: 9, color: 'rgba(245,244,239,0.3)', letterSpacing: '0.05em' }}>{brokerRanking.length} brokers · {totalInView} deals</div>
          </div>

          {/* Column headers */}
          <div style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr 44px 44px', gap: 0, padding: '6px 18px', borderBottom: '1px solid rgba(201,168,76,0.06)' }}>
            {['#', 'Broker', 'Share', 'Deals', '%'].map(h => (
              <div key={h} style={{ fontSize: 8, fontWeight: 700, color: 'rgba(201,168,76,0.4)', letterSpacing: '0.15em', textTransform: 'uppercase' as const, textAlign: h === '#' || h === 'Deals' || h === '%' ? 'center' as const : 'left' as const }}>{h}</div>
            ))}
          </div>

          <div style={{ overflowY: 'auto' as const, maxHeight: 394 }}>
            {brokerRanking.length === 0 ? (
              <div style={{ padding: '32px 18px', color: 'rgba(255,255,255,0.25)', fontSize: 12, textAlign: 'center' as const }}>No 2026 deals for this market</div>
            ) : brokerRanking.map((broker, idx) => {
              const barPct = (broker.count / maxCount) * 100
              const sharePct = ((broker.count / totalInView) * 100).toFixed(0)
              const medal = idx === 0 ? '🥇' : idx === 1 ? '🥈' : idx === 2 ? '🥉' : null
              return (
                <div key={broker.name}
                  style={{ display: 'grid', gridTemplateColumns: '28px 1fr 1fr 44px 44px', alignItems: 'center', gap: 0, padding: '10px 18px', borderBottom: '1px solid rgba(255,255,255,0.03)' }}
                  onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.02)')}
                  onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                >
                  {/* Rank */}
                  <div style={{ fontSize: medal ? 13 : 10, fontWeight: 700, color: 'rgba(245,244,239,0.25)', textAlign: 'center' as const }}>{medal || `${idx+1}`}</div>

                  {/* Name */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, paddingRight: 8, minWidth: 0 }}>
                    <div style={{ width: 6, height: 6, borderRadius: 2, background: broker.color, flexShrink: 0 }} />
                    <span style={{ fontSize: 12, fontWeight: 600, color: '#F5F4EF', whiteSpace: 'nowrap' as const, overflow: 'hidden', textOverflow: 'ellipsis' }}>{broker.name}</span>
                  </div>

                  {/* Bar */}
                  <div style={{ paddingRight: 12 }}>
                    <div style={{ height: 6, background: 'rgba(255,255,255,0.06)', borderRadius: 3, overflow: 'hidden' }}>
                      <div style={{ height: '100%', width: `${barPct}%`, background: broker.color, borderRadius: 3, opacity: 0.8 }} />
                    </div>
                  </div>

                  {/* Count */}
                  <div style={{ fontSize: 14, fontWeight: 700, color: '#C9A84C', fontFamily: "'DM Mono',monospace", textAlign: 'center' as const }}>{broker.count}</div>

                  {/* Share % */}
                  <div style={{ fontSize: 10, color: 'rgba(245,244,239,0.3)', fontFamily: "'DM Mono',monospace", textAlign: 'center' as const }}>{sharePct}%</div>
                </div>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}



function RateRow({ label, value, change, loading }: { label: string; value: string; change?: string; loading?: boolean }) {
  const up = change ? !change.startsWith('-') : null
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '9px 0', borderBottom: '1px solid rgba(201,168,76,0.08)' }}>
      <div style={{ fontSize: 11, color: 'rgba(245,244,239,0.5)', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
        {change && up !== null && <span style={{ fontSize: 10, color: up ? '#2E7D50' : '#C0392B', fontWeight: 600 }}>{change}</span>}
        <span style={{ fontSize: 13, fontWeight: 700, color: '#C9A84C', fontFamily: "'DM Mono',monospace" }}>{loading ? '—' : value}</span>
      </div>
    </div>
  )
}

function TickerRow({ label, value, change, pct, loading }: { label: string; value: string; change: string; pct: string; loading?: boolean }) {
  const up = !change.startsWith('-')
  const color = loading ? '#8A9BB0' : up ? '#2E7D50' : '#C0392B'
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '60px 1fr auto auto', alignItems: 'center', padding: '9px 0', borderBottom: '1px solid rgba(201,168,76,0.08)', gap: 8 }}>
      <div style={{ fontSize: 11, fontWeight: 700, color: '#C9A84C', letterSpacing: '0.06em' }}>{label}</div>
      <div />
      <div style={{ fontSize: 12, fontWeight: 700, color: '#F5F4EF', fontFamily: "'DM Mono',monospace" }}>{loading ? '—' : value}</div>
      <div style={{ fontSize: 10, fontWeight: 600, color, minWidth: 90, textAlign: 'right' }}>{loading ? '—' : `${change} (${pct})`}</div>
    </div>
  )
}

function DonutChart({ data }: { data: { label: string; value: number; color: string }[] }) {
  const [hoveredIdx, setHoveredIdx] = useState<number | null>(null)
  const total = data.reduce((s, d) => s + d.value, 0)
  if (total === 0) return null

  let cum = 0
  const r = 56, cx = 74, cy = 74
  const slices = data.map((d, i) => {
    const pct = d.value / total, start = cum; cum += pct
    const sa = start * 2 * Math.PI - Math.PI / 2
    const ea = cum * 2 * Math.PI - Math.PI / 2
    const ma = (sa + ea) / 2
    const sw = hoveredIdx === i ? 26 : 20
    return {
      ...d, i, pct, sw,
      path: `M ${cx + r * Math.cos(sa)} ${cy + r * Math.sin(sa)} A ${r} ${r} 0 ${pct > 0.5 ? 1 : 0} 1 ${cx + r * Math.cos(ea)} ${cy + r * Math.sin(ea)}`,
      tx: cx + r * Math.cos(ma), ty: cy + r * Math.sin(ma)
    }
  })

  const hovered = hoveredIdx !== null ? slices[hoveredIdx] : null

  return (
    <svg width={148} height={148} style={{ overflow: 'visible' }}>
      {slices.map((s) => (
        <path key={s.i} d={s.path} fill="none" stroke={s.color} strokeWidth={s.sw}
          style={{ cursor: 'pointer' }}
          onMouseEnter={() => setHoveredIdx(s.i)}
          onMouseLeave={() => setHoveredIdx(null)} />
      ))}
      <text x={cx} y={cy - 4} textAnchor="middle" style={{ fontSize: 20, fontWeight: 700, fill: '#0D1B2E', fontFamily: "'Cormorant Garamond',serif" }}>{total}</text>
      <text x={cx} y={cy + 12} textAnchor="middle" style={{ fontSize: 8, fill: '#8A9BB0', letterSpacing: '0.1em' }}>DEALS</text>
      {hovered && (
        <g style={{ pointerEvents: 'none' }}>
          <rect x={hovered.tx - 38} y={hovered.ty - 22} width={76} height={34} rx={4} fill="rgba(13,27,46,0.95)" />
          <text x={hovered.tx} y={hovered.ty - 5} textAnchor="middle" style={{ fontSize: 14, fontWeight: 700, fill: '#fff', fontFamily: "'Cormorant Garamond',serif" }}>{hovered.value}</text>
          <text x={hovered.tx} y={hovered.ty + 9} textAnchor="middle" style={{ fontSize: 8, fill: '#C9A84C', letterSpacing: '0.06em' }}>{hovered.label.toUpperCase()}</text>
        </g>
      )}
    </svg>
  )
}

export default function DashboardPage({ deals, capRateMap, boeMap, onOpenDeal }: Props) {
  const now = new Date()
  const [rates, setRates] = useState<any>(null)
  const [ratesLoading, setRatesLoading] = useState(true)
  const [news, setNews] = useState<{ title: string; url: string; date: string; summary: string }[]>([])
  const [newsLoading, setNewsLoading] = useState(true)

  useEffect(() => {
    async function loadRates() {
      try {
        const res = await fetch('/api/rates')
        if (!res.ok) throw new Error(`${res.status}`)
        const d = await res.json()
        if (!d.error) setRates(d)
      } catch (e) {
        console.warn('Rates fetch failed:', e)
      }
      setRatesLoading(false)
    }
    loadRates()
  }, [])

  useEffect(() => {
    fetch('/api/mhn-news').then(r => r.json()).then(d => { setNews(d); setNewsLoading(false) }).catch(() => setNewsLoading(false))
  }, [])

  const active = deals.filter(d => d.status.includes('2 -'))
  const newDeals = deals.filter(d => d.status.includes('1 -'))
  const owned = deals.filter(d => d.status.includes('10 -'))
  const passed = deals.filter(d => d.status.includes('6 -') || d.status.includes('7 -'))

  const totalGuidance = useMemo(() => [...newDeals, ...active].filter(d => d.purchase_price).reduce((s, d) => s + d.purchase_price!, 0), [newDeals, active])
  const avgCapRate = useMemo(() => { const crs = Object.values(capRateMap).filter(c => c.noi_cap_rate).map(c => Number(c.noi_cap_rate)); return crs.length ? crs.reduce((s, v) => s + v, 0) / crs.length : 0 }, [capRateMap])

  const upcomingBids = [...newDeals, ...active].filter(d => d.bid_due_date && d.bid_due_date >= now.toISOString().split('T')[0]).sort((a, b) => a.bid_due_date!.localeCompare(b.bid_due_date!)).slice(0, 6)
  const marketData = useMemo(() => {
    const counts: Record<string, number> = {}
    deals.filter(d => d.added && new Date(d.added).getFullYear() === 2026).forEach(d => {
      const label = (REGION_LABELS as any)[getRegion(d.market || '')] || 'Other'
      counts[label] = (counts[label] || 0) + 1
    })
    return Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([label, value]) => ({ label, value, color: REGION_COLORS[label] || '#8A9BB0' }))
  }, [deals])
  const statusCounts = deals.reduce((acc: Record<string, number>, d) => { acc[d.status] = (acc[d.status] || 0) + 1; return acc }, {})

  const fmtBig = (n: number) => n >= 1e9 ? `$${(n/1e9).toFixed(1)}B` : n >= 1e6 ? `$${(n/1e6).toFixed(1)}M` : '—'
  const fmtR = (v: any, d = 2) => v != null ? `${Number(v).toFixed(d)}%` : '—'
  const fmtDelta = (v: any) => v != null ? `${Number(v) >= 0 ? '+' : ''}${Number(v).toFixed(2)}` : '—'
  const fmtPct = (v: any) => v != null ? `${Number(v) >= 0 ? '+' : ''}${Number(v).toFixed(2)}%` : '—'
  const fmtPrice = (v: any, decimals = 2) => v != null ? Number(v).toLocaleString('en-US', { minimumFractionDigits: decimals, maximumFractionDigits: decimals }) : '—'

  const card = { background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden' as const }
  const dark = { background: '#0D1B2E', borderRadius: 12, border: '1px solid rgba(201,168,76,0.15)', overflow: 'hidden' as const }
  const secLabel: React.CSSProperties = { fontSize: 9, fontWeight: 700, color: '#C9A84C', letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 10 }

  return (
    <div style={{ padding: '24px 28px', background: '#EEEDE7', minHeight: '100%' }}>

      {/* KPI Strip */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5,1fr)', gap: 12, marginBottom: 20 }}>
        {[
          { label: 'Active Pipeline', value: `${newDeals.length + active.length}`, sub: `${newDeals.length} new · ${active.length} active`, accent: '#C9A84C' },
          { label: 'Pipeline Guidance', value: fmtBig(totalGuidance), sub: 'active + new deals', accent: '#2E6B9E' },
          { label: 'Portfolio', value: owned.length.toString(), sub: 'owned properties', accent: '#2E7D50' },
          { label: 'Avg BOE Cap Rate', value: avgCapRate ? `${avgCapRate.toFixed(2)}%` : '—', sub: 'underwritten deals', accent: '#6B3FA0' },
          { label: 'Not Pursued', value: passed.length.toString(), sub: 'passed or lost', accent: '#8A9BB0' },
        ].map(s => (
          <div key={s.label} style={{ ...card, padding: '18px 20px', borderTop: `3px solid ${s.accent}` }}>
            <div style={{ fontSize: 10, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 5 }}>{s.label}</div>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 28, fontWeight: 700, color: '#0D1B2E', lineHeight: 1 }}>{s.value}</div>
            <div style={{ fontSize: 11, color: '#8A9BB0', marginTop: 4 }}>{s.sub}</div>
          </div>
        ))}
      </div>

      {/* Main Row */}
      <div style={{ display: 'grid', gridTemplateColumns: '320px 1fr', gap: 16, marginBottom: 16 }}>

        {/* Market Intelligence */}
        <div style={{ ...dark, display: 'flex', flexDirection: 'column' }}>
          <div style={{ padding: '14px 18px', borderBottom: '1px solid rgba(201,168,76,0.1)' }}>
            <div style={{ fontSize: 9, fontWeight: 700, color: 'rgba(201,168,76,0.55)', letterSpacing: '0.2em', textTransform: 'uppercase' as const, marginBottom: 1 }}>Market Intelligence</div>
            <div style={{ fontSize: 10, color: 'rgba(245,244,239,0.3)' }}>
              {now.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })} · Live Data
            </div>
          </div>
          <div style={{ padding: '12px 18px', borderBottom: '1px solid rgba(201,168,76,0.08)' }}>
            <div style={secLabel}>Reference Rates</div>
            <RateRow label="SOFR" value={fmtR(rates?.sofr?.rate)} change={fmtDelta(rates?.sofr?.change)} loading={ratesLoading} />
            <RateRow label="5Y Treasury" value={fmtR(rates?.fiveY?.rate)} change={fmtDelta(rates?.fiveY?.change)} loading={ratesLoading} />
            <RateRow label="7Y Treasury" value={fmtR(rates?.sevenY?.rate)} loading={ratesLoading} />
            <RateRow label="10Y Treasury" value={fmtR(rates?.tenY?.rate)} change={fmtDelta(rates?.tenY?.change)} loading={ratesLoading} />
          </div>
          <div style={{ padding: '12px 18px', borderBottom: '1px solid rgba(201,168,76,0.08)' }}>
            <div style={secLabel}>Equity Markets</div>
            <TickerRow label="S&P 500" value={fmtPrice(rates?.sp500?.price)} change={fmtDelta(rates?.sp500?.change)} pct={fmtPct(rates?.sp500?.pct)} loading={ratesLoading} />
            <TickerRow label="DOW" value={fmtPrice(rates?.dow?.price, 0)} change={fmtDelta(rates?.dow?.change)} pct={fmtPct(rates?.dow?.pct)} loading={ratesLoading} />
            <TickerRow label="BTC" value={rates?.btc?.price != null ? `$${Number(rates.btc.price).toLocaleString('en-US', { maximumFractionDigits: 0 })}` : '—'} change={fmtDelta(rates?.btc?.change)} pct={fmtPct(rates?.btc?.pct)} loading={ratesLoading} />
          </div>
          <div style={{ padding: '12px 18px' }}>
            <div style={secLabel}>Multifamily REITs</div>
            {['avb','eqr','maa','ess'].map(t => (
              <TickerRow key={t} label={t.toUpperCase()} value={rates?.[t]?.price != null ? `$${Number(rates[t].price).toFixed(2)}` : '—'} change={fmtDelta(rates?.[t]?.change)} pct={fmtPct(rates?.[t]?.pct)} loading={ratesLoading} />
            ))}
          </div>
        </div>

        {/* Right side */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

          {/* Donut + Bids */}
          <div style={{ display: 'grid', gridTemplateColumns: '210px 1fr', gap: 16 }}>
            <div style={{ ...card, padding: '16px 18px' }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 8 }}>2026 by Market</div>
              <div style={{ display: 'flex', justifyContent: 'center' }}><DonutChart data={marketData} /></div>
              <div style={{ marginTop: 6 }}>
                {marketData.slice(0, 5).map(d => (
                  <div key={d.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '2px 0', alignItems: 'center' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                      <div style={{ width: 6, height: 6, borderRadius: 2, background: d.color, flexShrink: 0 }} />
                      <span style={{ fontSize: 10, color: '#8A9BB0' }}>{d.label}</span>
                    </div>
                    <span style={{ fontSize: 10, fontWeight: 700, color: '#0D1B2E' }}>{d.value}</span>
                  </div>
                ))}
              </div>
            </div>

            <div style={card}>
              <div style={{ padding: '14px 18px', borderBottom: '1px solid rgba(13,27,46,0.06)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 15, fontWeight: 700, color: '#0D1B2E' }}>Upcoming Bids</div>
                <div style={{ fontSize: 10, color: '#8A9BB0' }}>{upcomingBids.length} deals</div>
              </div>
              {upcomingBids.length === 0 ? (
                <div style={{ padding: 20, color: '#8A9BB0', fontSize: 12 }}>No upcoming bids</div>
              ) : upcomingBids.map((deal, i) => (
                <div key={deal.id} onClick={() => onOpenDeal(deal)}
                  style={{ display: 'grid', gridTemplateColumns: '1fr auto auto', gap: 12, padding: '10px 18px', borderBottom: i < upcomingBids.length - 1 ? '1px solid rgba(13,27,46,0.05)' : 'none', cursor: 'pointer', alignItems: 'center' }}
                  onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.04)')}
                  onMouseLeave={e => (e.currentTarget.style.background = '')}>
                  <div>
                    <div style={{ fontSize: 12, fontWeight: 600, color: '#0D1B2E' }}>{deal.name}</div>
                    <div style={{ fontSize: 10, color: '#8A9BB0', marginTop: 1 }}>{deal.market}</div>
                  </div>
                  <div style={{ fontSize: 11, color: '#8A9BB0' }}>{fmtShort(deal.purchase_price)}</div>
                  <div style={{ fontSize: 11, fontWeight: 600, minWidth: 110, textAlign: 'right' }} className={bidDateClass(deal.bid_due_date)}>{formatBidDate(deal.bid_due_date)}</div>
                </div>
              ))}
            </div>
          </div>

          {/* MHN News Feed */}
          <div style={dark}>
            <div style={{ padding: '14px 18px', borderBottom: '1px solid rgba(201,168,76,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: 9, fontWeight: 700, color: 'rgba(201,168,76,0.55)', letterSpacing: '0.2em', textTransform: 'uppercase' as const }}>Intelligence Feed</div>
                <div style={{ fontSize: 13, fontWeight: 600, color: '#F5F4EF', marginTop: 2 }}>Multifamily Housing News</div>
              </div>
              <a href="https://www.multihousingnews.com" target="_blank" rel="noopener noreferrer"
                style={{ fontSize: 9, color: '#C9A84C', textDecoration: 'none', border: '1px solid rgba(201,168,76,0.25)', borderRadius: 4, padding: '4px 10px', letterSpacing: '0.08em' }}>
                MHN ↗
              </a>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)' }}>
              {newsLoading ? [1,2,3].map(i => (
                <div key={i} style={{ padding: '16px 18px', borderRight: i < 3 ? '1px solid rgba(201,168,76,0.07)' : 'none' }}>
                  {[60,100,80].map((w, j) => <div key={j} style={{ height: 8, background: 'rgba(255,255,255,0.05)', borderRadius: 3, marginBottom: 8, width: `${w}%` }} />)}
                </div>
              )) : news.length === 0 ? (
                <div style={{ padding: 20, color: 'rgba(255,255,255,0.3)', fontSize: 12, gridColumn: '1/-1' }}>Unable to load news</div>
              ) : news.slice(0, 3).map((item, i) => (
                <a key={i} href={item.url} target="_blank" rel="noopener noreferrer"
                  style={{ padding: '16px 18px', borderRight: i < 2 ? '1px solid rgba(201,168,76,0.07)' : 'none', textDecoration: 'none', display: 'block', transition: 'background 0.15s' }}
                  onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.05)')}
                  onMouseLeave={e => (e.currentTarget.style.background = '')}>
                  <div style={{ fontSize: 9, color: 'rgba(201,168,76,0.5)', letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 6 }}>{item.date}</div>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#F5F4EF', lineHeight: 1.45, marginBottom: 8, fontFamily: "'Cormorant Garamond',serif" }}>{item.title}</div>
                  <div style={{ fontSize: 11, color: 'rgba(245,244,239,0.4)', lineHeight: 1.55 }}>{item.summary}</div>
                  <div style={{ marginTop: 10, fontSize: 9, color: '#C9A84C', letterSpacing: '0.08em', textTransform: 'uppercase' as const }}>Read Full Article ↗</div>
                </a>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Deal Map */}
      <div style={{ ...card, height: 400, marginBottom: 16, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '12px 18px', borderBottom: '1px solid rgba(13,27,46,0.07)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 15, fontWeight: 700, color: '#0D1B2E' }}>Deal Activity Map</div>
          <div style={{ fontSize: 10, color: '#8A9BB0' }}>{deals.length} deals tracked</div>
        </div>
        <div style={{ flex: 1, overflow: 'hidden' }}><DealsMap deals={deals} onOpenDeal={onOpenDeal} /></div>
      </div>

      {/* Broker Leaderboard */}
      <BrokerLeaderboard deals={deals} />

      {/* Status Breakdown */}
      <div style={{ ...card, padding: '16px 20px' }}>
        <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 15, fontWeight: 700, color: '#0D1B2E', marginBottom: 12 }}>Pipeline by Status</div>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' as const }}>
          {Object.entries(statusCounts).sort((a, b) => b[1] - a[1]).map(([status, count]) => (
            <div key={status} style={{ background: 'rgba(13,27,46,0.03)', borderRadius: 8, padding: '10px 16px', textAlign: 'center' as const, border: '1px solid rgba(13,27,46,0.06)' }}>
              <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 22, fontWeight: 700, color: '#0D1B2E' }}>{count}</div>
              <div style={{ fontSize: 9, color: '#8A9BB0', marginTop: 2, letterSpacing: '0.08em', textTransform: 'uppercase' as const }}>{statusLabel(status)}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
