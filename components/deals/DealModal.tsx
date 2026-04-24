'use client'
import React, { useState, useEffect, useRef, useCallback } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, fmtUnit, ALL_STATUSES, REGION_MAP, REGION_LABELS } from '@/lib/utils'
import type { Region } from '@/lib/types'
import BoePanel from '../boe/BoePanel'
import RentRollPanel from '../boe/RentRollPanel'

interface Props {
  deal: Deal
  boe: BoeData | null
  capRate: CapRate | null
  onClose: () => void
  onSave: (updates: Partial<Deal> & { name: string }) => Promise<any>
  onSaveBoe: (boe: BoeData) => Promise<any>
  onSaveCapRate?: (dealName: string, capAdj: number) => void
}

type Tab = 'details' | 'boe' | 'noi' | 'rr'


// ── NOI Walk + Cap Rate Sensitivity ──────────────────────────────────────────
function NoiWalk({ boe, deal, pfValues }: { boe: any; deal: any; pfValues: Record<string,number> }) {
  const NAVY = '#0D1B2E'
  const GOLD = '#C9A84C'
  const [tooltip, setTooltip] = React.useState<{ lines: string[]; x: number; y: number } | null>(null)

  if (!boe?.t12) return (
    <div style={{ padding:60, textAlign:'center', color:'#8A9BB0', fontFamily:"'DM Sans',sans-serif", fontSize:14 }}>
      No BOE data yet — build the BOE first then come back here.
    </div>
  )

  const units = deal.units || 1
  const pp = deal.purchase_price || 0
  const pf = pfValues

  const rrp_pf  = pf.rrp_pf  ?? 0
  const vac_p   = pf.vac_p   ?? 0
  const bad_p   = pf.bad_p   ?? 0
  const conc_p  = pf.conc_p  ?? 0
  const mod_p   = pf.mod_p   ?? 0
  const emp_p   = pf.emp_p   ?? 0
  const oi_p    = pf.oi_p    ?? 0
  const egr_p   = pf.egr_p   ?? 0
  const ga_p    = pf.ga_p    ?? 0
  const mkt_p   = pf.mkt_p   ?? 0
  const rm_p    = pf.rm_p    ?? 0
  const pay_p   = pf.pay_p   ?? 0
  const mgt_p   = pf.mgt_p   ?? 0
  const utl_p   = pf.utl_p   ?? 0
  const tax_p   = pf.tax_p   ?? 0
  const taxm_p  = pf.taxm_p  ?? 0
  const ins_p   = pf.ins_p   ?? 0
  const noi_pf  = pf.noi_p   ?? 0

  const fmtFull = (n: number) => n < 0 ? `-$${Math.abs(Math.round(n)).toLocaleString()}` : `$${Math.round(n).toLocaleString()}`
  const fmtM = (n: number) => { const a=Math.abs(n); if(a>=1000000) return `$${(n/1000000).toFixed(2)}M`; if(a>=1000) return `$${Math.round(n/1000)}K`; return `$${Math.round(n)}`}
  const ppu = (n: number) => units > 0 ? `$${Math.round(Math.abs(n)/units).toLocaleString()}/unit` : '—'
  const ppum = (n: number) => units > 0 ? `$${Math.round(Math.abs(n)/units/12).toLocaleString()}/unit/mo` : '—'
  const pctOfRRP = (n: number) => rrp_pf > 0 ? `${(Math.abs(n)/rrp_pf*100).toFixed(1)}%` : '—'
  const pctOfEGR = (n: number) => egr_p > 0 ? `${(Math.abs(n)/egr_p*100).toFixed(1)}% of EGR` : '—'

  // Payroll detail from boe.payroll
  const py = boe.payroll ?? {}
  const pv = (k: string) => parseFloat(py[k]??'0')||0
  const payrollLines = [
    ...(pv('py-pm')>0 ? [`Prop Mgr: $${Math.round(pv('py-pm')).toLocaleString()}`] : []),
    ...(pv('py-am')>0 ? [`Asst Mgr: $${Math.round(pv('py-am')).toLocaleString()}`] : []),
    ...(pv('py-la')>0 ? [`Leasing: $${Math.round(pv('py-la')).toLocaleString()}`] : []),
    ...(pv('py-ms')>0 ? [`Maint Sup: $${Math.round(pv('py-ms')).toLocaleString()}`] : []),
    ...(pv('py-mt')>0 ? [`Maint Tech: $${Math.round(pv('py-mt')).toLocaleString()}`] : []),
    ...(pv('py-ma')>0 ? [`Maint Asst: $${Math.round(pv('py-ma')).toLocaleString()}`] : []),
  ]

  // Tax tooltip
  const th = boe.tax_helper ?? {}
  const tv = (k: string) => parseFloat(th[k]??'0')||0
  const taxMode = boe.tax_mode ?? 'pp'
  const taxBase = taxMode === 'av' ? (parseFloat(String(boe.current_av??'0').replace(/[,$]/g,''))||0) : pp
  const taxLabel = taxMode === 'av' ? 'Current Cycle (AV)' : 'Reassessment (PP)'
  const taxLines = [
    taxLabel,
    `Base: $${Math.round(taxBase).toLocaleString()}`,
    ...(tv('tx-mil')>0 ? [`Mill Rate: ${tv('tx-mil')}‰`] : []),
    ...(tv('tx-rat')>0 ? [`Assessment Ratio: ${tv('tx-rat')}%`] : []),
    ...(tv('tx-sf')>0  ? [`State Factor: ${tv('tx-sf')}`] : []),
    ...(tv('tx-nad')>0 ? [`Non-Ad Val: $${Math.round(tv('tx-nad')).toLocaleString()}`] : []),
    `Total: ${fmtFull(tax_p+taxm_p)}`,
  ]

  // Bar definitions — label shown ON bar, tooltipLines shown on hover
  const bars: {
    label: string
    value: number
    color: string
    barLabel: string
    tooltipLines: string[]
    isStart?: boolean
    isTotal?: boolean
  }[] = [
    {
      label: 'RRP', value: rrp_pf, color: '#2E7D50', isStart: true,
      barLabel: ppum(rrp_pf),
      tooltipLines: [`RRP`, fmtFull(rrp_pf), ppum(rrp_pf)],
    },
    {
      label: 'Vacancy', value: vac_p, color: '#C0392B',
      barLabel: pctOfRRP(vac_p),
      tooltipLines: [`Vacancy`, pctOfRRP(vac_p), fmtFull(vac_p)],
    },
    {
      label: 'Bad Debt/Conc', value: bad_p+conc_p, color: '#C0392B',
      barLabel: pctOfRRP(bad_p+conc_p),
      tooltipLines: [
        'Bad Debt/Conc',
        `Bad Debt: ${pctOfRRP(bad_p)} (${fmtFull(bad_p)})`,
        `Conc: ${pctOfRRP(conc_p)} (${fmtFull(conc_p)})`,
        `Total: ${fmtFull(bad_p+conc_p)}`,
      ],
    },
    {
      label: 'Mod/Emp Units', value: mod_p+emp_p, color: '#C0392B',
      barLabel: pctOfRRP(mod_p+emp_p),
      tooltipLines: [`Mod/Emp Units`, pctOfRRP(mod_p+emp_p), fmtFull(mod_p+emp_p)],
    },
    {
      label: 'Other Inc.', value: oi_p, color: '#2E7D50',
      barLabel: ppu(oi_p),
      tooltipLines: [`Other Income`, ppu(oi_p), fmtFull(oi_p)],
    },
    {
      label: 'G&A', value: -ga_p, color: '#C0392B',
      barLabel: ppu(ga_p),
      tooltipLines: [`G&A`, ppu(ga_p), fmtFull(ga_p), pctOfEGR(ga_p)],
    },
    {
      label: 'Mktg', value: -mkt_p, color: '#C0392B',
      barLabel: ppu(mkt_p),
      tooltipLines: [`Marketing`, ppu(mkt_p), fmtFull(mkt_p), pctOfEGR(mkt_p)],
    },
    {
      label: 'R&M', value: -rm_p, color: '#C0392B',
      barLabel: ppu(rm_p),
      tooltipLines: [`R&M`, ppu(rm_p), fmtFull(rm_p), pctOfEGR(rm_p)],
    },
    {
      label: 'Payroll', value: -pay_p, color: '#C0392B',
      barLabel: `${fmtM(pay_p)} | ${ppu(pay_p)}`,
      tooltipLines: [`Payroll`, fmtFull(pay_p), ppu(pay_p), ...payrollLines.length ? payrollLines : ['No build-up data'], pctOfEGR(pay_p)],
    },
    {
      label: 'Utl/Mgmt', value: -(utl_p+mgt_p), color: '#C0392B',
      barLabel: ppu(utl_p+mgt_p),
      tooltipLines: [`Utilities + Mgmt Fee`, fmtFull(utl_p+mgt_p), pctOfEGR(utl_p+mgt_p)],
    },
    {
      label: 'RE / Other Tax', value: -(tax_p+taxm_p), color: '#C0392B',
      barLabel: ppu(tax_p+taxm_p),
      tooltipLines: taxLines,
    },
    {
      label: 'Ins', value: -ins_p, color: '#C0392B',
      barLabel: ppu(ins_p),
      tooltipLines: [`Insurance`, ppu(ins_p), fmtFull(ins_p), pctOfEGR(ins_p)],
    },
    {
      label: 'PF NOI', value: noi_pf, color: NAVY, isTotal: true,
      barLabel: fmtM(noi_pf),
      tooltipLines: [`PF NOI`, fmtFull(noi_pf), units>0?`$${Math.round(noi_pf/units).toLocaleString()}/unit`:''],
    },
  ]

  // Chart — fit all bars on screen
  const n = bars.length
  const padL = 56, padR = 16, padT = 40, padB = 90, chartH = 360, gap = 6
  // Fill full container width dynamically
  const chartW = typeof window !== 'undefined' ? Math.min(window.innerWidth - 80, 1040) : 960
  const barW = Math.floor((chartW - padL - padR - (n-1)*gap) / n)
  const totalW = padL + n*(barW+gap) - gap + padR

  // Waterfall positioning
  let running = 0
  const barData = bars.map((b) => {
    let stackTop: number, stackH: number
    if (b.isStart || b.isTotal) {
      stackTop = 0; stackH = b.value; if (b.isStart) running = b.value
    } else {
      stackTop = running; stackH = b.value; running += b.value
    }
    return { ...b, stackTop, stackH }
  })

  const allVals: number[] = []
  barData.forEach(b => {
    if (b.isStart || b.isTotal) allVals.push(b.value)
    else { allVals.push(b.stackTop); allVals.push(b.stackTop + b.stackH) }
  })
  const maxVal = Math.max(...allVals) * 1.12
  const minVal = Math.min(...allVals, 0)
  const range = maxVal - minVal || 1
  const toY = (v: number) => padT + (1 - (v - minVal) / range) * chartH

  const getRectProps = (b: typeof barData[0]) => {
    if (b.isStart || b.isTotal) {
      const top = toY(b.value); const bot = toY(0)
      return { y: Math.min(top,bot), h: Math.max(Math.abs(bot-top), 8) }
    }
    const from = toY(b.stackTop); const to = toY(b.stackTop+b.stackH)
    return { y: Math.min(from,to), h: Math.max(Math.abs(from-to), 8) }
  }

  return (
    <div style={{ padding:24, fontFamily:"'DM Sans',sans-serif" }}>
      {/* Header */}
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', marginBottom:16 }}>
        <div>
          <div style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:18, fontWeight:700, color:NAVY }}>NOI Walk</div>
          <div style={{ fontSize:11, color:'#8A9BB0', marginTop:2 }}>PF values · hover bars for detail</div>
        </div>
        <div style={{ display:'flex', gap:16, fontSize:12 }}>
          <span style={{ color:'#555' }}>EGR <strong style={{color:NAVY}}>{fmtFull(egr_p)}</strong></span>
          <span style={{ color:'#555' }}>PF NOI <strong style={{color:NAVY}}>{fmtFull(noi_pf)}</strong></span>
        </div>
      </div>

      {/* Chart */}
      <div style={{ position:'relative' }}>
        <svg width={totalW} height={padT+chartH+padB} style={{ overflow:'visible', display:'block', maxWidth:'100%' }}>
          {/* Gridlines + Y axis */}
          {[0,0.25,0.5,0.75,1].map(pct => {
            const val = minVal + pct*range
            const y = toY(val)
            return <g key={pct}>
              <line x1={padL} x2={totalW-padR} y1={y} y2={y} stroke="rgba(13,27,46,0.05)" strokeWidth={1}/>
              <text x={padL-8} y={y+3} textAnchor="end" fontSize={10} fill="#8A9BB0">{fmtM(val)}</text>
            </g>
          })}
          <line x1={padL} x2={totalW-padR} y1={toY(0)} y2={toY(0)} stroke="rgba(13,27,46,0.2)" strokeWidth={1}/>

          {/* Connector lines */}
          {barData.map((b,i) => {
            if (i===0||b.isTotal) return null
            const prev = barData[i-1]
            const connY = prev.isStart ? toY(prev.value) : toY(prev.stackTop+prev.stackH)
            const x = padL + i*(barW+gap)
            return <line key={`c${i}`} x1={x-gap} x2={x} y1={connY} y2={connY} stroke="rgba(13,27,46,0.15)" strokeWidth={0.5} strokeDasharray="3,2"/>
          })}

          {/* Bars */}
          {barData.map((b,i) => {
            const x = padL + i*(barW+gap)
            const {y,h} = getRectProps(b)
            const isPos = b.stackH >= 0
            return <g key={b.label}
              onMouseEnter={e => {
                const svgRect = (e.currentTarget.ownerSVGElement as SVGElement).getBoundingClientRect()
                setTooltip({ lines: b.tooltipLines, x: x+barW/2, y })
              }}
              onMouseLeave={() => setTooltip(null)}
              style={{ cursor:'pointer' }}>
              <rect x={x} y={y} width={barW} height={h} fill={b.color} rx={2} opacity={0.88}/>
              {/* Bar label */}
              <text x={x+barW/2} y={isPos||b.isStart||b.isTotal ? y-5 : y+h+13} textAnchor="middle" fontSize={Math.min(12, Math.max(9, barW/5))} fontWeight="700" fill={b.color}>
                {b.barLabel}
              </text>
              {/* X axis label — split on space */}
              {b.label.split(' ').map((w,wi) => (
                <text key={wi} x={x+barW/2} y={padT+chartH+14+(wi*11)} textAnchor="middle" fontSize={Math.min(9,barW/4.5)} fill="#8A9BB0">{w}</text>
              ))}
            </g>
          })}

          {/* Tooltip */}
          {tooltip && (() => {
            const lines = tooltip.lines.filter(Boolean)
            const tw = 160, th2 = 16*lines.length+14
            const tx = Math.min(Math.max(tooltip.x - tw/2, padL), totalW-padR-tw)
            const ty = Math.max(tooltip.y - th2 - 8, padT)
            return <g style={{ pointerEvents:'none' }}>
              <rect x={tx} y={ty} width={tw} height={th2} rx={5} fill={NAVY} opacity={0.94}/>
              {lines.map((l,li) => (
                <text key={li} x={tx+10} y={ty+14+li*16} fontSize={li===0?10:9} fontWeight={li===0?'700':'400'} fill={li===0?'#fff':li===lines.length-1?GOLD:'rgba(255,255,255,0.75)'}>{l}</text>
              ))}
            </g>
          })()}
        </svg>
      </div>

      {/* Cap Rate Sensitivity */}
      <div style={{ marginTop:32, marginBottom:12 }}>
        <div style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:18, fontWeight:700, color:NAVY, marginBottom:4 }}>Cap Rate Sensitivity</div>
        <div style={{ fontSize:11, color:'#8A9BB0', marginBottom:16 }}>PF NOI: {fmtFull(noi_pf)} · {units} units</div>
      </div>
      <table style={{ borderCollapse:'collapse', width:'100%', fontSize:12 }}>
        <thead>
          <tr style={{ background:NAVY }}>
            {['Price Adj.','Purchase Price','$/Unit','Cap Rate (Adj)'].map(h => (
              <th key={h} style={{ padding:'9px 14px', textAlign:h==='Price Adj.'?'left':'right', fontSize:10, fontWeight:700, color:GOLD, letterSpacing:'0.08em', textTransform:'uppercase' }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {[-4,-2,0,2,4].map((d,i) => {
            const adjPP = pp*(1+d/100)
            const ppuVal = units>0?adjPP/units:0
            const cap = adjPP>0?(noi_pf/adjPP)*100:0
            const isBase = d===0
            return (
              <tr key={d} style={{ background:isBase?'rgba(201,168,76,0.08)':i%2===0?'#fff':'rgba(13,27,46,0.015)', borderBottom:'1px solid rgba(13,27,46,0.06)' }}>
                <td style={{ padding:'9px 14px', fontWeight:isBase?700:400, color:NAVY }}>{d===0?'— Base PP —':`${d>0?'+':''}${d}%`}</td>
                <td style={{ padding:'9px 14px', textAlign:'right', fontWeight:isBase?700:400, color:NAVY, fontVariantNumeric:'tabular-nums' }}>${Math.round(adjPP).toLocaleString()}</td>
                <td style={{ padding:'9px 14px', textAlign:'right', color:'#555', fontVariantNumeric:'tabular-nums' }}>${Math.round(ppuVal).toLocaleString()}</td>
                <td style={{ padding:'9px 14px', textAlign:'right', fontWeight:isBase?700:400, fontSize:isBase?14:12, color:isBase?GOLD:(cap>=5?'#2E7D50':cap>=4?'#C9A84C':'#C0392B'), fontVariantNumeric:'tabular-nums' }}>{cap.toFixed(2)}%</td>
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
  const [rentRollData, setRentRollData] = useState<any>((boe as any)?.rent_roll ?? null)
  const [pfValues, setPfValues] = useState<Record<string,number>>(() => {
    // Compute initial PF values from boe so NOI Walk is correct on first open
    if (!boe?.t12) return {} as Record<string,number>
    const t = boe.t12 as any
    const a = (boe.adjs ?? {}) as any
    const v = (k: string) => a[k] !== undefined && a[k] !== '' ? parseFloat(a[k]) : null
    const units = deal.units || 1
    const pp = deal.purchase_price || 0
    const rrp_t12 = (t.gpr??0) + (t.ltl??0)
    const rrp_adjPct = v('gpr') ?? 0
    const rrp_pf = rrp_t12 * (1 + rrp_adjPct/100)
    const ltl_p = t.ltl ?? 0
    const gpr_p = rrp_pf - ltl_p
    const vac_p = v('vac')!=null ? -(v('vac')!/100)*(gpr_p+ltl_p) : (t.vac??0)
    const bad_p = v('bad')!=null ? -(v('bad')!/100)*gpr_p : (t.bad??0)
    const conc_p = v('conc')!=null ? -(v('conc')!/100)*gpr_p : (t.conc??0)
    const mod_p = v('mod')!=null ? -(v('mod')!/100)*gpr_p : (t.mod??0)
    const emp_p = v('emp')!=null ? -(v('emp')!/100)*gpr_p : (t.emp??0)
    const oi_p = (t.oi??0) + (v('oi')??0)
    const egr_p = rrp_pf + vac_p + bad_p + conc_p + mod_p + emp_p + oi_p
    const ga_p = (t.ga??0) + (v('ga')??0)
    const mkt_p = (t.mkt??0) + (v('mkt')??0)
    const py = boe.payroll ?? {}
    const pv = (k: string) => parseFloat((py as any)[k] ?? '0') || 0
    const inBase = pv('py-pm')+pv('py-am')+pv('py-la')
    const outBase = pv('py-ms')+pv('py-mt')+pv('py-ma')
    const payCalc = inBase*(1+pv('py-bi')) + outBase*(1+pv('py-bo')) + (inBase+outBase)*pv('py-ben')
    const rm = boe.rmi ?? {}
    const rv = (k: string) => parseFloat((rm as any)[k] ?? '0') || 0
    const rmCalc = (rv('rmi-rm')+rv('rmi-ct')+rv('rmi-tu'))*units
    const rm_p = a['rm'] ? parseFloat(a['rm'])*units : (rmCalc > 0 ? rmCalc : (t.rm??0))
    const pay_p = a['pay'] ? parseFloat(a['pay']) : (payCalc > 0 ? payCalc : (t.pay??0))
    const mgt_p = ((v('mgt')??2.5)/100)*egr_p
    const utl_p = (t.utl??0) + (v('utl')??0)
    const th = boe.tax_helper ?? {}
    const tv = (k: string) => parseFloat((th as any)[k] ?? '0') || 0
    const taxBase = boe.tax_mode === 'av' ? (parseFloat(String(boe.current_av??'0').replace(/[,$]/g,''))||0) : pp
    const taxCalc = taxBase*(tv('tx-mil')/100)*(tv('tx-rat')/100)*(tv('tx-sf')/100)+tv('tx-nad')
    const tax_p = a['tax'] ? (t.tax??0)+(v('tax')??0) : (taxCalc>0?taxCalc:(t.tax??0)+(v('tax')??0))
    const taxm_p = (t.taxm??0) + (v('taxm')??0)
    const ins_p = (v('ins')??550)*units
    const opex_p = ga_p+mkt_p+rm_p+pay_p+mgt_p+utl_p+tax_p+taxm_p+ins_p
    const noi_p = (boe.pf_noi_override != null && boe.pf_noi_override !== 0) ? boe.pf_noi_override : (egr_p - opex_p)
    return { rrp_pf, gpr_p, ltl_p, vac_p, bad_p, conc_p, mod_p, emp_p, oi_p, egr_p, ga_p, mkt_p, rm_p, pay_p, mgt_p, utl_p, tax_p, taxm_p, ins_p, noi_p }
  })
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
              {(['details','boe','noi','rr'] as Tab[]).map(t => (
                <button key={t} onClick={() => setTab(t)} style={{
                  padding:'8px 20px', border:'none', background:'none', cursor:'pointer',
                  fontFamily:"'DM Sans',sans-serif", fontSize:12, fontWeight:600,
                  color: tab===t ? '#0D1B2E' : '#8A9BB0',
                  borderBottom: tab===t ? '2px solid #C9A84C' : '2px solid transparent',
                  textTransform:'uppercase', letterSpacing:'0.08em',
                }}>
                  {t === 'details' ? 'Deal Details' : t === 'boe' ? 'BOE' : t === 'noi' ? 'NOI Walk' : 'Rent Roll Analysis'}
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
          {tab === 'rr' && (
            <RentRollPanel savedData={rentRollData} onSave={setRentRollData} dealName={deal.name} />
          )}
        </div>
      </div>
    </div>
  )
}
