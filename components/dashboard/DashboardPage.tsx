'use client'
import { useMemo, useState, useEffect } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, statusClass, statusLabel, formatBidDate, bidDateClass, getRegion, REGION_LABELS } from '@/lib/utils'
import dynamic from 'next/dynamic'
const DealsMap = dynamic(() => import('./DealsMap'), { ssr: false })

interface Props {
  deals: Deal[]
  capRateMap: Record<string, CapRate>
  boeMap: Record<string, BoeData>
  onOpenDeal: (d: Deal) => void
}

const MARKET_COLORS: Record<string, string> = {
  'Georgia': '#C84B31', 'N. Carolina': '#2E7D50', 'Orlando': '#E67E22',
  'DC MSA': '#1565A0', 'Texas': '#6B3FA0', 'S. Florida': '#C0922A',
  'Nashville': '#2C8C8C', 'Tampa': '#2E5BAD', 'Other': '#8A9BB0', 'S. Carolina': '#B85C8A'
}

function DonutChart({ data }: { data: { label: string; value: number; color: string }[] }) {
  const [tooltip, setTooltip] = useState<{ label: string; value: number; x: number; y: number } | null>(null)
  const total = data.reduce((s, d) => s + d.value, 0)
  if (total === 0) return null
  let cumulative = 0
  const r = 60, cx = 80, cy = 80, stroke = 22
  const slices = data.map(d => {
    const pct = d.value / total
    const start = cumulative
    cumulative += pct
    const startAngle = start * 2 * Math.PI - Math.PI / 2
    const endAngle = cumulative * 2 * Math.PI - Math.PI / 2
    const midAngle = (startAngle + endAngle) / 2
    const x1 = cx + r * Math.cos(startAngle)
    const y1 = cy + r * Math.sin(startAngle)
    const x2 = cx + r * Math.cos(endAngle)
    const y2 = cy + r * Math.sin(endAngle)
    const large = pct > 0.5 ? 1 : 0
    const tx = cx + r * Math.cos(midAngle)
    const ty = cy + r * Math.sin(midAngle)
    return { ...d, path: `M ${x1} ${y1} A ${r} ${r} 0 ${large} 1 ${x2} ${y2}`, pct, tx, ty }
  })
  return (
    <div style={{ position: 'relative' }}>
      <svg width={160} height={160} viewBox="0 0 160 160">
        {slices.map((s, i) => (
          <path key={i} d={s.path} fill="none" stroke={s.color} strokeWidth={stroke} strokeLinecap="butt"
            style={{ cursor: 'pointer', transition: 'stroke-width 0.15s' }}
            onMouseEnter={e => {
              const rect = (e.target as SVGElement).closest('svg')!.getBoundingClientRect()
              setTooltip({ label: s.label, value: s.value, x: s.tx, y: s.ty })
              ;(e.target as SVGPathElement).setAttribute('stroke-width', '28')
            }}
            onMouseLeave={e => {
              setTooltip(null)
              ;(e.target as SVGPathElement).setAttribute('stroke-width', String(stroke))
            }}
          />
        ))}
        <text x={cx} y={cy - 6} textAnchor="middle" style={{ fontSize: 18, fontWeight: 700, fill: '#0D1B2E', fontFamily: "'Cormorant Garamond',serif" }}>{total}</text>
        <text x={cx} y={cy + 10} textAnchor="middle" style={{ fontSize: 9, fill: '#8A9BB0', letterSpacing: '0.08em' }}>DEALS IN 2026</text>
        {tooltip && (
          <g>
            <rect x={tooltip.x - 36} y={tooltip.y - 22} width={72} height={36} rx={4} fill="rgba(13,27,46,0.92)" />
            <text x={tooltip.x} y={tooltip.y - 6} textAnchor="middle" style={{ fontSize: 13, fontWeight: 700, fill: '#fff', fontFamily: "'Cormorant Garamond',serif" }}>{tooltip.value}</text>
            <text x={tooltip.x} y={tooltip.y + 9} textAnchor="middle" style={{ fontSize: 8, fill: '#C9A84C', letterSpacing: '0.05em' }}>{tooltip.label.toUpperCase()}</text>
          </g>
        )}
      </svg>
    </div>
  )
}

function BarChart({ data }: { data: { label: string; value: number; current?: boolean }[] }) {
  const [hovered, setHovered] = useState<number | null>(null)
  const max = Math.max(...data.map(d => d.value), 1)
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 120, paddingBottom: 24, position: 'relative' }}>
      {data.map((d, i) => (
        <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, position: 'relative' }}
          onMouseEnter={() => setHovered(i)} onMouseLeave={() => setHovered(null)}>
          {hovered === i && (
            <div style={{ position: 'absolute', bottom: '100%', left: '50%', transform: 'translateX(-50%)', marginBottom: 4, background: 'rgba(13,27,46,0.92)', color: '#fff', borderRadius: 4, padding: '3px 8px', fontSize: 11, fontWeight: 700, whiteSpace: 'nowrap', pointerEvents: 'none', zIndex: 10 }}>
              {d.value} deals
            </div>
          )}
          <div style={{
            width: '100%', height: Math.max((d.value / max) * 80, 2),
            background: d.current ? '#C9A84C' : hovered === i ? '#1565A0' : '#0D1B2E',
            borderRadius: '3px 3px 0 0',
            opacity: d.current ? 1 : hovered === i ? 1 : 0.65,
            transition: 'all 0.15s ease', cursor: 'pointer'
          }} />
          <div style={{ fontSize: 9, color: '#8A9BB0', whiteSpace: 'nowrap', transform: 'rotate(-30deg)', transformOrigin: 'top center', marginTop: 4 }}>{d.label}</div>
        </div>
      ))}
    </div>
  )
}


