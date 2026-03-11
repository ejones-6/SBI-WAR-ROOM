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
  const [selectedRegion, setSelectedRegion] = useState<string>('All')
  const [sortBy, setSortBy] = useState<'deals' | 'guidance'>('deals')
  const [expandedBroker, setExpandedBroker] = useState<string | null>(null)

  const REGIONS = ['All', 'DC MSA', 'N. Carolina', 'S. Carolina', 'Georgia', 'Texas', 'Nashville', 'Florida', 'Misc']

  const filtered = useMemo(() => {
    if (selectedRegion === 'All') return deals
    return deals.filter(d => {
      const region = getRegion(d.market || '')
      return (REGION_LABELS as any)[region] === selectedRegion
    })
  }, [deals, selectedRegion])

  const brokerStats = useMemo(() => {
    const stats: Record<string, { deals: number; guidance: number; markets: Record<string, number>; regions: Record<string, number> }> = {}
    filtered.forEach(d => {
      if (!d.broker) return
      const b = d.broker.trim()
      if (!stats[b]) stats[b] = { deals: 0, guidance: 0, markets: {}, regions: {} }
      stats[b].deals++
      if (d.purchase_price) stats[b].guidance += d.purchase_price
      const mkt = d.market || 'Unknown'
      stats[b].markets[mkt] = (stats[b].markets[mkt] || 0) + 1
      const region = (REGION_LABELS as any)[getRegion(mkt)] || 'Misc'
      stats[b].regions[region] = (stats[b].regions[region] || 0) + 1
    })
    return Object.entries(stats)
      .map(([name, s]) => ({ name, ...s, topMarkets: Object.entries(s.markets).sort((a,b) => b[1]-a[1]).slice(0, 5), topRegions: Object.entries(s.regions).sort((a,b) => b[1]-a[1]) }))
      .sort((a, b) => sortBy === 'deals' ? b.deals - a.deals : b.guidance - a.guidance)
      .slice(0, 10)
  }, [filtered, sortBy])

  const maxDeals = brokerStats[0]?.deals || 1
  const maxGuidance = brokerStats[0]?.guidance || 1

  const fmtG = (n: number) => n >= 1e9 ? `$${(n/1e9).toFixed(1)}B` : `$${(n/1e6).toFixed(0)}M`

  return (
    <div style={{ background: '#0D1B2E', borderRadius: 12, border: '1px solid rgba(201,168,76,0.15)', overflow: 'hidden', marginBottom: 16 }}>
      {/* Header */}
      <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(201,168,76,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <div style={{ fontSize: 9, fontWeight: 700, color: 'rgba(201,168,76,0.55)', letterSpacing: '0.2em', textTransform: 'uppercase' }}>Intelligence</div>
          <div style={{ fontSize: 15, fontWeight: 700, color: '#F5F4EF', fontFamily: "'Cormorant Garamond',serif", marginTop: 1 }}>Broker Leaderboard</div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          {/* Sort toggle */}
          <div style={{ display: 'flex', background: 'rgba(255,255,255,0.05)', borderRadius: 6, padding: 2, border: '1px solid rgba(201,168,76,0.12)' }}>
            {(['deals', 'guidance'] as const).map(s => (
              <button key={s} onClick={() => setSortBy(s)} style={{ padding: '4px 12px', borderRadius: 4, border: 'none', background: sortBy === s ? 'rgba(201,168,76,0.2)' : 'transparent', color: sortBy === s ? '#C9A84C' : 'rgba(245,244,239,0.4)', fontSize: 10, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.06em', textTransform: 'uppercase' }}>
                {s === 'deals' ? '# Deals' : 'Guidance $'}
              </button>
            ))}
          </div>
          {/* Region filter */}
          <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
            {REGIONS.map(r => (
              <button key={r} onClick={() => setSelectedRegion(r)} style={{ padding: '4px 10px', borderRadius: 4, border: '1px solid', borderColor: selectedRegion === r ? '#C9A84C' : 'rgba(201,168,76,0.15)', background: selectedRegion === r ? 'rgba(201,168,76,0.15)' : 'transparent', color: selectedRegion === r ? '#C9A84C' : 'rgba(245,244,239,0.4)', fontSize: 9, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.06em', textTransform: 'uppercase' as const }}>
                {r}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Table */}
      <div>
        {/* Column headers */}
        <div style={{ display: 'grid', gridTemplateColumns: '28px 160px 1fr 100px 120px 160px', gap: 0, padding: '8px 20px', borderBottom: '1px solid rgba(201,168,76,0.08)' }}>
          {['#', 'Broker', 'Deal Volume', 'Deals', 'Guidance', 'Top Markets'].map(h => (
            <div key={h} style={{ fontSize: 8, fontWeight: 700, color: 'rgba(201,168,76,0.45)', letterSpacing: '0.15em', textTransform: 'uppercase' }}>{h}</div>
          ))}
        </div>

        {brokerStats.length === 0 ? (
          <div style={{ padding: '24px 20px', color: 'rgba(255,255,255,0.3)', fontSize: 12 }}>No broker data for this region</div>
        ) : brokerStats.map((broker, idx) => {
          const barWidth = sortBy === 'deals' ? (broker.deals / maxDeals) * 100 : (broker.guidance / maxGuidance) * 100
          const color = BROKER_COLORS[idx % BROKER_COLORS.length]
          const isExpanded = expandedBroker === broker.name
          return (
            <div key={broker.name}>
              <div
                onClick={() => setExpandedBroker(isExpanded ? null : broker.name)}
                style={{ display: 'grid', gridTemplateColumns: '28px 160px 1fr 100px 120px 160px', gap: 0, padding: '12px 20px', borderBottom: '1px solid rgba(201,168,76,0.06)', cursor: 'pointer', alignItems: 'center', transition: 'background 0.1s', background: isExpanded ? 'rgba(201,168,76,0.06)' : 'transparent' }}
                onMouseEnter={e => { if (!isExpanded) e.currentTarget.style.background = 'rgba(255,255,255,0.03)' }}
                onMouseLeave={e => { if (!isExpanded) e.currentTarget.style.background = 'transparent' }}
              >
                {/* Rank */}
                <div style={{ fontSize: 11, fontWeight: 700, color: idx < 3 ? '#C9A84C' : 'rgba(245,244,239,0.25)' }}>#{idx+1}</div>

                {/* Broker name */}
                <div style={{ fontSize: 13, fontWeight: 600, color: '#F5F4EF', display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div style={{ width: 6, height: 6, borderRadius: 2, background: color, flexShrink: 0 }} />
                  {broker.name}
                </div>

                {/* Bar */}
                <div style={{ paddingRight: 16 }}>
                  <div style={{ height: 6, background: 'rgba(255,255,255,0.06)', borderRadius: 3, overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: `${barWidth}%`, background: color, borderRadius: 3, transition: 'width 0.4s ease', opacity: 0.8 }} />
                  </div>
                </div>

                {/* Deal count */}
                <div style={{ fontSize: 13, fontWeight: 700, color: '#C9A84C', fontFamily: "'DM Mono',monospace" }}>{broker.deals}</div>

                {/* Guidance */}
                <div style={{ fontSize: 12, color: 'rgba(245,244,239,0.6)', fontFamily: "'DM Mono',monospace" }}>{fmtG(broker.guidance)}</div>

                {/* Top markets */}
                <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                  {broker.topMarkets.slice(0,3).map(([mkt, cnt]) => (
                    <span key={mkt} style={{ fontSize: 9, background: 'rgba(201,168,76,0.1)', color: '#C9A84C', borderRadius: 3, padding: '2px 6px', whiteSpace: 'nowrap' }}>
                      {shortMarket(mkt)} <span style={{ opacity: 0.6 }}>({cnt})</span>
                    </span>
                  ))}
                </div>
              </div>

              {/* Expanded market breakdown */}
              {isExpanded && (
                <div style={{ padding: '14px 60px 16px', borderBottom: '1px solid rgba(201,168,76,0.08)', background: 'rgba(201,168,76,0.03)' }}>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
                    {/* By Market */}
                    <div>
                      <div style={{ fontSize: 8, fontWeight: 700, color: 'rgba(201,168,76,0.5)', letterSpacing: '0.15em', textTransform: 'uppercase', marginBottom: 10 }}>All Markets</div>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                        {broker.topMarkets.map(([mkt, cnt]) => {
                          const pct = (cnt / broker.deals) * 100
                          return (
                            <div key={mkt}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 3 }}>
                                <span style={{ fontSize: 11, color: 'rgba(245,244,239,0.65)' }}>{shortMarket(mkt)}</span>
                                <span style={{ fontSize: 11, fontWeight: 600, color: '#C9A84C', fontFamily: "'DM Mono',monospace" }}>{cnt} <span style={{ fontSize: 9, opacity: 0.5 }}>({pct.toFixed(0)}%)</span></span>
                              </div>
                              <div style={{ height: 3, background: 'rgba(255,255,255,0.06)', borderRadius: 2 }}>
                                <div style={{ height: '100%', width: `${pct}%`, background: color, borderRadius: 2, opacity: 0.7 }} />
                              </div>
                            </div>
                          )
                        })}
                      </div>
                    </div>
                    {/* By Region */}
                    <div>
                      <div style={{ fontSize: 8, fontWeight: 700, color: 'rgba(201,168,76,0.5)', letterSpacing: '0.15em', textTransform: 'uppercase', marginBottom: 10 }}>By Region</div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                        {broker.topRegions.map(([region, cnt]) => (
                          <div key={region} style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(201,168,76,0.15)', borderRadius: 6, padding: '6px 12px', textAlign: 'center' }}>
                            <div style={{ fontSize: 14, fontWeight: 700, color: '#C9A84C', fontFamily: "'Cormorant Garamond',serif" }}>{cnt}</div>
                            <div style={{ fontSize: 8, color: 'rgba(245,244,239,0.4)', marginTop: 1, letterSpacing: '0.08em' }}>{region}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Footer */}
      <div style={{ padding: '10px 20px', borderTop: '1px solid rgba(201,168,76,0.08)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontSize: 9, color: 'rgba(245,244,239,0.25)', letterSpacing: '0.06em' }}>
          Click a broker row to expand market breakdown · Showing top 10 of {Object.keys(deals.reduce((a: any, d) => { if(d.broker) a[d.broker]=1; return a }, {})).length} brokers
        </div>
        <div style={{ fontSize: 9, color: 'rgba(245,244,239,0.25)' }}>
          {selectedRegion !== 'All' ? `Filtered: ${selectedRegion}` : `${filtered.length} total deals`}
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
      // Try multiple CORS proxies + direct in parallel, take first success
      const SYMBOLS = ['^TNX', '^FVX', '^IRX', '^GSPC', '^DJI', 'BTC-USD', 'AVB', 'EQR', 'MAA', 'ESS']
      const yahooUrl = `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${encodeURIComponent(SYMBOLS.join(','))}&fields=regularMarketPrice,regularMarketChange,regularMarketChangePercent`

      function parseYahooResults(results: any[]) {
        const m: Record<string, any> = {}
        for (const r of results) {
          m[r.symbol] = { price: r.regularMarketPrice ?? null, change: r.regularMarketChange ?? null, pct: r.regularMarketChangePercent ?? null }
        }
        const fiveY = m['^FVX']?.price ?? null
        const tenY  = m['^TNX']?.price ?? null
        return {
          sofr:   m['^IRX']    ? { rate: m['^IRX'].price,    change: m['^IRX'].change   } : null,
          fiveY:  m['^FVX']    ? { rate: m['^FVX'].price,    change: m['^FVX'].change   } : null,
          sevenY: (fiveY && tenY) ? { rate: +(fiveY * 0.4 + tenY * 0.6).toFixed(3) }    : null,
          tenY:   m['^TNX']    ? { rate: m['^TNX'].price,    change: m['^TNX'].change   } : null,
          sp500:  m['^GSPC']   ? { price: m['^GSPC'].price,  change: m['^GSPC'].change,  pct: m['^GSPC'].pct  } : null,
          dow:    m['^DJI']    ? { price: m['^DJI'].price,   change: m['^DJI'].change,   pct: m['^DJI'].pct   } : null,
          btc:    m['BTC-USD'] ? { price: m['BTC-USD'].price, change: m['BTC-USD'].change, pct: m['BTC-USD'].pct } : null,
          avb:    m['AVB']     ? { price: m['AVB'].price,    change: m['AVB'].change,    pct: m['AVB'].pct    } : null,
          eqr:    m['EQR']     ? { price: m['EQR'].price,    change: m['EQR'].change,    pct: m['EQR'].pct    } : null,
          maa:    m['MAA']     ? { price: m['MAA'].price,    change: m['MAA'].change,    pct: m['MAA'].pct    } : null,
          ess:    m['ESS']     ? { price: m['ESS'].price,    change: m['ESS'].change,    pct: m['ESS'].pct    } : null,
        }
      }

      async function tryProxy(proxyUrl: string) {
        const r = await fetch(proxyUrl, { signal: AbortSignal.timeout(8000) })
        if (!r.ok) throw new Error(`${r.status}`)
        const wrapper = await r.json()
        const raw = typeof wrapper.contents === 'string' ? JSON.parse(wrapper.contents) : wrapper
        const results: any[] = raw?.quoteResponse?.result ?? []
        if (!results.length) throw new Error('empty')
        return parseYahooResults(results)
      }

      async function tryDirect() {
        const r = await fetch(yahooUrl, { signal: AbortSignal.timeout(6000) })
        if (!r.ok) throw new Error(`${r.status}`)
        const raw = await r.json()
        const results: any[] = raw?.quoteResponse?.result ?? []
        if (!results.length) throw new Error('empty')
        return parseYahooResults(results)
      }

      async function tryServerRoute() {
        const r = await fetch('/api/rates', { signal: AbortSignal.timeout(10000) })
        if (!r.ok) throw new Error(`${r.status}`)
        const d = await r.json()
        if (d.error || !d.sp500) throw new Error('no data')
        return d
      }

      const proxies = [
        'https://api.allorigins.win/get?url=' + encodeURIComponent(yahooUrl),
        'https://corsproxy.io/?' + encodeURIComponent(yahooUrl),
        'https://api.codetabs.com/v1/proxy?quest=' + encodeURIComponent(yahooUrl),
      ]

      // Race all sources — take first winner
      const attempts = [
        tryDirect(),
        ...proxies.map(p => tryProxy(p)),
        tryServerRoute(),
      ]

      try {
        const result = await Promise.any(attempts)
        setRates(result)
      } catch {
        console.warn('All rate sources failed')
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
