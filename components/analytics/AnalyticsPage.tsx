'use client'
import { useMemo, useState } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { getRegion, REGION_LABELS, fmtShort } from '@/lib/utils'

interface Props {
  deals: Deal[]
  boeMap: Record<string, BoeData>
  capRateMap: Record<string, CapRate>
}

// ── Shared helpers ────────────────────────────────────────────────────────────
const SBI_ORANGE = '#E8A020'
const NAVY = '#0D1B2E'
const CREAM = '#F5F4EF'
const MUTED = '#8A9BB0'

const CHART_COLORS = [
  '#E8A020', '#2E6B9E', '#2E7D50', '#6B3FA0',
  '#1E7A6E', '#8B4513', '#C0392B', '#2C8C8C', '#5D6D7E', '#4A235A'
]

function shortMarket(m: string) {
  return m
    .replace('Washington, DC-MD-VA', 'Washington DC')
    .replace('Baltimore, MD', 'Baltimore')
    .replace('Richmond-Petersburg, VA', 'Richmond')
    .replace('Raleigh-Durham-Chapel Hill, NC', 'Raleigh/Durham')
    .replace('Charlotte-Gastonia-Rock Hill, NC-SC', 'Charlotte')
    .replace('Greensboro--Winston-Salem--High Point, NC', 'Greensboro')
    .replace('Charleston-North Charleston, SC', 'Charleston SC')
    .replace('Greenville-Spartanburg-Anderson, SC', 'Greenville SC')
    .replace('Atlanta, GA', 'Atlanta')
    .replace('Dallas-Fort Worth, TX', 'Dallas/FW')
    .replace('Houston, TX', 'Houston')
    .replace('Austin-San Marcos, TX', 'Austin')
    .replace('San Antonio, TX', 'San Antonio')
    .replace('Nashville, TN', 'Nashville')
    .replace('Orlando, FL', 'Orlando')
    .replace('Tampa-St. Petersburg-Clearwater, FL', 'Tampa')
    .replace('Miami-Fort Lauderdale, FL', 'South Florida')
    .replace('Fort Myers-Cape Coral, FL', 'Fort Myers')
    .replace('Jacksonville, FL', 'Jacksonville')
    .split(',')[0]
}

const card: React.CSSProperties = {
  background: '#fff', borderRadius: 12,
  border: '1px solid rgba(13,27,46,0.07)', overflow: 'hidden'
}
const darkCard: React.CSSProperties = {
  background: NAVY, borderRadius: 12,
  border: `1px solid rgba(232,160,32,0.15)`, overflow: 'hidden'
}
const sectionLabel = (accent = SBI_ORANGE): React.CSSProperties => ({
  fontSize: 9, fontWeight: 700, color: accent,
  letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 2
})
const cardTitle: React.CSSProperties = {
  fontFamily: "'Cormorant Garamond',serif", fontSize: 16, fontWeight: 700,
  color: NAVY, marginTop: 2
}
const darkCardTitle: React.CSSProperties = {
  fontFamily: "'Cormorant Garamond',serif", fontSize: 16, fontWeight: 700,
  color: CREAM, marginTop: 2
}

// ── Simple SVG bar chart ──────────────────────────────────────────────────────
function HorizBar({ label, value, max, color, sub }: { label: string; value: number; max: number; color: string; sub?: string }) {
  const pct = max > 0 ? (value / max) * 100 : 0
  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
        <span style={{ fontSize: 11, color: NAVY, fontWeight: 500 }}>{label}</span>
        <div style={{ textAlign: 'right' }}>
          <span style={{ fontSize: 12, fontWeight: 700, color: NAVY, fontFamily: "'DM Mono',monospace" }}>{value}</span>
          {sub && <span style={{ fontSize: 10, color: MUTED, marginLeft: 6 }}>{sub}</span>}
        </div>
      </div>
      <div style={{ height: 6, background: 'rgba(13,27,46,0.06)', borderRadius: 3, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${pct}%`, background: color, borderRadius: 3, transition: 'width 0.4s ease' }} />
      </div>
    </div>
  )
}

function HorizBarDark({ label, value, max, color, sub }: { label: string; value: number; max: number; color: string; sub?: string }) {
  const pct = max > 0 ? (value / max) * 100 : 0
  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
        <span style={{ fontSize: 11, color: 'rgba(245,244,239,0.7)', fontWeight: 500 }}>{label}</span>
        <div style={{ textAlign: 'right' }}>
          <span style={{ fontSize: 12, fontWeight: 700, color: CREAM, fontFamily: "'DM Mono',monospace" }}>{value}</span>
          {sub && <span style={{ fontSize: 10, color: 'rgba(245,244,239,0.35)', marginLeft: 6 }}>{sub}</span>}
        </div>
      </div>
      <div style={{ height: 6, background: 'rgba(255,255,255,0.08)', borderRadius: 3, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${pct}%`, background: color, borderRadius: 3, transition: 'width 0.4s ease' }} />
      </div>
    </div>
  )
}

