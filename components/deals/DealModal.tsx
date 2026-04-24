'use client'
import { useState, useEffect, useRef, useCallback } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, fmtUnit, ALL_STATUSES, REGION_MAP, REGION_LABELS } from '@/lib/utils'
import type { Region } from '@/lib/types'
import BoePanel from '../boe/BoePanel'

interface Props {
  deal: Deal
  boe: BoeData | null
  capRate: CapRate | null
  onClose: () => void
  onSave: (updates: Partial<Deal> & { name: string }) => Promise<any>
  onSaveBoe: (boe: BoeData) => Promise<any>
  onSaveCapRate?: (dealName: string, capAdj: number) => void
}

type Tab = 'details' | 'boe' | 'noi' | 'noi'


// ── NOI Walk + Cap Rate Sensitivity ───────────────────────────────────────────

// ── NOI Walk + Cap Rate Sensitivity ───────────────────────────────────────────
function NoiWalk({ boe, deal, pfValues }: { boe: any; deal: any; pfValues: Record<string,number> }) {
  const NAVY = '#0D1B2E'
  const GOLD = '#C9A84C'

  if (!boe?.t12) return (
    <div style={{ padding:40, textAlign:'center', color:'#8A9BB0', fontFamily:"'DM Sans',sans-serif" }}>
      No BOE data yet — build the BOE first then come back here.
    </div>
  )

  const units = deal.units || 1
  const pp = deal.purchase_price || 0
  const pf = pfValues

  // Grab PF totals directly from BoePanel — no recalculation
  const rrp_pf = pf.rrp_pf ?? 0
  const vac_p  = pf.vac_p  ?? 0
  const bad_p  = pf.bad_p  ?? 0
  const conc_p = pf.conc_p ?? 0
  const mod_p  = pf.mod_p  ?? 0
  const emp_p  = pf.emp_p  ?? 0
  const oi_p   = pf.oi_p   ?? 0
  const egr_p  = pf.egr_p  ?? 0
  const ga_p   = pf.ga_p   ?? 0
  const mkt_p  = pf.mkt_p  ?? 0
  const rm_p   = pf.rm_p   ?? 0
  const pay_p  = pf.pay_p  ?? 0
  const mgt_p  = pf.mgt_p  ?? 0
  const utl_p  = pf.utl_p  ?? 0
  const tax_p  = pf.tax_p  ?? 0
  const taxm_p = pf.taxm_p ?? 0
  const ins_p  = pf.ins_p  ?? 0
  const noi_pf = pf.noi_p  ?? 0

  // T12 NOI for start bar
  const t = boe.t12
  const noi_t12 = t ? (t.gpr+t.ltl+t.vac+t.bad+t.conc+t.mod+t.emp+t.oi) - (t.ga+t.mkt+t.rm+t.pay+t.mgt+t.utl+t.tax+t.taxm+t.ins) : 0

  const fmt = (n: number) => {
    const abs = Math.abs(n)
    if (abs >= 1000000) return `$${(n/1000000).toFixed(2)}M`
    if (abs >= 1000) return `$${Math.round(n/1000)}K`
    return `$${Math.round(n)}`
  }
  const fmtFull = (n: number) => n < 0 ? `-$${Math.abs(Math.round(n)).toLocaleString()}` : `$${Math.round(n).toLocaleString()}`

  // Waterfall — starts at T12 NOI, each bar is the PF delta vs T12 for that item
  const dRRP      = rrp_pf - ((t?.gpr??0)+(t?.ltl??0))
  const dVac      = vac_p  - (t?.vac??0)
  const dBadConc  = (bad_p+conc_p) - ((t?.bad??0)+(t?.conc??0))
  const dModEmp   = (mod_p+emp_p)  - ((t?.mod??0)+(t?.emp??0))
  const dOI       = oi_p   - (t?.oi??0)
  const dGA       = -(ga_p   - (t?.ga??0))
  const dMkt      = -(mkt_p  - (t?.mkt??0))
  const dRM       = -(rm_p   - (t?.rm??0))
  const dPay      = -(pay_p  - (t?.pay??0))
  const dUtlMgt   = -((utl_p+mgt_p) - ((t?.utl??0)+(t?.mgt??0)))
  const dTax      = -((tax_p+taxm_p) - ((t?.tax??0)+(t?.taxm??0)))
  const dIns      = -(ins_p  - (t?.ins??0))

  const bars: { label: string; value: number }[] = [
    { label: 'T12 NOI', value: noi_t12 },
    ...( Math.abs(dRRP)     > 1 ? [{ label: 'RRP',          value: dRRP     }] : [] ),
    ...( Math.abs(dVac)     > 1 ? [{ label: 'Vacancy',      value: dVac     }] : [] ),
    ...( Math.abs(dBadConc) > 1 ? [{ label: 'Bad/Conc',     value: dBadConc }] : [] ),
    ...( Math.abs(dModEmp)  > 1 ? [{ label: 'Mod/Emp',      value: dModEmp  }] : [] ),
    ...( Math.abs(dOI)      > 1 ? [{ label: 'Other Inc.',   value: dOI      }] : [] ),
    ...( Math.abs(dGA)      > 1 ? [{ label: 'G&A',          value: dGA      }] : [] ),
    ...( Math.abs(dMkt)     > 1 ? [{ label: 'Marketing',    value: dMkt     }] : [] ),
    ...( Math.abs(dRM)      > 1 ? [{ label: 'R&M',          value: dRM      }] : [] ),
    ...( Math.abs(dPay)     > 1 ? [{ label: 'Payroll',      value: dPay     }] : [] ),
    ...( Math.abs(dUtlMgt)  > 1 ? [{ label: 'Utl/Mgmt',    value: dUtlMgt  }] : [] ),
    ...( Math.abs(dTax)     > 1 ? [{ label: 'Tax',          value: dTax     }] : [] ),
    ...( Math.abs(dIns)     > 1 ? [{ label: 'Insurance',    value: dIns     }] : [] ),
    { label: 'PF NOI', value: noi_pf },
  ]

  // Chart setup
  const barW = 54, gap = 8, padL = 58, padR = 16, padT = 30, padB = 44, chartH = 200
  const totalW = padL + bars.length * (barW + gap) - gap + padR

  let running = noi_t12
  const allY: number[] = [noi_t12, noi_pf]
  bars.slice(1,-1).forEach(b => { running += b.value; allY.push(running) })
  const maxVal = Math.max(...allY) * 1.12
  const minVal = Math.min(...allY, 0) * 1.08
  const range = maxVal - minVal || 1
  const toY = (v: number) => padT + (1 - (v - minVal) / range) * chartH

  running = noi_t12
  const barData = bars.map((b, i) => {
    const isFirst = i === 0
    const isLast  = i === bars.length - 1
    if (isFirst || isLast) {
      return { ...b, top: toY(b.value), height: Math.max(toY(0) - toY(b.value), 2), runAfter: b.value }
    }
    const prev = running
    running += b.value
    const top = toY(Math.max(prev, running))
    const height = Math.max(Math.abs(toY(prev) - toY(running)), 2)
    return { ...b, top, height, runAfter: running }
  })

  const barColor = (b: any, i: number) => {
    if (i === 0) return '#2E7D50'
    if (i === bars.length - 1) return NAVY
    return b.value >= 0 ? '#2E7D50' : '#C0392B'
  }

  return (
    <div style={{ padding:24, fontFamily:"'DM Sans',sans-serif", overflowX:'auto' }}>
      <div style={{ marginBottom:16 }}>
        <div style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:18, fontWeight:700, color:NAVY }}>NOI Walk</div>
        <div style={{ fontSize:11, color:'#8A9BB0', marginTop:2 }}>T12 → PF adjustments → PF NOI · updates live as you adjust the BOE</div>
      </div>

      <svg width={totalW} height={padT + chartH + padB} style={{ overflow:'visible', display:'block', marginBottom:36 }}>
        {[0,0.25,0.5,0.75,1].map(pct => {
          const val = minVal + pct * range
          const y = toY(val)
          return <g key={pct}>
            <line x1={padL} x2={totalW-padR} y1={y} y2={y} stroke="rgba(13,27,46,0.06)" strokeWidth={1}/>
            <text x={padL-6} y={y+3} textAnchor="end" fontSize={8} fill="#8A9BB0">{fmt(val)}</text>
          </g>
        })}
        <line x1={padL} x2={totalW-padR} y1={toY(0)} y2={toY(0)} stroke="rgba(13,27,46,0.2)" strokeWidth={1}/>

        {barData.map((b, i) => {
          const x = padL + i * (barW + gap)
          const c = barColor(b, i)
          const isLast = i === bars.length - 1
          const connY = b.value >= 0 ? b.top : b.top + b.height
          return <g key={b.label}>
            {i > 0 && !isLast && (
              <line x1={x-gap} x2={x} y1={connY} y2={connY} stroke="rgba(13,27,46,0.15)" strokeWidth={0.5} strokeDasharray="3,2"/>
            )}
            <rect x={x} y={b.top} width={barW} height={b.height} fill={c} rx={2} opacity={0.88}/>
            <text x={x+barW/2} y={b.top - 4} textAnchor="middle" fontSize={9} fontWeight="600" fill={c}>
              {i > 0 && i < bars.length-1 && b.value > 0 ? '+' : ''}{fmt(b.value)}
            </text>
            <text x={x+barW/2} y={padT+chartH+14} textAnchor="middle" fontSize={8} fill="#8A9BB0">
              {b.label.split('/').map((w: string, wi: number) => (
                <tspan key={wi} x={x+barW/2} dy={wi===0?0:10}>{w}</tspan>
              ))}
            </text>
          </g>
        })}
      </svg>

      {/* Cap Rate Sensitivity */}
      <div style={{ marginBottom:12 }}>
        <div style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:18, fontWeight:700, color:NAVY, marginBottom:4 }}>Cap Rate Sensitivity</div>
        <div style={{ fontSize:11, color:'#8A9BB0', marginBottom:16 }}>PF NOI: {fmtFull(noi_pf)} · {units} units</div>
      </div>
      <table style={{ borderCollapse:'collapse', width:'100%', fontSize:12 }}>
        <thead>
          <tr style={{ background:NAVY }}>
            {['Price Adj.','Purchase Price','$/Unit','Cap Rate (Adj)'].map(h => (
              <th key={h} style={{ padding:'9px 14px', textAlign: h==='Price Adj.'?'left':'right', fontSize:10, fontWeight:700, color:GOLD, letterSpacing:'0.08em' }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {[-4,-2,0,2,4].map((d,i) => {
            const adjPP = pp * (1 + d/100)
            const ppu = units > 0 ? adjPP/units : 0
            const cap = adjPP > 0 ? (noi_pf/adjPP)*100 : 0
            const isBase = d === 0
            return (
              <tr key={d} style={{ background: isBase ? 'rgba(201,168,76,0.08)' : i%2===0 ? '#fff' : 'rgba(13,27,46,0.015)', borderBottom:'1px solid rgba(13,27,46,0.06)' }}>
                <td style={{ padding:'9px 14px', fontWeight:isBase?700:400, color:NAVY }}>{d===0?'— Base PP —':`${d>0?'+':''}${d}%`}</td>
                <td style={{ padding:'9px 14px', textAlign:'right', fontWeight:isBase?700:400, color:NAVY, fontVariantNumeric:'tabular-nums' }}>${Math.round(adjPP).toLocaleString()}</td>
                <td style={{ padding:'9px 14px', textAlign:'right', color:'#555', fontVariantNumeric:'tabular-nums' }}>${Math.round(ppu).toLocaleString()}</td>
                <td style={{ padding:'9px 14px', textAlign:'right', fontWeight:isBase?700:400, color:isBase?GOLD:(cap>=5?'#2E7D50':cap>=4?'#C9A84C':'#C0392B'), fontVariantNumeric:'tabular-nums' }}>{cap.toFixed(2)}%</td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

export default function DealModal({ deal, boe, capRate, onClose, onSave, onSaveBoe, onSaveCapRate }: Props) {
  const [tab, setTab] = useState<Tab>('details')
  const [pfValues, setPfValues] = useState<Record<string,number>>({})
  const [form, setForm] = useState({
    status: deal.status,
    purchase_price: deal.purchase_price?.toString() ?? '',
    units: deal.units?.toString() ?? '',
    year_built: deal.year_built?.toString() ?? '',
    broker: deal.broker ?? '',
    bid_due_date: deal.bid_due_date ?? '',
    buyer: deal.buyer ?? '',
    seller: deal.seller ?? '',
    sold_price: deal.sold_price?.toString() ?? '',
    comments: deal.comments ?? '',
    address: (deal as any).address ?? '',
  })
  const [editingName, setEditingName] = useState(false)
  const [editName, setEditName] = useState(deal.name)
  const [photoUrl, setPhotoUrl] = useState<string | null>(null)
  const nameInputRef = useRef<HTMLInputElement>(null)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [isMobile, setIsMobile] = useState(false)
  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768)
    check()
    window.addEventListener('resize', check)
    return () => window.removeEventListener('resize', check)
  }, [])

  function regionFromMarket(market: string | null | undefined): Region | '' {
    if (!market) return ''
    for (const [region, cities] of Object.entries(REGION_MAP)) {
      if ((cities as string[]).includes(market)) return region as Region
    }
    return ''
  }
  const [editRegion, setEditRegion] = useState<Region | ''>(regionFromMarket(deal.market))
  const [editMarket, setEditMarket] = useState<string>(deal.market ?? '')

  useEffect(() => {
    setForm({
      status: deal.status,
      purchase_price: deal.purchase_price?.toString() ?? '',
      units: deal.units?.toString() ?? '',
      year_built: deal.year_built?.toString() ?? '',
      broker: deal.broker ?? '',
      bid_due_date: deal.bid_due_date ?? '',
      buyer: deal.buyer ?? '',
      seller: deal.seller ?? '',
      sold_price: deal.sold_price?.toString() ?? '',
      comments: deal.comments ?? '',
      address: (deal as any).address ?? '',
    })
    setEditName(deal.name)
    setEditingName(false)
    setEditRegion(regionFromMarket(deal.market))
    setEditMarket(deal.market ?? '')
    setTab('details')

  }, [deal.name, deal.comments, deal.status, deal.purchase_price, deal.units, deal.buyer, deal.seller, deal.sold_price, deal.market])

  const pp = parseFloat(form.purchase_price) || null
  const u = parseInt(form.units) || null
  const ppu = pp && u ? Math.round(pp / u) : deal.price_per_unit
  const soldP = parseFloat(form.sold_price) || null
  const guidanceDiff = soldP && pp ? soldP - pp : null

  async function handleSave() {
    setSaving(true)
    await onSave({
      id: deal.id,
      name: editName.trim() || deal.name,
      _oldName: deal.name,
      status: form.status,
      purchase_price: pp,
      units: u,
      year_built: form.year_built?.trim() || null,
      broker: form.broker || null,
      bid_due_date: form.bid_due_date || null,
      price_per_unit: ppu,
      buyer: form.buyer || null,
      seller: form.seller || null,
      sold_price: soldP,
      comments: form.comments || null,
      market: editMarket || undefined,
      address: form.address || null,
    } as any)
    setSaving(false)
    setSaved(true)
    setTimeout(() => setSaved(false), 2500)
  }

  // ESC to close
  useEffect(() => {
    const fn = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', fn)
    return () => window.removeEventListener('keydown', fn)
  }, [onClose])

  const inputStyle = {
    width: '100%', padding: '8px 10px', border: '1px solid rgba(13,27,46,0.12)',
    borderRadius: 7, fontSize: 13, fontFamily: "'DM Sans',sans-serif",
    color: '#0D1B2E', outline: 'none', boxSizing: 'border-box' as const,
  }
  const labelStyle = { display: 'block' as const, fontSize: 10, fontWeight: 600 as const, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 5 }

  return (
    <div style={{ position:'fixed', inset:0, background:'rgba(13,27,46,0.55)', zIndex:2000, display:'flex', alignItems: isMobile ? 'flex-end' : 'center', justifyContent:'center', padding: isMobile ? 0 : 16 }}
      onClick={onClose}>
      <div style={{ background:'#fff', borderRadius: isMobile ? '16px 16px 0 0' : 16, width: isMobile ? '100vw' : 'min(1080px,96vw)', height: isMobile ? '92vh' : 'auto', maxHeight: isMobile ? '92vh' : '94vh', display:'flex', flexDirection:'column', overflow: 'hidden' }}
        onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div style={{ padding: isMobile ? '14px 16px 0' : '20px 28px 0', borderBottom:'1px solid rgba(13,27,46,0.08)', flexShrink:0 }}>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', marginBottom:14 }}>
            <div style={{ flex:1, minWidth:0, paddingRight:16 }}>
              {/* Editable deal name */}
              {editingName ? (
                <input
                  ref={nameInputRef}
                  value={editName}
                  onChange={e => setEditName(e.target.value)}
                  onBlur={() => setEditingName(false)}
                  onKeyDown={e => { if (e.key==='Enter'||e.key==='Escape') setEditingName(false) }}
                  style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:22, fontWeight:700, color:'#0D1B2E',
                    border:'none', borderBottom:'2px solid #C9A84C', outline:'none', background:'transparent',
                    width:'100%', padding:'0 0 2px 0' }}
                  autoFocus
                />
              ) : (
                <div style={{ display:'flex', alignItems:'center', gap:8, cursor:'text' }} onClick={() => setEditingName(true)}>
                  <a
                    href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent((form as any).address || (editName + ' ' + (deal.market ?? '')))}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    title="Search on Google Maps"
                    onClick={e => e.stopPropagation()}
                    style={{ fontFamily:"'Cormorant Garamond',serif", fontSize: isMobile ? 17 : 22, fontWeight:700, color:'#0D1B2E', textDecoration:'none', display:'inline-block' }}
                    onMouseEnter={e => (e.currentTarget.style.color = '#C9A84C')}
                    onMouseLeave={e => (e.currentTarget.style.color = '#0D1B2E')}
                  >
                    {editName} <span style={{ fontSize:14, verticalAlign:'middle' }}>↗</span>
                  </a>
                  <span title="Edit name" style={{ fontSize:11, color:'#C9A84C', opacity:0.6, userSelect:'none' }}>✎</span>
                </div>
              )}
              <div style={{ fontSize:12, color:'#8A9BB0', marginTop:3 }}>
                📍 {(form as any).address ? `${(form as any).address}` : deal.market}
              </div>
            </div>
            <div style={{ display:'flex', alignItems:'flex-start', gap:12, flexShrink:0 }}>
              {/* Property photo */}
              <div style={{ width: isMobile ? 60 : 160, height: isMobile ? 60 : 100, borderRadius:10, overflow:'hidden', background:'rgba(13,27,46,0.08)', flexShrink:0, position:'relative' }}>
                <img
                  src={`https://maps.googleapis.com/maps/api/streetview?size=320x200&location=${encodeURIComponent((form as any).address || editName + ' ' + (deal.market ?? ''))}&key=${process.env.NEXT_PUBLIC_GOOGLE_MAPS_KEY ?? ''}&source=outdoor`}
                  alt={editName}
                  style={{ width:'100%', height:'100%', objectFit:'cover' }}
                  onError={e => {
                    const el = e.currentTarget
                    el.style.display = 'none'
                    const parent = el.parentElement
                    if (parent) {
                      parent.style.background = '#0D1B2E'
                      parent.style.display = 'flex'
                      parent.style.alignItems = 'center'
                      parent.style.justifyContent = 'center'
                      const txt = document.createElement('span')
                      txt.textContent = editName.charAt(0).toUpperCase()
                      txt.style.cssText = 'color:#C9A84C;font-size:36px;font-family:Cormorant Garamond,serif;font-weight:700'
                      parent.appendChild(txt)
                    }
                  }}
                />
              </div>
              <button onClick={onClose} style={{ background:'none', border:'none', cursor:'pointer', color:'#8A9BB0', fontSize:20, padding:4, lineHeight:1 }}>✕</button>
            </div>
          </div>

          {/* Tabs */}
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center' }}>
            <div style={{ display:'flex', gap:0 }}>
              {(['details','boe','noi'] as Tab[]).map(t => (
                <button key={t} onClick={() => setTab(t)} style={{
                  padding:'8px 20px', border:'none', background:'none', cursor:'pointer',
                  fontFamily:"'DM Sans',sans-serif", fontSize:12, fontWeight:600,
                  color: tab===t ? '#0D1B2E' : '#8A9BB0',
                  borderBottom: tab===t ? '2px solid #C9A84C' : '2px solid transparent',
                  textTransform:'uppercase', letterSpacing:'0.08em',
                }}>
                  {t === 'details' ? 'Deal Details' : t === 'boe' ? 'BOE' : 'NOI Walk'}
                  {t === 'boe' && boe && Object.keys(boe.t12 ?? {}).length > 0 && (
                    <span style={{ marginLeft:6, background:'#2E7D50', color:'#fff', borderRadius:8, padding:'1px 6px', fontSize:9 }}>T12</span>
                  )}
                </button>
              ))}
            </div>
            {tab === 'boe' && (
              <div style={{ display:'flex', gap:16, paddingRight:4, paddingBottom:8 }}>
                <div style={{ textAlign:'right' }}>
                  <div style={{ fontSize:9, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase' }}>Units</div>
                  <div style={{ fontSize:15, fontWeight:700, color:'#0D1B2E', fontFamily:"'Cormorant Garamond',serif" }}>{deal.units?.toLocaleString() ?? '—'}</div>
                </div>
                <div style={{ textAlign:'right' }}>
                  <div style={{ fontSize:9, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase' }}>Year Built</div>
                  <div style={{ fontSize:15, fontWeight:700, color:'#0D1B2E', fontFamily:"'Cormorant Garamond',serif" }}>{deal.year_built ?? '—'}</div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Body */}
        <div style={{ flex:1, overflowY:'auto', overflowX: tab === 'boe' ? 'auto' : 'hidden' }}>
          {tab === 'details' && (
            <div style={{ padding: isMobile ? '16px' : '24px 28px' }}>
              <div style={{ display:'grid', gridTemplateColumns: isMobile ? '1fr' : 'repeat(3,1fr)', gap: isMobile ? 12 : 16 }}>
                {/* Status */}
                <div style={{ gridColumn:'span 1' }}>
                  <label style={labelStyle}>Status</label>
                  <select value={form.status} onChange={e => setForm(p => ({...p, status: e.target.value}))} style={{...inputStyle, background:'#fff'}}>
                    {ALL_STATUSES.map(s => <option key={s} value={s}>{s}</option>)}
                  </select>
                </div>

                <div><label style={labelStyle}>Purchase Price ($)</label>
                  <input style={inputStyle} type="number" value={form.purchase_price} onChange={e => setForm(p => ({...p, purchase_price:e.target.value}))} /></div>

                <div><label style={labelStyle}>Units</label>
                  <input style={inputStyle} type="number" value={form.units} onChange={e => setForm(p => ({...p, units:e.target.value}))} /></div>

                <div><label style={labelStyle}>$/Unit (calc)</label>
                  <div style={{...inputStyle, background:'rgba(13,27,46,.03)', color:'#8A9BB0', display:'flex', alignItems:'center'}}>{fmtUnit(ppu)}</div>
                </div>

                <div><label style={labelStyle}>Year Built</label>
                  <input style={inputStyle} type="text" placeholder="e.g. 2000 / 2023" value={form.year_built} onChange={e => setForm(p => ({...p, year_built:e.target.value}))} /></div>

                <div><label style={labelStyle}>Broker</label>
                  <input style={inputStyle} type="text" value={form.broker} onChange={e => setForm(p => ({...p, broker:e.target.value}))} /></div>

                <div><label style={labelStyle}>Bid Due Date</label>
                  <input style={inputStyle} type="date" value={form.bid_due_date} onChange={e => setForm(p => ({...p, bid_due_date:e.target.value}))} /></div>

                <div><label style={labelStyle}>Seller</label>
                  <input style={inputStyle} type="text" placeholder="Selling entity…" value={form.seller} onChange={e => setForm(p => ({...p, seller:e.target.value}))} /></div>

                <div><label style={labelStyle}>Buyer</label>
                  <input style={inputStyle} type="text" placeholder="Acquiring entity…" value={form.buyer} onChange={e => setForm(p => ({...p, buyer:e.target.value}))} /></div>

                <div><label style={labelStyle}>Sold Price ($)</label>
                  <input style={inputStyle} type="number" placeholder="0" value={form.sold_price} onChange={e => setForm(p => ({...p, sold_price:e.target.value}))} /></div>

                <div>
                  <label style={labelStyle}>+/− vs Guidance</label>
                  <div style={{...inputStyle, background:'rgba(13,27,46,.03)', display:'flex', alignItems:'center', minHeight:38}}>
                    {guidanceDiff !== null ? (
                      <span style={{ fontSize:13, fontWeight:700, color: guidanceDiff>0?'#1E7A4A':guidanceDiff<0?'#C0392B':'#8A9BB0' }}>
                        {guidanceDiff>=0?'+':''}{fmtShort(guidanceDiff)} ({guidanceDiff>=0?'+':''}{((guidanceDiff/pp!)*100).toFixed(1)}%)
                      </span>
                    ) : <span style={{color:'#8A9BB0'}}>—</span>}
                  </div>
                </div>

                <div><label style={labelStyle}>Date Added</label>
                  <div style={{...inputStyle, background:'rgba(13,27,46,.03)', color:'#8A9BB0', display:'flex', alignItems:'center'}}>{deal.added ?? '—'}</div>
                </div>

                <div style={{ gridColumn:'span 3' }}><label style={labelStyle}>Address</label>
                  <input style={inputStyle} type="text" placeholder="e.g. 4200 Lake Como Dr, Orlando, FL 32808" value={form.address} onChange={e => setForm(p => ({...p, address:e.target.value}))} />
                </div>

                {/* Region + Market */}
                <div>
                  <label style={labelStyle}>Region</label>
                  <select value={editRegion} onChange={e => { setEditRegion(e.target.value as Region | ''); setEditMarket('') }} style={{...inputStyle, background:'#fff'}}>
                    <option value=''>— Select Region —</option>
                    {(Object.keys(REGION_MAP) as Region[]).map(r => (
                      <option key={r} value={r}>{REGION_LABELS[r]}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={labelStyle}>Market</label>
                  <select value={editMarket.startsWith('__custom__') ? '__custom__' : editMarket} onChange={e => setEditMarket(e.target.value === '__custom__' ? '__custom__' : e.target.value)} style={{...inputStyle, background:'#fff'}} disabled={!editRegion}>
                    <option value=''>— Select Market —</option>
                    {editRegion && (REGION_MAP[editRegion] as string[]).map(city => (
                      <option key={city} value={city}>{city}</option>
                    ))}
                    <option value='__custom__'>Other (type below)…</option>
                  </select>
                  {editMarket === '__custom__' && (
                    <input type="text" placeholder="Type market name…"
                      style={{...inputStyle, marginTop: 6}}
                      onChange={e => setEditMarket(e.target.value)}
                    />
                  )}
                </div>

                {/* Comments — full width */}
                <div style={{ gridColumn:'span 3' }}>
                  <label style={labelStyle}>Comments</label>
                  <textarea
                    value={form.comments}
                    onChange={e => setForm(p => ({...p, comments: e.target.value}))}
                    style={{ ...inputStyle, minHeight: 120, resize: 'vertical', lineHeight: 1.7 }}
                    placeholder="No comments on file."
                  />
                </div>

                {/* Cap Rate intel */}
                {capRate && (
                  <div style={{ gridColumn:'span 3', background:'rgba(13,27,46,0.02)', border:'1px solid rgba(13,27,46,0.07)', borderRadius:10, padding:16 }}>
                    <div style={{ fontSize:10, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.12em', textTransform:'uppercase', marginBottom:12 }}>Cap Rate Intelligence</div>
                    <div style={{ display:'grid', gridTemplateColumns:'repeat(5,1fr)', gap:12 }}>
                      {[
                        ['Broker Cap Rate', capRate.broker_cap_rate ? `${Number(capRate.broker_cap_rate).toFixed(2)}%` : '—'],
                        ['NOI/PP Cap Rate', capRate.noi_cap_rate ? `${Number(capRate.noi_cap_rate).toFixed(2)}%` : '—'],
                        ['Ask Price', capRate.purchase_price ? fmtShort(capRate.purchase_price * 1000) : '—'],
                        ['Sold Price', capRate.sold_price ? fmtShort(capRate.sold_price * 1000) : '—'],
                        ['Delta', capRate.delta != null ? `${Number(capRate.delta) >= 0 ? '+' : ''}${(Number(capRate.delta)*100).toFixed(1)}%` : '—'],
                      ].map(([l, v]) => (
                        <div key={l}><div style={{ fontSize:10, color:'#8A9BB0', marginBottom:3 }}>{l}</div><div style={{ fontSize:14, fontWeight:600, color:'#0D1B2E' }}>{v}</div></div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Footer */}
              <div style={{ display:'flex', justifyContent:'flex-end', alignItems:'center', gap:12, marginTop:24, paddingTop:16, borderTop:'1px solid rgba(13,27,46,0.07)' }}>
                {saved && <span style={{ fontSize:12, color:'#2E7D50', fontWeight:600 }}>✓ Changes saved</span>}
                <button onClick={onClose} style={{ padding:'9px 22px', border:'1px solid rgba(13,27,46,0.15)', borderRadius:8, background:'#fff', color:'#8A9BB0', fontSize:13, cursor:'pointer', fontFamily:"'DM Sans',sans-serif" }}>Cancel</button>
                <button onClick={handleSave} disabled={saving} style={{ padding:'9px 22px', background: saving?'#8A9BB0':'#0D1B2E', color:'#F0B429', border:'none', borderRadius:8, fontSize:13, fontWeight:700, cursor: saving?'not-allowed':'pointer', fontFamily:"'DM Sans',sans-serif" }}>
                  {saving ? 'Saving…' : 'Save Changes'}
                </button>
              </div>
            </div>
          )}

          {tab === 'boe' && (
            <BoePanel deal={deal} boe={boe} onSave={onSaveBoe} onPfChange={setPfValues} />
          )}
          {tab === 'noi' && (
            <NoiWalk boe={boe} deal={deal} pfValues={pfValues} />
          )}
          {tab === 'noi' && (
            <NoiWalk boe={boe} deal={deal} pfValues={pfValues} />
          )}
        </div>
      </div>
    </div>
  )
}
