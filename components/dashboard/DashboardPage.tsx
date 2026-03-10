'use client'
import { useMemo } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, statusClass, statusLabel, formatBidDate, bidDateClass, getRegion, REGION_LABELS } from '@/lib/utils'

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
    const x1 = cx + r * Math.cos(startAngle)
    const y1 = cy + r * Math.sin(startAngle)
    const x2 = cx + r * Math.cos(endAngle)
    const y2 = cy + r * Math.sin(endAngle)
    const large = pct > 0.5 ? 1 : 0
    return { ...d, path: `M ${x1} ${y1} A ${r} ${r} 0 ${large} 1 ${x2} ${y2}`, pct }
  })
  return (
    <svg width={160} height={160} viewBox="0 0 160 160">
      {slices.map((s, i) => (
        <path key={i} d={s.path} fill="none" stroke={s.color} strokeWidth={stroke} strokeLinecap="butt" />
      ))}
      <text x={cx} y={cy - 6} textAnchor="middle" style={{ fontSize: 18, fontWeight: 700, fill: '#0D1B2E', fontFamily: "'Cormorant Garamond',serif" }}>{total}</text>
      <text x={cx} y={cy + 10} textAnchor="middle" style={{ fontSize: 9, fill: '#8A9BB0', letterSpacing: '0.08em' }}>DEALS IN 2026</text>
    </svg>
  )
}

function BarChart({ data }: { data: { label: string; value: number; current?: boolean }[] }) {
  const max = Math.max(...data.map(d => d.value), 1)
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 100, paddingBottom: 20, position: 'relative' }}>
      {data.map((d, i) => (
        <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
          <div style={{
            width: '100%', height: Math.max((d.value / max) * 80, 2),
            background: d.current ? '#C9A84C' : '#0D1B2E',
            borderRadius: '3px 3px 0 0',
            opacity: d.current ? 1 : 0.65,
            transition: 'height 0.3s ease'
          }} />
          <div style={{ fontSize: 9, color: '#8A9BB0', whiteSpace: 'nowrap', transform: 'rotate(-30deg)', transformOrigin: 'top center', marginTop: 4 }}>{d.label}</div>
        </div>
      ))}
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

  // Monthly deal flow — last 12 months
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

  // 2026 deal allocation by market
  const marketData = useMemo(() => {
    const counts: Record<string, number> = {}
    deals.filter(d => {
      if (!d.added) return false
      return new Date(d.added).getFullYear() === 2026
    }).forEach(d => {
      const region = getRegion ? getRegion(d.market || '') : (d.market || 'Other')
      const label = (REGION_LABELS && REGION_LABELS[region]) || region || 'Other'
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

      {/* Charts row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 380px', gap: 20, marginBottom: 20 }}>
        {/* Monthly deal flow bar chart */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', padding: '18px 22px' }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 16 }}>Monthly Deal Flow — Last 12 Months</div>
          <BarChart data={monthlyData} />
        </div>

        {/* Donut + legend */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', padding: '18px 22px' }}>
          <div style={{ fontSize: 10, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 12 }}>2026 Deal Allocation by Market</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <DonutChart data={marketData} />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 16px', flex: 1 }}>
              {marketData.map(d => (
                <div key={d.label} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div style={{ width: 10, height: 10, borderRadius: 2, background: d.color, flexShrink: 0 }} />
                  <span style={{ fontSize: 11, color: '#0D1B2E' }}>{d.label}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Bottom row: Active pipeline + Upcoming bids */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 20, marginBottom: 20 }}>
        {/* Active pipeline table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden' }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.07)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E' }}>Active Pipeline</div>
            <span style={{ fontSize: 11, color: '#8A9BB0' }}>{active.length + newDeals.length} deals</span>
          </div>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: 'rgba(13,27,46,0.03)' }}>
                {['Deal', 'Status', 'Price', 'Bid Date'].map(h => (
                  <th key={h} style={{ padding: '9px 14px', textAlign: 'left', fontSize: 10, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {[...active, ...newDeals].slice(0, 15).map(deal => (
                <tr key={deal.id} onClick={() => onOpenDeal(deal)} style={{ cursor: 'pointer', borderBottom: '1px solid rgba(13,27,46,0.04)' }}
                  onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.04)')}
                  onMouseLeave={e => (e.currentTarget.style.background = '')}>
                  <td style={{ padding: '9px 14px', fontWeight: 500, fontSize: 13, color: '#0D1B2E', maxWidth: 200 }}>
                    {deal.name}
                    <small style={{ display: 'block', fontSize: 11, color: '#8A9BB0' }}>{deal.market}</small>
                  </td>
                  <td style={{ padding: '9px 14px' }}>
                    <span className={`status-badge ${statusClass(deal.status)}`} style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '2px 8px', borderRadius: 10, fontSize: 11, fontWeight: 600 }}>
                      <span style={{ width: 5, height: 5, borderRadius: '50%', background: 'currentColor', opacity: .7 }} />
                      {statusLabel(deal.status)}
                    </span>
                  </td>
                  <td style={{ padding: '9px 14px', fontSize: 12, fontVariantNumeric: 'tabular-nums', textAlign: 'right' }}>{fmtShort(deal.purchase_price)}</td>
                  <td style={{ padding: '9px 14px', fontSize: 12, whiteSpace: 'nowrap' }} className={bidDateClass(deal.bid_due_date)}>{formatBidDate(deal.bid_due_date)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Upcoming bids */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden' }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.07)' }}>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E' }}>Upcoming Bids</div>
          </div>
          {upcomingBids.length === 0 ? (
            <div style={{ padding: 24, textAlign: 'center', color: '#8A9BB0', fontSize: 13 }}>No upcoming bids</div>
          ) : upcomingBids.map(deal => (
            <div key={deal.id} onClick={() => onOpenDeal(deal)} style={{ padding: '12px 20px', borderBottom: '1px solid rgba(13,27,46,0.05)', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
              onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.04)')}
              onMouseLeave={e => (e.currentTarget.style.background = '')}>
              <div>
                <div style={{ fontSize: 13, fontWeight: 500, color: '#0D1B2E' }}>{deal.name}</div>
                <div style={{ fontSize: 11, color: '#8A9BB0' }}>{deal.market}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: 12, fontWeight: 600 }} className={bidDateClass(deal.bid_due_date)}>{formatBidDate(deal.bid_due_date)}</div>
                <div style={{ fontSize: 11, color: '#8A9BB0' }}>{fmtShort(deal.purchase_price)}</div>
              </div>
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