// ── 1. Market Intelligence ─────────────────────────────────────────────────────
function MarketIntelligence({ deals }: { deals: Deal[] }) {
  const [yearFilter, setYearFilter] = useState<'all' | '2024' | '2025' | '2026'>('all')

  const filtered = useMemo(() => deals.filter(d => {
    if (yearFilter === 'all') return true
    return d.added?.startsWith(yearFilter)
  }), [deals, yearFilter])

  const byMarket = useMemo(() => {
    const map: Record<string, { count: number; prices: number[]; ppus: number[] }> = {}
    filtered.forEach(d => {
      const m = shortMarket(d.market || 'Unknown')
      if (!map[m]) map[m] = { count: 0, prices: [], ppus: [] }
      map[m].count++
      if (d.purchase_price) map[m].prices.push(d.purchase_price)
      if (d.price_per_unit) map[m].ppus.push(d.price_per_unit)
    })
    return Object.entries(map)
      .map(([market, v]) => ({
        market,
        count: v.count,
        avgPrice: v.prices.length ? v.prices.reduce((a, b) => a + b, 0) / v.prices.length : null,
        avgPpu: v.ppus.length ? Math.round(v.ppus.reduce((a, b) => a + b, 0) / v.ppus.length) : null,
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 12)
  }, [filtered])

  const maxCount = byMarket[0]?.count || 1

  return (
    <div style={card}>
      <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.06)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={sectionLabel()}>Deal Flow · By Market</div>
          <div style={cardTitle}>Market Intelligence</div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['all', '2024', '2025', '2026'] as const).map(y => (
            <button key={y} onClick={() => setYearFilter(y)} style={{
              padding: '4px 10px', borderRadius: 5, border: '1px solid rgba(13,27,46,0.12)',
              background: yearFilter === y ? NAVY : '#fff',
              color: yearFilter === y ? SBI_ORANGE : MUTED,
              fontSize: 10, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.05em'
            }}>{y === 'all' ? 'All Time' : y}</button>
          ))}
        </div>
      </div>
      <div style={{ padding: '18px 20px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0 28px' }}>
          {byMarket.map((m, i) => (
            <HorizBar
              key={m.market} label={m.market} value={m.count} max={maxCount}
              color={CHART_COLORS[i % CHART_COLORS.length]}
              sub={m.avgPpu ? `$${(m.avgPpu / 1000).toFixed(0)}K/unit` : undefined}
            />
          ))}
        </div>
        <div style={{ marginTop: 16, paddingTop: 12, borderTop: '1px solid rgba(13,27,46,0.05)', display: 'flex', gap: 24 }}>
          <div><div style={{ fontSize: 9, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' }}>Total Deals</div><div style={{ fontSize: 20, fontWeight: 700, color: NAVY, fontFamily: "'Cormorant Garamond',serif" }}>{filtered.length.toLocaleString()}</div></div>
          <div><div style={{ fontSize: 9, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' }}>Markets Tracked</div><div style={{ fontSize: 20, fontWeight: 700, color: NAVY, fontFamily: "'Cormorant Garamond',serif" }}>{byMarket.length}</div></div>
          <div><div style={{ fontSize: 9, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase' }}>Avg Guidance</div><div style={{ fontSize: 20, fontWeight: 700, color: NAVY, fontFamily: "'Cormorant Garamond',serif" }}>{fmtShort(filtered.filter(d => d.purchase_price).reduce((s, d) => s + d.purchase_price!, 0) / Math.max(filtered.filter(d => d.purchase_price).length, 1))}</div></div>
        </div>
      </div>
    </div>
  )
}

// ── 2. Cap Rate Distribution ─────────────────────────────────────────────────
function CapRateDistribution({ deals, capRateMap }: { deals: Deal[]; capRateMap: Record<string, CapRate> }) {
  const [view, setView] = useState<'dist' | 'market'>('dist')
  const [yearFilter, setYearFilter] = useState<'all' | '2024' | '2025' | '2026'>('all')

  const filteredDeals = useMemo(() =>
    yearFilter === 'all' ? deals : deals.filter(d => d.added?.startsWith(yearFilter))
  , [deals, yearFilter])

  // Build distribution buckets: 4.0–6.5% in 25bps increments
  const distData = useMemo(() => {
    const rates = filteredDeals
      .map(d => capRateMap[d.name]?.noi_cap_rate)
      .filter(Boolean)
      .map(Number)

    // 25bps buckets from 4.00 to 6.50, plus <4% and >6.5% catch-alls
    const steps = Array.from({ length: 10 }, (_, i) => 4.0 + i * 0.25) // 4.00,4.25,...6.25
    const buckets = ['<4.00', ...steps.map(s => `${s.toFixed(2)}–${(s+0.25).toFixed(2)}`), '>6.50']
    const counts = buckets.map((_, i) => {
      if (i === 0) return rates.filter(r => r < 4.0).length
      if (i === buckets.length - 1) return rates.filter(r => r >= 6.5).length
      const lo = 4.0 + (i - 1) * 0.25
      const hi = lo + 0.25
      return rates.filter(r => r >= lo && r < hi).length
    })
    const maxC = Math.max(...counts, 1)
    return buckets.map((label, i) => ({ label, count: counts[i], pct: (counts[i] / maxC) * 100 }))
  }, [deals, capRateMap])

  // By market averages
  const marketData = useMemo(() => {
    const map: Record<string, number[]> = {}
    filteredDeals.forEach(d => {
      const cr = capRateMap[d.name]?.noi_cap_rate
      if (!cr) return
      const m = shortMarket(d.market || 'Unknown')
      if (!map[m]) map[m] = []
      map[m].push(Number(cr))
    })
    return Object.entries(map)
      .filter(([, v]) => v.length >= 2)
      .map(([market, vals]) => ({
        market,
        avg: vals.reduce((a, b) => a + b, 0) / vals.length,
        count: vals.length,
        min: Math.min(...vals),
        max: Math.max(...vals),
      }))
      .sort((a, b) => a.avg - b.avg)
      .slice(0, 10)
  }, [filteredDeals, capRateMap])

  const totalRates = filteredDeals.filter(d => capRateMap[d.name]?.noi_cap_rate).length
  const allRates = filteredDeals.map(d => capRateMap[d.name]?.noi_cap_rate).filter(Boolean).map(Number)
  const avgRate = allRates.length ? allRates.reduce((a, b) => a + b, 0) / allRates.length : 0
  const medianRate = allRates.length ? [...allRates].sort((a,b)=>a-b)[Math.floor(allRates.length/2)] : 0

  return (
    <div style={darkCard}>
      <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(232,160,32,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={sectionLabel('rgba(232,160,32,0.55)')}>Underwriting Intelligence</div>
          <div style={darkCardTitle}>Cap Rate Distribution</div>
        </div>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <div style={{ display: 'flex', gap: 4, marginRight: 6, paddingRight: 10, borderRight: '1px solid rgba(232,160,32,0.15)' }}>
            {(['all', '2024', '2025', '2026'] as const).map(y => (
              <button key={y} onClick={() => setYearFilter(y)} style={{
                padding: '4px 10px', borderRadius: 5,
                border: `1px solid rgba(232,160,32,${yearFilter === y ? '0.5' : '0.1'})`,
                background: yearFilter === y ? 'rgba(232,160,32,0.15)' : 'transparent',
                color: yearFilter === y ? SBI_ORANGE : 'rgba(245,244,239,0.3)',
                fontSize: 10, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.05em'
              }}>{y === 'all' ? 'All' : y}</button>
            ))}
          </div>
          {(['dist', 'market'] as const).map(v => (
            <button key={v} onClick={() => setView(v)} style={{
              padding: '4px 10px', borderRadius: 5,
              border: `1px solid rgba(232,160,32,${view === v ? '0.5' : '0.15'})`,
              background: view === v ? 'rgba(232,160,32,0.15)' : 'transparent',
              color: view === v ? SBI_ORANGE : 'rgba(245,244,239,0.4)',
              fontSize: 10, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.05em'
            }}>{v === 'dist' ? 'Distribution' : 'By Market'}</button>
          ))}
        </div>
      </div>
      <div style={{ padding: '18px 20px' }}>
        {/* Summary strip */}
        <div style={{ display: 'flex', gap: 24, marginBottom: 20, paddingBottom: 16, borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
          {[
            { label: 'Deals Underwritten', value: totalRates.toLocaleString() },
            { label: 'Avg BOE Cap Rate', value: avgRate ? `${avgRate.toFixed(2)}%` : '—' },
            { label: 'Median Cap Rate', value: medianRate ? `${medianRate.toFixed(2)}%` : '—' },
          ].map(s => (
            <div key={s.label}>
              <div style={{ fontSize: 9, color: 'rgba(232,160,32,0.5)', letterSpacing: '0.12em', textTransform: 'uppercase' }}>{s.label}</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: CREAM, fontFamily: "'Cormorant Garamond',serif" }}>{s.value}</div>
            </div>
          ))}
        </div>

        {view === 'dist' ? (
          <div>
            {distData.map((b, i) => (
              <div key={b.label} style={{ display: 'grid', gridTemplateColumns: '72px 1fr 36px', gap: 10, alignItems: 'center', marginBottom: 8 }}>
                <div style={{ fontSize: 10, color: 'rgba(245,244,239,0.5)', fontFamily: "'DM Mono',monospace", textAlign: 'right' }}>{b.label}%</div>
                <div style={{ background: 'rgba(255,255,255,0.06)', borderRadius: 3, height: 20, overflow: 'hidden' }}>
                  <div style={{ width: `${b.pct}%`, height: '100%', background: b.pct > 60 ? SBI_ORANGE : 'rgba(201,168,76,0.5)', borderRadius: 3, transition: 'width 0.3s' }} />
                </div>
                <div style={{ fontSize: 11, fontWeight: 700, color: b.count > 0 ? CREAM : 'rgba(245,244,239,0.2)', fontFamily: "'DM Mono',monospace", textAlign: 'right' }}>{b.count}</div>
              </div>
            ))}
            <div style={{ marginTop: 12, fontSize: 9, color: 'rgba(245,244,239,0.2)' }}>All BOE underwritten deals · NOI cap rate (adj)</div>
          </div>
        ) : (
          <div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 70px 70px 70px 40px', gap: 8, marginBottom: 8 }}>
              {['Market','Avg','Min','Max','#'].map(h => (
                <div key={h} style={{ fontSize: 8, fontWeight: 700, color: 'rgba(232,160,32,0.4)', letterSpacing: '0.15em', textTransform: 'uppercase', textAlign: h==='Market'?'left':'right' }}>{h}</div>
              ))}
            </div>
            {marketData.map((m, i) => (
              <div key={m.market} style={{ display: 'grid', gridTemplateColumns: '1fr 70px 70px 70px 40px', gap: 8, padding: '8px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div style={{ width: 5, height: 5, borderRadius: 1, background: CHART_COLORS[i % CHART_COLORS.length], flexShrink: 0 }} />
                  <span style={{ fontSize: 11, color: CREAM }}>{m.market}</span>
                </div>
                <div style={{ fontSize: 12, fontWeight: 700, color: SBI_ORANGE, textAlign: 'right', fontFamily: "'DM Mono',monospace" }}>{m.avg.toFixed(2)}%</div>
                <div style={{ fontSize: 11, color: 'rgba(245,244,239,0.4)', textAlign: 'right', fontFamily: "'DM Mono',monospace" }}>{m.min.toFixed(2)}%</div>
                <div style={{ fontSize: 11, color: 'rgba(245,244,239,0.4)', textAlign: 'right', fontFamily: "'DM Mono',monospace" }}>{m.max.toFixed(2)}%</div>
                <div style={{ fontSize: 11, color: 'rgba(245,244,239,0.3)', textAlign: 'right', fontFamily: "'DM Mono',monospace" }}>{m.count}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

// ── 3. Pricing Trends ─────────────────────────────────────────────────────────
function PricingTrends({ deals }: { deals: Deal[] }) {
  const [metric, setMetric] = useState<'ppu' | 'price'>('ppu')

  const byYear = useMemo(() => {
    const map: Record<string, number[]> = {}
    deals.filter(d => d.added && (metric === 'ppu' ? d.price_per_unit : d.purchase_price)).forEach(d => {
      const yr = d.added!.slice(0, 4)
      if (!map[yr]) map[yr] = []
      map[yr].push(metric === 'ppu' ? d.price_per_unit! : d.purchase_price!)
    })
    return Object.entries(map)
      .filter(([yr]) => ['2022','2023','2024','2025','2026'].includes(yr))
      .map(([yr, vals]) => {
        const sorted = [...vals].sort((a, b) => a - b)
        const avg = vals.reduce((a, b) => a + b, 0) / vals.length
        const p25 = sorted[Math.floor(sorted.length * 0.25)]
        const p75 = sorted[Math.floor(sorted.length * 0.75)]
        const median = sorted[Math.floor(sorted.length * 0.5)]
        return { yr, avg, median, p25, p75, count: vals.length }
      })
      .sort((a, b) => a.yr.localeCompare(b.yr))
  }, [deals, metric])

  const maxVal = Math.max(...byYear.map(d => d.p75 || d.avg)) * 1.1 || 1
  const fmt = (v: number) => metric === 'ppu'
    ? `$${(v / 1000).toFixed(0)}K`
    : fmtShort(v)

  // Distribution buckets for current year
  const dist2026 = useMemo(() => {
    const vals = deals
      .filter(d => d.added?.startsWith('2026') && (metric === 'ppu' ? d.price_per_unit : d.purchase_price))
      .map(d => metric === 'ppu' ? d.price_per_unit! : d.purchase_price!)
    if (!vals.length) return []
    const min = Math.min(...vals), max = Math.max(...vals)
    const buckets = 8
    const size = (max - min) / buckets
    const counts = Array(buckets).fill(0)
    vals.forEach(v => {
      const i = Math.min(Math.floor((v - min) / size), buckets - 1)
      counts[i]++
    })
    const maxC = Math.max(...counts)
    return counts.map((c, i) => ({
      label: fmt(min + i * size),
      count: c,
      pct: maxC > 0 ? (c / maxC) * 100 : 0
    }))
  }, [deals, metric])

  return (
    <div style={card}>
      <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.06)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={sectionLabel()}>Pricing Intelligence</div>
          <div style={cardTitle}>Pricing Trends</div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['ppu', 'price'] as const).map(m => (
            <button key={m} onClick={() => setMetric(m)} style={{
              padding: '4px 10px', borderRadius: 5, border: '1px solid rgba(13,27,46,0.12)',
              background: metric === m ? NAVY : '#fff',
              color: metric === m ? SBI_ORANGE : MUTED,
              fontSize: 10, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.05em'
            }}>{m === 'ppu' ? '$/Unit' : 'Total Price'}</button>
          ))}
        </div>
      </div>
      <div style={{ padding: '18px 20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        {/* Year over year */}
        <div>
          <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 14 }}>Year-over-Year Avg</div>
          {byYear.map((yr, i) => (
            <div key={yr.yr} style={{ marginBottom: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span style={{ fontSize: 11, fontWeight: 600, color: NAVY }}>{yr.yr}</span>
                <div style={{ display: 'flex', gap: 8 }}>
                  <span style={{ fontSize: 10, color: MUTED }}>{yr.count} deals</span>
                  <span style={{ fontSize: 11, fontWeight: 700, color: NAVY, fontFamily: "'DM Mono',monospace" }}>{fmt(yr.avg)}</span>
                </div>
              </div>
              {/* IQR bar */}
              <div style={{ position: 'relative', height: 8, background: 'rgba(13,27,46,0.05)', borderRadius: 4 }}>
                <div style={{
                  position: 'absolute',
                  left: `${(yr.p25 / maxVal) * 100}%`,
                  width: `${((yr.p75 - yr.p25) / maxVal) * 100}%`,
                  height: '100%',
                  background: i === byYear.length - 1 ? SBI_ORANGE : `rgba(232,160,32,${0.3 + i * 0.15})`,
                  borderRadius: 4,
                }} />
                <div style={{
                  position: 'absolute',
                  left: `${(yr.median / maxVal) * 100}%`,
                  width: 2, height: '100%',
                  background: NAVY, borderRadius: 1,
                }} />
              </div>
            </div>
          ))}
          <div style={{ marginTop: 8, fontSize: 9, color: MUTED }}>Bar = 25th–75th pct · Line = median</div>
        </div>

        {/* 2026 distribution */}
        <div>
          <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 14 }}>2026 Distribution</div>
          {dist2026.length === 0 ? (
            <div style={{ color: MUTED, fontSize: 12 }}>No 2026 data</div>
          ) : (
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 100 }}>
              {dist2026.map((b, i) => (
                <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
                  <div style={{
                    width: '100%', background: SBI_ORANGE, borderRadius: '3px 3px 0 0',
                    height: `${b.pct}%`, minHeight: b.count > 0 ? 4 : 0,
                    opacity: 0.7 + (b.pct / 200),
                  }} />
                  {b.count > 0 && <div style={{ fontSize: 8, color: NAVY, fontWeight: 700 }}>{b.count}</div>}
                </div>
              ))}
            </div>
          )}
          {dist2026.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
              <span style={{ fontSize: 8, color: MUTED }}>{dist2026[0]?.label}</span>
              <span style={{ fontSize: 8, color: MUTED }}>{dist2026[dist2026.length - 1]?.label}+</span>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ── 4. Vintage & Asset Profile ────────────────────────────────────────────────
function VintageProfile({ deals, capRateMap }: { deals: Deal[]; capRateMap: Record<string, CapRate> }) {
  const [yearFilter, setYearFilter] = useState<'all' | '2025' | '2026'>('all')

  const filtered = useMemo(() =>
    yearFilter === 'all' ? deals : deals.filter(d => d.added?.startsWith(yearFilter))
  , [deals, yearFilter])

  const vintageData = useMemo(() => {
    const buckets: Record<string, { count: number; capRates: number[]; units: number[] }> = {
      'Pre-1970': { count: 0, capRates: [], units: [] },
      '1970–1979': { count: 0, capRates: [], units: [] },
      '1980–1989': { count: 0, capRates: [], units: [] },
      '1990–1999': { count: 0, capRates: [], units: [] },
      '2000–2009': { count: 0, capRates: [], units: [] },
      '2010–2019': { count: 0, capRates: [], units: [] },
      '2020+': { count: 0, capRates: [], units: [] },
    }
    filtered.filter(d => d.year_built).forEach(d => {
      const yr = d.year_built!
      const key = yr < 1970 ? 'Pre-1970' : yr < 1980 ? '1970–1979' : yr < 1990 ? '1980–1989'
        : yr < 2000 ? '1990–1999' : yr < 2010 ? '2000–2009' : yr < 2020 ? '2010–2019' : '2020+'
      buckets[key].count++
      const cr = capRateMap[d.name]
      if (cr?.noi_cap_rate) buckets[key].capRates.push(Number(cr.noi_cap_rate))
      if (d.units) buckets[key].units.push(d.units)
    })
    return Object.entries(buckets).map(([era, v]) => ({
      era,
      count: v.count,
      avgCapRate: v.capRates.length ? v.capRates.reduce((a, b) => a + b, 0) / v.capRates.length : null,
      avgUnits: v.units.length ? Math.round(v.units.reduce((a, b) => a + b, 0) / v.units.length) : null,
    })).filter(v => v.count > 0)
  }, [filtered, capRateMap])

  const unitSizes = useMemo(() => {
    const buckets = { 'Under 100': 0, '100–199': 0, '200–299': 0, '300–399': 0, '400+': 0 }
    filtered.filter(d => d.units).forEach(d => {
      const u = d.units!
      if (u < 100) buckets['Under 100']++
      else if (u < 200) buckets['100–199']++
      else if (u < 300) buckets['200–299']++
      else if (u < 400) buckets['300–399']++
      else buckets['400+']++
    })
    const max = Math.max(...Object.values(buckets))
    return Object.entries(buckets).map(([label, count]) => ({ label, count, pct: max > 0 ? (count / max) * 100 : 0 }))
  }, [filtered])

  const maxVintage = Math.max(...vintageData.map(v => v.count))

  return (
    <div style={card}>
      <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.06)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={sectionLabel()}>Asset Intelligence</div>
          <div style={cardTitle}>Vintage & Asset Profile</div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['all', '2025', '2026'] as const).map(y => (
            <button key={y} onClick={() => setYearFilter(y)} style={{
              padding: '4px 10px', borderRadius: 5, border: '1px solid rgba(13,27,46,0.12)',
              background: yearFilter === y ? NAVY : '#fff',
              color: yearFilter === y ? SBI_ORANGE : MUTED,
              fontSize: 10, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.05em'
            }}>{y === 'all' ? 'All Time' : y}</button>
          ))}
        </div>
      </div>
      <div style={{ padding: '18px 20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28 }}>
        <div>
          <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 14 }}>By Build Era</div>
          {vintageData.map((v, i) => (
            <HorizBar
              key={v.era} label={v.era} value={v.count} max={maxVintage}
              color={CHART_COLORS[i % CHART_COLORS.length]}
              sub={v.avgCapRate ? `${v.avgCapRate.toFixed(2)}% avg cap` : undefined}
            />
          ))}
        </div>
        <div>
          <div style={{ fontSize: 10, fontWeight: 700, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 14 }}>By Unit Count</div>
          {unitSizes.map((u, i) => (
            <HorizBar key={u.label} label={u.label} value={u.count} max={unitSizes[0]?.count || 1} color={CHART_COLORS[i % CHART_COLORS.length]} />
          ))}

        </div>
      </div>
    </div>
  )
}

// ── 5. BOE Benchmarking ───────────────────────────────────────────────────────
function BoeBenchmarking({ deals, boeMap, capRateMap }: { deals: Deal[]; boeMap: Record<string, BoeData>; capRateMap: Record<string, CapRate> }) {
  const byMarket = useMemo(() => {
    const map: Record<string, { noicaps: number[]; brokercaps: number[]; deltas: number[] }> = {}
    deals.forEach(d => {
      const cr = capRateMap[d.name]
      if (!cr) return
      const m = shortMarket(d.market || 'Unknown')
      if (!map[m]) map[m] = { noicaps: [], brokercaps: [], deltas: [] }
      if (cr.noi_cap_rate) map[m].noicaps.push(Number(cr.noi_cap_rate))
      if (cr.broker_cap_rate) map[m].brokercaps.push(Number(cr.broker_cap_rate))
      if (cr.noi_cap_rate && cr.broker_cap_rate) {
        map[m].deltas.push(Number(cr.noi_cap_rate) - Number(cr.broker_cap_rate))
      }
    })
    return Object.entries(map)
      .map(([market, v]) => ({
        market,
        avgNoi: v.noicaps.length ? v.noicaps.reduce((a, b) => a + b, 0) / v.noicaps.length : null,
        avgBroker: v.brokercaps.length ? v.brokercaps.reduce((a, b) => a + b, 0) / v.brokercaps.length : null,
        avgDelta: v.deltas.length ? v.deltas.reduce((a, b) => a + b, 0) / v.deltas.length : null,
        count: Math.max(v.noicaps.length, v.brokercaps.length),
      }))
      .filter(v => v.count >= 2)
      .sort((a, b) => b.count - a.count)
      .slice(0, 8)
  }, [deals, capRateMap])

  const totalBoe = Object.keys(boeMap).length
  const allNoiCaps = Object.values(capRateMap).filter(c => c.noi_cap_rate).map(c => Number(c.noi_cap_rate))
  const avgNoi = allNoiCaps.length ? allNoiCaps.reduce((a, b) => a + b, 0) / allNoiCaps.length : 0

  return (
    <div style={darkCard}>
      <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(232,160,32,0.1)' }}>
        <div style={sectionLabel('rgba(232,160,32,0.55)')}>Underwriting Intelligence</div>
        <div style={darkCardTitle}>BOE Benchmarking by Market</div>
      </div>
      <div style={{ padding: '18px 20px' }}>
        {/* Summary strip */}
        <div style={{ display: 'flex', gap: 20, marginBottom: 20, paddingBottom: 16, borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
          {[
            { label: 'BOEs Underwritten', value: totalBoe.toLocaleString() },
            { label: 'Avg NOI Cap Rate', value: avgNoi ? `${avgNoi.toFixed(2)}%` : '—' },
            { label: 'Markets w/ BOE', value: byMarket.length.toString() },
          ].map(s => (
            <div key={s.label}>
              <div style={{ fontSize: 9, color: 'rgba(232,160,32,0.5)', letterSpacing: '0.12em', textTransform: 'uppercase' }}>{s.label}</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: CREAM, fontFamily: "'Cormorant Garamond',serif" }}>{s.value}</div>
            </div>
          ))}
        </div>

        {/* Column headers */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 80px 80px 70px 50px', gap: 8, marginBottom: 8 }}>
          {['Market', 'BOE Cap', 'Broker Cap', 'Delta', 'Deals'].map(h => (
            <div key={h} style={{ fontSize: 8, fontWeight: 700, color: 'rgba(232,160,32,0.4)', letterSpacing: '0.15em', textTransform: 'uppercase', textAlign: h === 'Market' ? 'left' : 'right' }}>{h}</div>
          ))}
        </div>

        {byMarket.length === 0 ? (
          <div style={{ color: 'rgba(245,244,239,0.3)', fontSize: 12, padding: '16px 0' }}>No BOE data yet</div>
        ) : byMarket.map((m, i) => (
          <div key={m.market} style={{
            display: 'grid', gridTemplateColumns: '1fr 80px 80px 70px 50px', gap: 8,
            padding: '9px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 5, height: 5, borderRadius: 1, background: CHART_COLORS[i % CHART_COLORS.length], flexShrink: 0 }} />
              <span style={{ fontSize: 11, color: CREAM, fontWeight: 500 }}>{m.market}</span>
            </div>
            <div style={{ fontSize: 12, fontWeight: 700, color: SBI_ORANGE, textAlign: 'right', fontFamily: "'DM Mono',monospace" }}>
              {m.avgNoi ? `${m.avgNoi.toFixed(2)}%` : '—'}
            </div>
            <div style={{ fontSize: 12, color: 'rgba(245,244,239,0.5)', textAlign: 'right', fontFamily: "'DM Mono',monospace" }}>
              {m.avgBroker ? `${m.avgBroker.toFixed(2)}%` : '—'}
            </div>
            <div style={{ fontSize: 11, fontWeight: 700, textAlign: 'right', fontFamily: "'DM Mono',monospace",
              color: m.avgDelta == null ? MUTED : m.avgDelta > 0 ? '#2E7D50' : '#C0392B' }}>
              {m.avgDelta != null ? `${m.avgDelta >= 0 ? '+' : ''}${m.avgDelta.toFixed(2)}%` : '—'}
            </div>
            <div style={{ fontSize: 11, color: 'rgba(245,244,239,0.35)', textAlign: 'right', fontFamily: "'DM Mono',monospace" }}>{m.count}</div>
          </div>
        ))}
        <div style={{ marginTop: 10, fontSize: 9, color: 'rgba(245,244,239,0.2)' }}>
          Delta = BOE cap rate minus broker-quoted cap rate. Positive = you underwrote higher than guidance.
        </div>
      </div>
    </div>
  )
}

// ── 7. Market Comp Tracker ────────────────────────────────────────────────────
function MarketCompTracker({ deals, capRateMap }: { deals: Deal[]; capRateMap: Record<string, CapRate> }) {
  const [marketFilter, setMarketFilter] = useState('all')
  const [search, setSearch] = useState('')

  const soldDeals = useMemo(() =>
    deals
      .filter(d => d.sold_price && d.purchase_price)
      .map(d => ({
        ...d,
        delta: d.sold_price! - d.purchase_price!,
        deltaPct: ((d.sold_price! - d.purchase_price!) / d.purchase_price!) * 100,
        market: shortMarket(d.market || 'Unknown'),
        cr: capRateMap[d.name],
      }))
      .sort((a, b) => new Date(b.modified).getTime() - new Date(a.modified).getTime())
  , [deals, capRateMap])

  const markets = useMemo(() => ['all', ...Array.from(new Set(soldDeals.map(d => d.market)))], [soldDeals])

  const filtered = useMemo(() => {
    let d = marketFilter === 'all' ? soldDeals : soldDeals.filter(x => x.market === marketFilter)
    if (search.trim()) {
      const q = search.toLowerCase()
      d = d.filter(x => x.name.toLowerCase().includes(q) || x.market?.toLowerCase().includes(q) || x.seller?.toLowerCase().includes(q) || x.buyer?.toLowerCase().includes(q))
    }
    return d
  }, [soldDeals, marketFilter, search])

  const avgDelta = filtered.length ? filtered.reduce((s, d) => s + d.deltaPct, 0) / filtered.length : 0
  const above = filtered.filter(d => d.delta > 0).length
  const below = filtered.filter(d => d.delta < 0).length

  return (
    <div style={card}>
      <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(13,27,46,0.06)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={sectionLabel()}>Transaction Intelligence</div>
          <div style={cardTitle}>Market Comp Tracker</div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input
            value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search deals, sellers, buyers…"
            style={{ padding: '5px 10px', borderRadius: 6, border: '1px solid rgba(13,27,46,0.12)', fontSize: 11, color: NAVY, fontFamily: "'DM Sans',sans-serif", outline: 'none', width: 220 }}
          />
          <select value={marketFilter} onChange={e => setMarketFilter(e.target.value)} style={{
            padding: '5px 10px', borderRadius: 6, border: '1px solid rgba(13,27,46,0.12)',
            fontSize: 11, color: NAVY, background: '#fff', fontFamily: "'DM Sans',sans-serif", cursor: 'pointer'
          }}>
            {markets.map(m => <option key={m} value={m}>{m === 'all' ? 'All Markets' : m}</option>)}
          </select>
        </div>
      </div>

      {/* Summary row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', borderBottom: '1px solid rgba(13,27,46,0.05)' }}>
        {[
          { label: 'Comps Tracked', value: filtered.length.toString() },
          { label: 'Avg vs Guidance', value: filtered.length ? `${avgDelta >= 0 ? '+' : ''}${avgDelta.toFixed(1)}%` : '—', color: avgDelta >= 0 ? '#2E7D50' : '#C0392B' },
          { label: 'Cleared Above', value: above.toString(), color: '#2E7D50' },
          { label: 'Cleared Below', value: below.toString(), color: '#C0392B' },
        ].map(s => (
          <div key={s.label} style={{ padding: '12px 16px', borderRight: '1px solid rgba(13,27,46,0.05)' }}>
            <div style={{ fontSize: 9, color: MUTED, letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 3 }}>{s.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, color: s.color || NAVY, fontFamily: "'Cormorant Garamond',serif" }}>{s.value}</div>
          </div>
        ))}
      </div>

      {/* Table */}
      <div style={{ overflowX: 'auto' }}>
        {filtered.length === 0 ? (
          <div style={{ padding: 24, color: MUTED, fontSize: 12, textAlign: 'center' }}>
            No closed deals with both guidance and sold price yet
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
            <thead>
              <tr style={{ background: NAVY }}>
                {['Deal', 'Market', 'Guidance', 'Sold', 'Delta', 'Seller', 'Buyer', 'Yr 1 Cap (Adj)', 'Updated'].map(h => (
                  <th key={h} style={{ padding: '8px 14px', textAlign: 'left', color: SBI_ORANGE, fontSize: 9, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.slice(0, 50).map((d, i) => {
                const isRecent = d.modified && (Date.now() - new Date(d.modified).getTime()) < 7 * 24 * 60 * 60 * 1000
                return (
                  <tr key={d.id} style={{ borderBottom: '1px solid rgba(13,27,46,0.05)', background: isRecent ? 'rgba(201,168,76,0.08)' : i % 2 === 0 ? '#fff' : 'rgba(13,27,46,0.01)', transition: 'background 0.2s' }}>
                    <td style={{ padding: '8px 14px', fontWeight: 600, color: NAVY, maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        {isRecent && <span style={{ fontSize: 8, fontWeight: 800, color: '#8A6500', background: 'rgba(201,168,76,0.2)', padding: '1px 5px', borderRadius: 3, letterSpacing: '0.1em', flexShrink: 0 }}>NEW</span>}
                        {d.name}
                      </div>
                    </td>
                    <td style={{ padding: '8px 14px', color: MUTED, whiteSpace: 'nowrap' }}>{d.market}</td>
                    <td style={{ padding: '8px 14px', color: MUTED, fontFamily: "'DM Mono',monospace" }}>{fmtShort(d.purchase_price)}</td>
                    <td style={{ padding: '8px 14px', color: NAVY, fontWeight: 600, fontFamily: "'DM Mono',monospace" }}>{fmtShort(d.sold_price)}</td>
                    <td style={{ padding: '8px 14px', fontWeight: 700, fontFamily: "'DM Mono',monospace", color: d.delta > 0 ? '#2E7D50' : '#C0392B', whiteSpace: 'nowrap' }}>
                      {d.delta >= 0 ? '+' : ''}{fmtShort(d.delta)} ({d.deltaPct >= 0 ? '+' : ''}{d.deltaPct.toFixed(1)}%)
                    </td>
                    <td style={{ padding: '8px 14px', color: MUTED, maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.seller || '—'}</td>
                    <td style={{ padding: '8px 14px', color: MUTED, maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.buyer || '—'}</td>
                    <td style={{ padding: '8px 14px', fontWeight: 600, fontFamily: "'DM Mono',monospace", color: NAVY, whiteSpace: 'nowrap' }}>
                      {d.cr?.noi_cap_rate ? `${Number(d.cr.noi_cap_rate).toFixed(2)}%` : ''}
                    </td>
                    <td style={{ padding: '8px 14px', color: MUTED, whiteSpace: 'nowrap', fontSize: 11 }}>{d.modified ? new Date(d.modified).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: '2-digit' }) : '—'}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

// ── Main Export ───────────────────────────────────────────────────────────────
export default function AnalyticsPage({ deals, boeMap, capRateMap }: Props) {
  return (
    <div style={{ padding: '24px 28px', background: '#EEEDE7', minHeight: '100%' }}>
      {/* Header */}
      <div style={{ marginBottom: 24 }}>
        <div style={{ fontSize: 9, fontWeight: 700, color: SBI_ORANGE, letterSpacing: '0.2em', textTransform: 'uppercase', marginBottom: 4 }}>StoneBridge Investments</div>
        <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 28, fontWeight: 700, color: NAVY }}>Pipeline Analytics</div>
        <div style={{ fontSize: 12, color: MUTED, marginTop: 3 }}>{deals.length.toLocaleString()} deals · {Object.keys(boeMap).length} underwritten · {Object.keys(capRateMap).length} cap rates tracked</div>
      </div>

      {/* Row 1: Market Intelligence + Cap Rate Distribution */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
        <MarketIntelligence deals={deals} />
        <CapRateDistribution deals={deals} capRateMap={capRateMap} />
      </div>

      {/* Row 2: Pricing Trends + Vintage Profile */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
        <PricingTrends deals={deals} />
        <VintageProfile deals={deals} capRateMap={capRateMap} />
      </div>

      {/* Row 3: Market Comp Tracker — full width */}
      <div style={{ marginBottom: 16 }}>
        <MarketCompTracker deals={deals} capRateMap={capRateMap} />
      </div>
    </div>
  )
}
