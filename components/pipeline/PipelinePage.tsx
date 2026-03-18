'use client'
import { useMemo, useState } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, formatBidDate, bidDateClass, statusLabel, getRegion, REGION_LABELS } from '@/lib/utils'

interface Props {
  deals: Deal[]
  onOpenDeal: (d: Deal) => void
  onSaveDeal?: (d: Deal) => Promise<any>
}

const NAVY = '#0D1B2E'
const GOLD = '#C9A84C'
const CREAM = '#F5F4EF'
const MUTED = '#8A9BB0'
const ORANGE = '#E8A020'

function fmtDate(s?: string | null) {
  if (!s) return '—'
  return new Date(s).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

export default function PipelinePage({ deals, onOpenDeal }: Props) {
  const [section, setSection] = useState<'bids' | 'velocity' | 'focus'>('bids')
  const now = new Date()
  const todayStr = now.toISOString().split('T')[0]

  // ── Bid Calendar data ──────────────────────────────────────────────────────
  const upcomingBids = useMemo(() => {
    return deals
      .filter(d => d.bid_due_date && d.bid_due_date >= todayStr && (d.status.includes('1 -') || d.status.includes('2 -') || d.status.includes('3 -')))
      .sort((a, b) => a.bid_due_date!.localeCompare(b.bid_due_date!))
  }, [deals, todayStr])

  const pastBids = useMemo(() => {
    return deals
      .filter(d => d.bid_due_date && d.bid_due_date < todayStr && (d.status.includes('1 -') || d.status.includes('2 -') || d.status.includes('3 -')))
      .sort((a, b) => b.bid_due_date!.localeCompare(a.bid_due_date!))
      .slice(0, 10)
  }, [deals, todayStr])

  // Group upcoming by week
  const byWeek = useMemo(() => {
    const weeks: { label: string; deals: Deal[] }[] = []
    upcomingBids.forEach(d => {
      const date = new Date(d.bid_due_date!)
      const weekStart = new Date(date)
      weekStart.setDate(date.getDate() - date.getDay())
      const label = weekStart.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) + ' week'
      const existing = weeks.find(w => w.label === label)
      if (existing) existing.deals.push(d)
      else weeks.push({ label, deals: [d] })
    })
    return weeks
  }, [upcomingBids])

  // ── Deal Velocity ──────────────────────────────────────────────────────────
  const velocity = useMemo(() => {
    // Last 90 days activity
    const cutoff = new Date(now)
    cutoff.setDate(cutoff.getDate() - 90)
    const cutoffStr = cutoff.toISOString().split('T')[0]

    const recentlyAdded = deals.filter(d => d.added && d.added >= cutoffStr).length
    const recentlyModified = deals.filter(d => d.modified && d.modified >= cutoffStr).length
    const newDeals = deals.filter(d => d.status.includes('1 -')).length
    const activeDeals = deals.filter(d => d.status.includes('2 -')).length
    const bidPlaced = deals.filter(d => d.status.includes('3 -')).length
    const owned = deals.filter(d => d.status.includes('10 -')).length
    const passed = deals.filter(d => d.status.includes('6 -') || d.status.includes('7 -')).length

    // Win rate: owned / (owned + passed)
    const winRate = owned + passed > 0 ? (owned / (owned + passed)) * 100 : 0

    // By region breakdown
    const byRegion = deals.reduce((acc: Record<string, { new: number; active: number; bid: number }>, d) => {
      const reg = (REGION_LABELS as any)[getRegion(d.market)] || 'Other'
      if (!acc[reg]) acc[reg] = { new: 0, active: 0, bid: 0 }
      if (d.status.includes('1 -')) acc[reg].new++
      if (d.status.includes('2 -')) acc[reg].active++
      if (d.status.includes('3 -')) acc[reg].bid++
      return acc
    }, {})

    return { recentlyAdded, recentlyModified, newDeals, activeDeals, bidPlaced, owned, passed, winRate, byRegion }
  }, [deals])

  // ── Focus List — deals needing attention ──────────────────────────────────
  const focusList = useMemo(() => {
    const today = new Date()
    return deals
      .filter(d => d.status.includes('2 -') || d.status.includes('1 -'))
      .map(d => {
        let urgency = 0
        let reason = ''
        // Bid due soon
        if (d.bid_due_date) {
          const daysUntil = Math.ceil((new Date(d.bid_due_date).getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
          if (daysUntil <= 3 && daysUntil >= 0) { urgency = 3; reason = `Bid in ${daysUntil}d` }
          else if (daysUntil <= 7 && daysUntil >= 0) { urgency = 2; reason = `Bid in ${daysUntil}d` }
          else if (daysUntil <= 14 && daysUntil >= 0) { urgency = 1; reason = `Bid in ${daysUntil}d` }
        }
        // Not modified in 14+ days
        if (!reason && d.modified) {
          const daysSince = Math.floor((today.getTime() - new Date(d.modified).getTime()) / (1000 * 60 * 60 * 24))
          if (daysSince >= 14) { urgency = Math.max(urgency, 1); reason = `No update in ${daysSince}d` }
        }
        return { ...d, urgency, reason }
      })
      .filter(d => d.urgency > 0 || d.bid_due_date)
      .sort((a, b) => b.urgency - a.urgency || (a.bid_due_date || '').localeCompare(b.bid_due_date || ''))
      .slice(0, 15)
  }, [deals])

  const card = { background: '#fff', borderRadius: 12, border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden' as const }
  const darkCard = { background: NAVY, borderRadius: 12, border: `1px solid rgba(201,168,76,0.15)`, overflow: 'hidden' as const }

  const urgencyColor = (u: number) => u === 3 ? '#C0392B' : u === 2 ? '#E8A020' : '#2E7D50'

  return (
    <div style={{ padding: '24px 28px', background: '#EEEDE7', minHeight: '100%' }}>

      {/* Header */}
      <div style={{ marginBottom: 20, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div>
          <div style={{ fontSize: 9, fontWeight: 700, color: GOLD, letterSpacing: '0.2em', textTransform: 'uppercase' as const, marginBottom: 4 }}>Active Pipeline</div>
          <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 26, fontWeight: 700, color: NAVY }}>Pipeline Manager</div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {([['bids', 'Bid Calendar'], ['focus', 'Focus List'], ['velocity', 'Velocity']] as const).map(([id, label]) => (
            <button key={id} onClick={() => setSection(id)} style={{
              padding: '7px 16px', borderRadius: 8, border: '1px solid',
              borderColor: section === id ? NAVY : 'rgba(13,27,46,0.15)',
              background: section === id ? NAVY : '#fff',
              color: section === id ? GOLD : MUTED,
              fontSize: 12, fontWeight: 600, cursor: 'pointer', fontFamily: "'DM Sans',sans-serif"
            }}>{label}</button>
          ))}
        </div>
      </div>

      {/* ── BID CALENDAR ── */}
      {section === 'bids' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 320px', gap: 16 }}>
          <div>
            {upcomingBids.length === 0 ? (
              <div style={{ ...card, padding: 32, textAlign: 'center' as const, color: MUTED, fontSize: 13 }}>No upcoming bid dates</div>
            ) : byWeek.map(week => (
              <div key={week.label} style={{ marginBottom: 20 }}>
                <div style={{ fontSize: 10, fontWeight: 700, color: GOLD, letterSpacing: '0.12em', textTransform: 'uppercase' as const, marginBottom: 8, paddingLeft: 4 }}>{week.label}</div>
                {week.deals.map(d => {
                  const daysUntil = Math.ceil((new Date(d.bid_due_date!).getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
                  const isUrgent = daysUntil <= 3
                  const isSoon = daysUntil <= 7
                  return (
                    <div key={d.id} onClick={() => onOpenDeal(d)}
                      style={{ ...card, marginBottom: 8, padding: '14px 18px', cursor: 'pointer', borderLeft: `4px solid ${isUrgent ? '#C0392B' : isSoon ? ORANGE : '#2E6B9E'}`, display: 'grid', gridTemplateColumns: '1fr auto', gap: 16, alignItems: 'center' }}
                      onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.04)')}
                      onMouseLeave={e => (e.currentTarget.style.background = '#fff')}>
                      <div>
                        <div style={{ fontSize: 14, fontWeight: 700, color: NAVY, marginBottom: 3 }}>{d.name}</div>
                        <div style={{ fontSize: 11, color: MUTED }}>
                          {d.market} · {d.units?.toLocaleString()} units
                          {d.purchase_price ? ` · ${fmtShort(d.purchase_price)}` : ''}
                          {d.broker ? ` · ${d.broker}` : ''}
                        </div>
                      </div>
                      <div style={{ textAlign: 'right' as const }}>
                        <div style={{ fontSize: 13, fontWeight: 700, color: isUrgent ? '#C0392B' : isSoon ? ORANGE : NAVY }}>
                          {fmtDate(d.bid_due_date)}
                        </div>
                        <div style={{ fontSize: 11, color: isUrgent ? '#C0392B' : isSoon ? ORANGE : MUTED, fontWeight: 600, marginTop: 2 }}>
                          {daysUntil === 0 ? 'Today' : daysUntil === 1 ? 'Tomorrow' : `${daysUntil} days`}
                        </div>
                      </div>
                    </div>
                  )
                })}
              </div>
            ))}
          </div>

          {/* Sidebar — recent past bids */}
          <div>
            <div style={{ ...darkCard }}>
              <div style={{ padding: '14px 16px', borderBottom: '1px solid rgba(201,168,76,0.1)' }}>
                <div style={{ fontSize: 9, fontWeight: 700, color: 'rgba(201,168,76,0.55)', letterSpacing: '0.15em', textTransform: 'uppercase' as const }}>Recently Passed</div>
                <div style={{ fontSize: 15, fontWeight: 700, color: CREAM, fontFamily: "'Cormorant Garamond',serif", marginTop: 2 }}>Past Bid Dates</div>
              </div>
              <div style={{ padding: '8px 0' }}>
                {pastBids.length === 0 ? (
                  <div style={{ padding: '16px', color: 'rgba(245,244,239,0.3)', fontSize: 12 }}>None yet</div>
                ) : pastBids.map(d => (
                  <div key={d.id} onClick={() => onOpenDeal(d)}
                    style={{ padding: '10px 16px', borderBottom: '1px solid rgba(255,255,255,0.04)', cursor: 'pointer' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.05)')}
                    onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}>
                    <div style={{ fontSize: 12, fontWeight: 600, color: CREAM, marginBottom: 2, whiteSpace: 'nowrap' as const, overflow: 'hidden', textOverflow: 'ellipsis' }}>{d.name}</div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div style={{ fontSize: 10, color: 'rgba(245,244,239,0.35)' }}>{d.market?.split(',')[0]}</div>
                      <div style={{ fontSize: 10, color: 'rgba(245,244,239,0.35)' }}>{fmtDate(d.bid_due_date)}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Quick stats */}
            <div style={{ ...card, padding: '16px 18px', marginTop: 12 }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 12 }}>Pipeline Summary</div>
              {[
                ['Upcoming Bids', upcomingBids.length.toString()],
                ['This Week', byWeek[0]?.deals.length.toString() ?? '0'],
                ['Next 14 Days', upcomingBids.filter(d => {
                  const days = Math.ceil((new Date(d.bid_due_date!).getTime() - now.getTime()) / 86400000)
                  return days <= 14
                }).length.toString()],
              ].map(([l, v]) => (
                <div key={l} style={{ display: 'flex', justifyContent: 'space-between', padding: '7px 0', borderBottom: '1px solid rgba(13,27,46,0.04)' }}>
                  <span style={{ fontSize: 12, color: MUTED }}>{l}</span>
                  <span style={{ fontSize: 14, fontWeight: 700, color: NAVY, fontFamily: "'DM Mono',monospace" }}>{v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ── FOCUS LIST ── */}
      {section === 'focus' && (
        <div>
          <div style={{ ...card, marginBottom: 16 }}>
            <div style={{ padding: '12px 18px', borderBottom: '1px solid rgba(13,27,46,0.06)', background: NAVY }}>
              <div style={{ fontSize: 9, fontWeight: 700, color: 'rgba(201,168,76,0.55)', letterSpacing: '0.15em', textTransform: 'uppercase' as const }}>Attention Required</div>
              <div style={{ fontSize: 15, fontWeight: 700, color: CREAM, fontFamily: "'Cormorant Garamond',serif", marginTop: 2 }}>Focus List — Deals Needing Action</div>
            </div>
            <table style={{ width: '100%', borderCollapse: 'collapse' as const }}>
              <thead>
                <tr style={{ background: 'rgba(13,27,46,0.03)' }}>
                  {['Deal', 'Market', 'Status', 'Guidance', 'Broker', 'Bid Date', 'Reason'].map(h => (
                    <th key={h} style={{ padding: '8px 14px', textAlign: 'left' as const, fontSize: 9, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' as const }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {focusList.map((d, i) => (
                  <tr key={d.id} onClick={() => onOpenDeal(d)}
                    style={{ borderBottom: '1px solid rgba(13,27,46,0.05)', cursor: 'pointer', background: i % 2 === 0 ? '#fff' : 'rgba(13,27,46,0.01)' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.05)')}
                    onMouseLeave={e => (e.currentTarget.style.background = i % 2 === 0 ? '#fff' : 'rgba(13,27,46,0.01)')}>
                    <td style={{ padding: '11px 14px', fontWeight: 700, color: NAVY, fontSize: 13 }}>{d.name}</td>
                    <td style={{ padding: '11px 14px', color: MUTED, fontSize: 12 }}>{d.market?.split(',')[0]}</td>
                    <td style={{ padding: '11px 14px' }}>
                      <span style={{ fontSize: 11, fontWeight: 600, padding: '2px 8px', borderRadius: 10, background: d.status.includes('1 -') ? 'rgba(46,107,158,0.1)' : 'rgba(46,125,80,0.1)', color: d.status.includes('1 -') ? '#2E6B9E' : '#2E7D50' }}>
                        {statusLabel(d.status)}
                      </span>
                    </td>
                    <td style={{ padding: '11px 14px', color: NAVY, fontSize: 13, fontFamily: "'DM Mono',monospace", fontWeight: 600 }}>{fmtShort(d.purchase_price)}</td>
                    <td style={{ padding: '11px 14px', color: MUTED, fontSize: 12 }}>{d.broker || '—'}</td>
                    <td style={{ padding: '11px 14px', fontSize: 12, fontWeight: 600 }} className={bidDateClass(d.bid_due_date)}>{formatBidDate(d.bid_due_date)}</td>
                    <td style={{ padding: '11px 14px' }}>
                      {d.reason && (
                        <span style={{ fontSize: 11, fontWeight: 700, color: urgencyColor(d.urgency), background: `${urgencyColor(d.urgency)}15`, padding: '2px 8px', borderRadius: 10 }}>
                          {d.reason}
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── VELOCITY ── */}
      {section === 'velocity' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16 }}>
          {/* Pipeline funnel */}
          <div style={{ ...darkCard, padding: '20px 22px' }}>
            <div style={{ fontSize: 9, fontWeight: 700, color: 'rgba(201,168,76,0.55)', letterSpacing: '0.15em', textTransform: 'uppercase' as const, marginBottom: 4 }}>Deal Funnel</div>
            <div style={{ fontSize: 17, fontWeight: 700, color: CREAM, fontFamily: "'Cormorant Garamond',serif", marginBottom: 18 }}>Pipeline Status</div>
            {[
              { label: 'New', count: velocity.newDeals, color: '#2E6B9E', width: 100 },
              { label: 'Active', count: velocity.activeDeals, color: '#2E7D50', width: velocity.newDeals ? (velocity.activeDeals / velocity.newDeals) * 100 : 0 },
              { label: 'Bid Placed', count: velocity.bidPlaced, color: ORANGE, width: velocity.newDeals ? (velocity.bidPlaced / velocity.newDeals) * 100 : 0 },
              { label: 'Owned', count: velocity.owned, color: GOLD, width: velocity.newDeals ? (velocity.owned / velocity.newDeals) * 100 : 0 },
            ].map(s => (
              <div key={s.label} style={{ marginBottom: 14 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 5 }}>
                  <span style={{ fontSize: 11, color: 'rgba(245,244,239,0.6)' }}>{s.label}</span>
                  <span style={{ fontSize: 14, fontWeight: 700, color: CREAM, fontFamily: "'DM Mono',monospace" }}>{s.count}</span>
                </div>
                <div style={{ background: 'rgba(255,255,255,0.07)', borderRadius: 3, height: 8, overflow: 'hidden' }}>
                  <div style={{ width: `${Math.min(s.width, 100)}%`, height: '100%', background: s.color, borderRadius: 3 }} />
                </div>
              </div>
            ))}
          </div>

          {/* Win rate + 90-day activity */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ ...card, padding: '20px 22px', flex: 1 }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 4 }}>Win Rate</div>
              <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 42, fontWeight: 700, color: NAVY, lineHeight: 1 }}>{velocity.winRate.toFixed(1)}%</div>
              <div style={{ fontSize: 12, color: MUTED, marginTop: 6 }}>{velocity.owned} owned · {velocity.passed} passed/lost</div>
              <div style={{ marginTop: 14, background: 'rgba(13,27,46,0.06)', borderRadius: 6, height: 10, overflow: 'hidden' }}>
                <div style={{ width: `${velocity.winRate}%`, height: '100%', background: '#2E7D50', borderRadius: 6 }} />
              </div>
            </div>
            <div style={{ ...card, padding: '20px 22px', flex: 1 }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 12 }}>Last 90 Days</div>
              {[
                ['Deals Added', velocity.recentlyAdded],
                ['Deals Updated', velocity.recentlyModified],
              ].map(([l, v]) => (
                <div key={l as string} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid rgba(13,27,46,0.05)' }}>
                  <span style={{ fontSize: 12, color: MUTED }}>{l}</span>
                  <span style={{ fontSize: 16, fontWeight: 700, color: NAVY, fontFamily: "'DM Mono',monospace" }}>{v}</span>
                </div>
              ))}
            </div>
          </div>

          {/* By Region */}
          <div style={{ ...card, padding: '20px 22px' }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 4 }}>By Region</div>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: NAVY, marginBottom: 16 }}>Active Pipeline Breakdown</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 40px 40px 40px', gap: 6, marginBottom: 8 }}>
              {['Region', 'New', 'Act', 'Bid'].map(h => (
                <div key={h} style={{ fontSize: 8, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' as const, textAlign: h === 'Region' ? 'left' : 'center' as const }}>{h}</div>
              ))}
            </div>
            {Object.entries(velocity.byRegion)
              .filter(([, v]) => v.new + v.active + v.bid > 0)
              .sort((a, b) => (b[1].new + b[1].active + b[1].bid) - (a[1].new + a[1].active + a[1].bid))
              .map(([region, v]) => (
                <div key={region} style={{ display: 'grid', gridTemplateColumns: '1fr 40px 40px 40px', gap: 6, padding: '7px 0', borderBottom: '1px solid rgba(13,27,46,0.04)', alignItems: 'center' }}>
                  <span style={{ fontSize: 12, color: NAVY, fontWeight: 500 }}>{region}</span>
                  <span style={{ fontSize: 13, fontWeight: 700, color: '#2E6B9E', textAlign: 'center' as const, fontFamily: "'DM Mono',monospace" }}>{v.new || '—'}</span>
                  <span style={{ fontSize: 13, fontWeight: 700, color: '#2E7D50', textAlign: 'center' as const, fontFamily: "'DM Mono',monospace" }}>{v.active || '—'}</span>
                  <span style={{ fontSize: 13, fontWeight: 700, color: ORANGE, textAlign: 'center' as const, fontFamily: "'DM Mono',monospace" }}>{v.bid || '—'}</span>
                </div>
              ))}
          </div>
        </div>
      )}
    </div>
  )
}