function RatesWidget() {
  const [rates, setRates] = useState<Record<string, { rate: number | null; change: number | null }>>({})
  const [lastUpdated, setLastUpdated] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  const RATES = [
    { key: 'SOFR',  label: 'SOFR',    seriesId: 'SOFR'   },
    { key: 'DGS5',  label: '5Y UST',  seriesId: 'DGS5'   },
    { key: 'DGS7',  label: '7Y UST',  seriesId: 'DGS7'   },
    { key: 'DGS10', label: '10Y UST', seriesId: 'DGS10'  },
  ]

  async function fetchRates() {
    try {
      const res = await fetch('/api/rates')
      const data = await res.json()
      if (data.rates) {
        const results: Record<string, { rate: number | null; change: number | null }> = {}
        for (const r of data.rates) results[r.key] = { rate: r.rate, change: r.change }
        setRates(results)
        setLastUpdated(new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }))
      }
    } catch (e) {
      console.error('Rates fetch error:', e)
    } finally {
      setLoading(false)
    }
  }

  // Fetch on mount, refresh every 60 minutes
  useEffect(() => { fetchRates(); const t = setInterval(fetchRates, 60 * 60 * 1000); return () => clearInterval(t) }, [])
  
  return (
    <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', padding: '18px 22px', marginBottom: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
        <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E' }}>Market Rates</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {lastUpdated && <div style={{ fontSize: 10, color: '#8A9BB0' }}>Updated {lastUpdated}</div>}
          <button onClick={fetchRates} style={{ background: 'none', border: '1px solid rgba(13,27,46,0.1)', borderRadius: 6, padding: '3px 10px', fontSize: 10, color: '#8A9BB0', cursor: 'pointer', fontFamily: "'DM Sans',sans-serif" }}>↻ Refresh</button>
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 12 }}>
        {RATES.map(({ key, label }) => {
          const r = rates[key]
          const up = r?.change != null && r.change > 0
          const dn = r?.change != null && r.change < 0
          return (
            <div key={key} style={{ background: 'rgba(13,27,46,0.02)', borderRadius: 10, padding: '14px 18px', borderLeft: `3px solid ${up ? '#C0392B' : dn ? '#2E7D50' : '#8A9BB0'}` }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 6 }}>{label}</div>
              {loading ? (
                <div style={{ fontSize: 22, fontWeight: 700, color: '#C9A84C', fontFamily: "'Cormorant Garamond',serif" }}>—</div>
              ) : (
                <>
                  <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 26, fontWeight: 700, color: '#0D1B2E' }}>
                    {r?.rate != null ? r.rate.toFixed(2) + '%' : '—'}
                  </div>
                  {r?.change != null && (
                    <div style={{ fontSize: 11, fontWeight: 600, color: up ? '#C0392B' : dn ? '#2E7D50' : '#8A9BB0', marginTop: 4 }}>
                      {up ? '▲' : dn ? '▼' : '—'} {Math.abs(r.change).toFixed(3)} bps
                    </div>
                  )}
                </>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

export default function DashboardPage({ deals, capRateMap, boeMap, onOpenDeal }: Props) {
  const now = new Date()
  const currentMonth = now.getMonth()
  const currentYear = now.getFullYear()

  const active = deals.filter(d => d.status.includes('2 -'))
  const newDeals = deals.filter(d => d.status.includes('1 -'))
  const owned = deals.filter(d => d.status.includes('10 -'))
  const avgPrice = useMemo(() => {
    const priced = deals.filter(d => d.purchase_price)
    return priced.length ? priced.reduce((s, d) => s + d.purchase_price!, 0) / priced.length : 0
  }, [deals])

  const monthlyData = useMemo(() => {
    const months = []
    for (let i = 11; i >= 0; i--) {
      const d = new Date(currentYear, currentMonth - i, 1)
      const m = d.getMonth(), y = d.getFullYear()
      const count = deals.filter(deal => {
        if (!deal.added) return false
        const a = new Date(deal.added)
        return a.getMonth() === m && a.getFullYear() === y
      }).length
      const label = d.toLocaleDateString('en-US', { month: 'short', year: '2-digit' }).replace(' ', " '")
      months.push({ label, value: count, current: m === currentMonth && y === currentYear })
    }
    return months
  }, [deals, currentMonth, currentYear])

  const marketData = useMemo(() => {
    const counts: Record<string, number> = {}
    deals.filter(d => {
      if (!d.added) return false
      return new Date(d.added).getFullYear() === 2026
    }).forEach(d => {
      const region = getRegion ? getRegion(d.market || '') : (d.market || 'Other')
      const label = (REGION_LABELS && (REGION_LABELS as Record<string, string>)[region]) || region || 'Other'
      counts[label] = (counts[label] || 0) + 1
    })
    return Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .map(([label, value]) => ({ label, value, color: MARKET_COLORS[label] || '#8A9BB0' }))
  }, [deals])

  const upcomingBids = [...newDeals, ...active]
    .filter(d => d.bid_due_date && d.bid_due_date >= now.toISOString().split('T')[0])
    .sort((a, b) => a.bid_due_date!.localeCompare(b.bid_due_date!))
    .slice(0, 8)

  const statusCounts = deals.reduce((acc: Record<string, number>, d) => {
    acc[d.status] = (acc[d.status] || 0) + 1
    return acc
  }, {})

  const STAT_CARDS = [
    { label: 'Total Deals', value: deals.length.toLocaleString(), sub: 'all time', color: '#0D1B2E' },
    { label: 'New / Active', value: `${newDeals.length} / ${active.length}`, sub: 'current pipeline', color: '#1565A0' },
    { label: 'Owned Properties', value: owned.length.toString(), sub: 'portfolio', color: '#6B3FA0' },
    { label: 'Avg Ask Price', value: fmtShort(avgPrice), sub: 'across priced deals', color: '#2E7D50' },
  ]

  return (
    <div style={{ padding: '28px 32px' }}>
      {/* Stat cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 24 }}>
        {STAT_CARDS.map(s => (
          <div key={s.label} style={{ background: '#fff', borderRadius: 12, padding: '20px 22px', border: '1px solid rgba(13,27,46,0.07)', borderLeft: `4px solid ${s.color}` }}>
            <div style={{ fontSize: 11, color: '#8A9BB0', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 6 }}>{s.label}</div>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 26, fontWeight: 700, color: s.color }}>{s.value}</div>
            <div style={{ fontSize: 11, color: '#8A9BB0', marginTop: 3 }}>{s.sub}</div>
          </div>
        ))}
      </div>

      {/* Rates widget */}
      <RatesWidget />

      {/* Charts row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: 20, marginBottom: 20 }}>
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', padding: '20px 26px' }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 16 }}>Monthly Deal Flow — Last 12 Months</div>
          <BarChart data={monthlyData} />
        </div>
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', padding: '20px 26px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 12, alignSelf: 'flex-start' }}>2026 Deal Allocation by Market</div>
          <DonutChart data={marketData} />
        </div>
      </div>

      {/* Interactive Deal Map */}
      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden', height: 500, marginBottom: 20, display: 'flex', flexDirection: 'column' }}>
        <DealsMap deals={deals} onOpenDeal={onOpenDeal} />
      </div>

      {/* Upcoming bids */}
      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden', marginBottom: 20 }}>
        <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.07)' }}>
          <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E' }}>Upcoming Bids</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)' }}>
          {upcomingBids.length === 0 ? (
            <div style={{ padding: 24, color: '#8A9BB0', fontSize: 13, gridColumn: '1/-1' }}>No upcoming bids</div>
          ) : upcomingBids.map(deal => (
            <div key={deal.id} onClick={() => onOpenDeal(deal)} style={{ padding: '12px 20px', borderRight: '1px solid rgba(13,27,46,0.05)', borderBottom: '1px solid rgba(13,27,46,0.05)', cursor: 'pointer' }}
              onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.04)')}
              onMouseLeave={e => (e.currentTarget.style.background = '')}>
              <div style={{ fontSize: 13, fontWeight: 500, color: '#0D1B2E', marginBottom: 2 }}>{deal.name}</div>
              <div style={{ fontSize: 11, color: '#8A9BB0', marginBottom: 6 }}>{deal.market}</div>
              <div style={{ fontSize: 12, fontWeight: 600 }} className={bidDateClass(deal.bid_due_date)}>{formatBidDate(deal.bid_due_date)}</div>
              <div style={{ fontSize: 11, color: '#8A9BB0' }}>{fmtShort(deal.purchase_price)}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Status breakdown */}
      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', padding: '18px 22px' }}>
        <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E', marginBottom: 14 }}>Deal Flow by Status</div>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          {Object.entries(statusCounts).sort((a, b) => b[1] - a[1]).map(([status, count]) => (
            <div key={status} style={{ background: 'rgba(13,27,46,0.03)', borderRadius: 8, padding: '8px 16px', textAlign: 'center' }}>
              <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 20, fontWeight: 700, color: '#0D1B2E' }}>{count}</div>
              <div style={{ fontSize: 10, color: '#8A9BB0', marginTop: 1 }}>{statusLabel(status)}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
