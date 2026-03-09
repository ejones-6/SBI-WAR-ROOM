'use client'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, statusClass, statusLabel, formatBidDate, bidDateClass, getRegion, REGION_LABELS } from '@/lib/utils'

interface Props {
  deals: Deal[]
  capRateMap: Record<string, CapRate>
  boeMap: Record<string, BoeData>
  onOpenDeal: (d: Deal) => void
}

export default function DashboardPage({ deals, capRateMap, boeMap, onOpenDeal }: Props) {
  const statusCounts = deals.reduce((acc: Record<string, number>, d) => {
    acc[d.status] = (acc[d.status] || 0) + 1
    return acc
  }, {})

  const active = deals.filter(d => d.status.includes('2 -'))
  const newDeals = deals.filter(d => d.status.includes('1 -'))
  const owned = deals.filter(d => d.status.includes('10 -'))
  const avgPrice = deals.filter(d => d.purchase_price).reduce((s, d) => s + (d.purchase_price! / deals.filter(x => x.purchase_price).length), 0)

  const upcomingBids = newDeals
    .filter(d => d.bid_due_date)
    .sort((a, b) => a.bid_due_date!.localeCompare(b.bid_due_date!))
    .slice(0, 8)

  const STAT_CARDS = [
    { label: 'Total Deals', value: deals.length.toLocaleString(), sub: 'all time', color: '#0D1B2E' },
    { label: 'New / Active', value: `${newDeals.length} / ${active.length}`, sub: 'current pipeline', color: '#1565A0' },
    { label: 'Owned Properties', value: owned.length.toString(), sub: 'portfolio', color: '#6B3FA0' },
    { label: 'Avg Ask Price', value: fmtShort(avgPrice), sub: 'across all deals', color: '#2E7D50' },
  ]

  return (
    <div style={{ padding: '28px 32px' }}>
      {/* Stat cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 16, marginBottom: 28 }}>
        {STAT_CARDS.map(s => (
          <div key={s.label} style={{ background: '#fff', borderRadius: 12, padding: '20px 22px', border: '1px solid rgba(13,27,46,0.07)', borderLeft: `4px solid ${s.color}` }}>
            <div style={{ fontSize: 11, color: '#8A9BB0', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 6 }}>{s.label}</div>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 26, fontWeight: 700, color: s.color }}>{s.value}</div>
            <div style={{ fontSize: 11, color: '#8A9BB0', marginTop: 3 }}>{s.sub}</div>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 20 }}>
        {/* Active pipeline table */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden' }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.07)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E' }}>Active Pipeline</div>
            <span style={{ fontSize: 11, color: '#8A9BB0' }}>{active.length + newDeals.length} deals</span>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: 'rgba(13,27,46,0.03)' }}>
                  {['Deal','Status','Price','Bid Date'].map(h => (
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
        </div>

        {/* Upcoming bids */}
        <div style={{ background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden' }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.07)' }}>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E' }}>Upcoming Bids</div>
          </div>
          <div>
            {upcomingBids.length === 0 && (
              <div style={{ padding: 24, textAlign: 'center', color: '#8A9BB0', fontSize: 13 }}>No upcoming bids</div>
            )}
            {upcomingBids.map(deal => (
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
      </div>

      {/* Status breakdown */}
      <div style={{ marginTop: 20, background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', padding: '18px 22px' }}>
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
