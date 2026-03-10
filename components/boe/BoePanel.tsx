'use client'
import { useState, useEffect, useCallback, useRef } from 'react'
import type { Deal, BoeData, BoeT12, BoeAdjs } from '@/lib/types'
import * as XLSX from 'xlsx'

interface Props {
  deal: Deal
  boe: BoeData | null
  onSave: (boe: BoeData) => Promise<any>
}

const EMPTY_T12: BoeT12 = { gpr:0,ltl:0,vac:0,bad:0,conc:0,mod:0,emp:0,oi:0,ga:0,mkt:0,rm:0,pay:0,mgt:0,utl:0,tax:0,taxm:0,ins:0 }

const DEFAULT_ADJS: BoeAdjs = {
  gpr:'1.6', ltl:'3', vac:'5.0', bad:'', conc:'', mod:'', emp:'',
  oi:'', ga:'', mkt:'', rm:'', pay:'', mgt:'2.5', utl:'', tax:'', taxm:'', ins:'550',
}

const BOE_MAP: Record<string, string[]> = {
  gpr:  ['gpr'],
  ltl:  ['ltl'],
  vac:  ['vac'],
  bad:  ['bad'],
  conc: ['conc'],
  mod:  ['mod'],
  emp:  ['emp'],
  // All other income rows sum to oi
  oi:   ['app','admin','dam','mtm','pet_f','pet_r','int','term','cable','tran','nsf','late',
          'wash','park','stor','park_c','cell','bill','prem','pest','oi','comm',
          'reim_e','reim_w','reim_g','reim_o','reim_t','key','cc','leg','amn','fsd',
          'vend','p/d','p/d_u','gym','club','oi1','oi2','oi3','oi4','ri'],
  // G&A = Administrative + Licenses
  ga:   ['ga','lic'],
  // Marketing
  mkt:  ['adv'],
  // R&M = repairs + contract services + turnover + landscaping
  rm:   ['rm','cont','turn','ls'],
  // Payroll
  pay:  ['pay'],
  // Management fee
  mgt:  ['mgt'],
  // Utilities = all utility lines
  utl:  ['elec','wat','gas','utl','trash'],
  // Real estate taxes = all tax lines
  tax:  ['tax','tax_c','tax_o','tax_p'],
  // Misc taxes
  taxm: [],
  // Insurance
  ins:  ['ins'],
}

function fmt(n: number) { return n < 0 ? `-$${Math.abs(Math.round(n)).toLocaleString()}` : `$${Math.round(n).toLocaleString()}` }
function fmtpu(n: number, u: number) { if (!u) return '—'; return `$${Math.round(n/u).toLocaleString()}` }
function fmtPct(n: number) { return n.toFixed(1) + '%' }

export default function BoePanel({ deal, boe, onSave }: Props) {
  const units = deal.units ?? 1
  const pp = deal.purchase_price ?? 0

  const [t12, setT12] = useState<BoeT12>(boe?.t12 && Object.keys(boe.t12).length ? boe.t12 : EMPTY_T12)
  const [adjs, setAdjs] = useState<BoeAdjs>(boe?.adjs ?? DEFAULT_ADJS)
  const [notes, setNotes] = useState<Record<string,string>>(boe?.notes ?? {})
  const [period, setPeriod] = useState(boe?.period ?? '')
  const [status, setStatus] = useState('')
  const [saving, setSaving] = useState(false)
  const [showPayroll, setShowPayroll] = useState(true)
  const [showRM, setShowRM] = useState(true)
  const [showTax, setShowTax] = useState(true)
  const [payroll, setPayroll] = useState<Record<string,string>>(boe?.payroll ?? {
    'py-pm':'85000','py-am':'60000','py-la':'45000','py-bi':'0.25',
    'py-ms':'80000','py-mt':'60000','py-ma':'40000','py-bo':'0.05','py-ben':'0.325'
  })
  const [rmi, setRmi] = useState<Record<string,string>>(boe?.rmi ?? { 'rmi-rm':'750','rmi-ct':'420','rmi-tu':'350' })
  const [taxHelper, setTaxHelper] = useState<Record<string,string>>(boe?.tax_helper ?? { 'tx-mil':'','tx-rat':'','tx-nad':'','tx-sf':'100' })

  // Load from saved boe on deal change
  useEffect(() => {
    if (boe) {
      setT12(boe.t12 && Object.keys(boe.t12).length ? boe.t12 : EMPTY_T12)
      setAdjs(boe.adjs ?? DEFAULT_ADJS)
      setNotes(boe.notes ?? {})
      setPeriod(boe.period ?? '')
      if (boe.payroll && Object.keys(boe.payroll).length) setPayroll(boe.payroll as any)
      if (boe.rmi && Object.keys(boe.rmi).length) setRmi(boe.rmi as any)
      if (boe.tax_helper && Object.keys(boe.tax_helper).length) setTaxHelper({...{'tx-sf':'100'}, ...boe.tax_helper as any})
    }
  }, [deal.name, boe?.updated_at])

  const v = (k: keyof BoeAdjs) => { const raw = adjs[k]; if (raw === undefined || raw === '') return null; const num = parseFloat(String(raw).replace(/[%,\$\s]/g, '')); return isNaN(num) ? null : num }

  // ── Compute all PF values ──────────────────────────────────
  const gpr_t = t12.gpr; const gpr_p = v('gpr')!=null ? gpr_t*(1+v('gpr')!/100) : gpr_t
  const ltl_t = t12.ltl; const ltl_p = t12.ltl*(1+(v('ltl')??3)/100)
  const vac_t = t12.vac; const vac_p = v('vac')!=null ? -(v('vac')!/100)*(gpr_p+ltl_p) : vac_t
  const bad_t = t12.bad; const bad_p = v('bad')!=null ? -(v('bad')!/100)*gpr_p : bad_t
  const conc_t= t12.conc;const conc_p= v('conc')!=null? -(v('conc')!/100)*gpr_p : conc_t
  const mod_t = t12.mod; const mod_p = v('mod')!=null ? -(v('mod')!/100)*gpr_p : mod_t
  const emp_t = t12.emp; const emp_p = v('emp')!=null ? -(v('emp')!/100)*gpr_p : emp_t
  const brr_t = gpr_t+ltl_t+vac_t+bad_t+conc_t+mod_t+emp_t
  const brr_p = gpr_p+ltl_p+vac_p+bad_p+conc_p+mod_p+emp_p
  const oi_t  = t12.oi;  const oi_p  = oi_t + (v('oi')??0)
  const egr_t = brr_t + oi_t; const egr_p = brr_p + oi_p

  // Payroll calc
  const pv = (k: string) => parseFloat(payroll[k] ?? '0') || 0
  const inBase = pv('py-pm')+pv('py-am')+pv('py-la')
  const outBase= pv('py-ms')+pv('py-mt')+pv('py-ma')
  const payCalc = inBase*(1+pv('py-bi')) + outBase*(1+pv('py-bo')) + (inBase+outBase)*pv('py-ben')

  // R&M calc
  const rv = (k: string) => parseFloat(rmi[k] ?? '0') || 0
  const rmCalc = (rv('rmi-rm')+rv('rmi-ct')+rv('rmi-tu'))*units

  // Tax calc
  const tv = (k: string) => parseFloat(taxHelper[k] ?? '0') || 0
  const taxCalc = pp * (tv('tx-rat')/100) * (tv('tx-mil')/1000) * (tv('tx-sf')/100) + tv('tx-nad')

  const ga_t  = t12.ga;  const ga_p  = ga_t  + (v('ga')??0)
  const mkt_t = t12.mkt; const mkt_p = mkt_t + (v('mkt')??0)
  const rm_p  = adjs['rm']  ? parseFloat(adjs['rm']!)*units : (showRM ? rmCalc : t12.rm)
  const pay_p = adjs['pay'] ? parseFloat(adjs['pay']!) : (showPayroll ? payCalc : t12.pay)
  const mgt_p = ((v('mgt')??2.5)/100)*egr_p
  const utl_t = t12.utl; const utl_p = utl_t + (v('utl')??0)
  const tax_p = adjs['tax'] ? t12.tax+(v('tax')??0) : (showTax && taxCalc ? taxCalc : t12.tax+(v('tax')??0))
  const taxm_t= t12.taxm;const taxm_p= taxm_t+(v('taxm')??0)
  const ins_p = (v('ins')??550)*units

  const ctrl_t= t12.ga+t12.mkt+t12.rm+t12.pay
  const ctrl_p= ga_p+mkt_p+rm_p+pay_p
  const nctrl_t=t12.mgt+t12.utl+t12.tax+t12.taxm+t12.ins
  const nctrl_p=mgt_p+utl_p+tax_p+taxm_p+ins_p
  const opex_t= ctrl_t+nctrl_t; const opex_p = ctrl_p+nctrl_p
  const noi_t = egr_t-opex_t;   const noi_p  = egr_p-opex_p
  const cap_na = pp ? (noi_t/pp)*100 : 0
  const cap_adj= pp ? (noi_p/pp)*100 : 0

  async function handleSave() {
    setSaving(true)
    await onSave({ deal_name: deal.name, t12, adjs, notes, payroll: payroll as any, rmi: rmi as any, tax_helper: taxHelper as any, period } as any)
    // Save cap rate directly
    if (pp && cap_adj) {
      try {
        const crRes = await fetch('/api/cap-rates', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            deal_name: deal.name,
            noi_cap_rate: cap_adj,
            broker_cap_rate: null,
            purchase_price: pp / 1000,
          }),
        })
        if (!crRes.ok) console.error('cap-rate save failed', await crRes.text())
        else console.log('cap-rate saved:', cap_adj)
      } catch(err) { console.error('cap-rate fetch error', err) }
    }
    setSaving(false)
    setStatus('✓ Saved to database')
    setTimeout(() => setStatus(''), 2500)
  }

  function handleReset() {
    setAdjs(DEFAULT_ADJS)
    setStatus('ADJ values reset')
    setTimeout(() => setStatus(''), 2000)
  }

  // File upload
  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]; if (!file) return
    setStatus('Parsing T12…')
    try {
      const buf = await file.arrayBuffer()
      const wb = XLSX.read(buf, { type:'array', cellDates:true })

      // Prefer the monthly data sheet (not Overview or About)
      const sheetName = wb.SheetNames.find(n => !/overview|about/i.test(n) && wb.SheetNames.indexOf(n) > 0)
                     ?? wb.SheetNames[0]
      const ws = wb.Sheets[sheetName]
      const rows: any[][] = XLSX.utils.sheet_to_json(ws, { header:1, defval:'' })

      // Find header row (has 'Code' in col A)
      const hdrIdx = rows.findIndex(r => String(r[0]).trim().toLowerCase() === 'code')
      if (hdrIdx < 0) { setStatus('⚠ Could not find header row'); return }
      const hdr = rows[hdrIdx]

      // Find monthly columns (date objects or month names) — cols 3+ in monthly sheet
      const monthlyCols: number[] = []
      hdr.forEach((h: any, i: number) => {
        if (i >= 3) {
          if (typeof h === 'object' && h !== null) monthlyCols.push(i)
          else if (/jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec/i.test(String(h))) monthlyCols.push(i)
        }
      })
      // Fallback: use cols 3-14 if no monthly cols found
      const useCols = monthlyCols.length > 0 ? monthlyCols : Array.from({length:12},(_,i)=>i+3)

      const sumRow = (row: any[]) => useCols.reduce((s, c) => s + (parseFloat(String(row[c] ?? '').replace(/[,$]/g,'')) || 0), 0)

      // Build code map — accumulate values (same code can appear multiple times)
      const codeMap: Record<string, number> = {}
      // Also capture subtotal rows by label
      const labelMap: Record<string, number> = {}

      for (let i = hdrIdx+1; i < rows.length; i++) {
        const row = rows[i]
        const code = String(row[0] ?? '').trim().toLowerCase().replace(/[^a-z0-9_/]/g,'_')
        const label = String(row[1] ?? '').trim().toUpperCase()
        const val = sumRow(row)
        if (code) {
          codeMap[code] = (codeMap[code] ?? 0) + val
        }
        if (label) {
          labelMap[label] = val
        }
      }

      // Map to BOE buckets
      const newT12: BoeT12 = { ...EMPTY_T12 }

      // Direct code mappings (accumulates all rows with same code)
      newT12.gpr  = codeMap['gpr']  ?? 0
      newT12.ltl  = codeMap['ltl']  ?? 0
      newT12.vac  = codeMap['vac']  ?? 0   // sum of all vac rows
      newT12.bad  = codeMap['bad']  ?? 0   // sum of all bad rows
      newT12.conc = codeMap['conc'] ?? 0
      newT12.mod  = codeMap['mod']  ?? 0
      newT12.emp  = codeMap['emp']  ?? 0

      // Other Income — use TOTAL OTHER INCOME subtotal row if available
      newT12.oi = labelMap['TOTAL OTHER INCOME'] ?? BOE_MAP.oi.reduce((s, c) => s + (codeMap[c] ?? 0), 0)

      // Expenses — sum all matching codes
      newT12.ga   = (codeMap['ga']  ?? 0) + (codeMap['lic'] ?? 0)
      newT12.mkt  = codeMap['adv']  ?? 0
      newT12.rm   = (codeMap['rm']  ?? 0) + (codeMap['cont'] ?? 0) + (codeMap['turn'] ?? 0) + (codeMap['ls'] ?? 0)
      newT12.pay  = codeMap['pay']  ?? 0
      newT12.mgt  = codeMap['mgt']  ?? 0
      newT12.utl  = (codeMap['elec'] ?? 0) + (codeMap['wat'] ?? 0) + (codeMap['gas'] ?? 0) + (codeMap['utl'] ?? 0) + (codeMap['trash'] ?? 0)
      newT12.tax  = codeMap['tax'] ?? 0
      newT12.taxm = (codeMap['tax_c'] ?? 0) + (codeMap['tax_o'] ?? 0) + (codeMap['tax_p'] ?? 0)
      newT12.ins  = codeMap['ins']  ?? 0

      // Ensure loss lines are negative
      for (const k of ['vac','bad','conc','mod','emp'] as const) {
        if (newT12[k] > 0) newT12[k] = -newT12[k]
      }

      const periodLabel = `${useCols.length} months`
      setT12(newT12)
      setPeriod(periodLabel)
      setStatus(`✓ Loaded ${useCols.length} months from ${file.name}`)
    } catch(err) {
      setStatus('⚠ Parse error: ' + String(err))
    }
    e.target.value = ''
  }

  const a = (k: keyof BoeAdjs) => adjs[k] ?? ''
  const setA = (k: keyof BoeAdjs, val: string) => setAdjs(p => ({...p, [k]: val === '' ? '' : val}))
  const setN = (k: string, val: string) => setNotes(p => ({...p, [k]: val}))

  const COL = '196px 88px 60px 60px 108px 88px 60px 1fr'

  function Row({ k, label, t12v, pfv, isNeg=false, adjType='dollar', adjPlaceholder='', note=true }:
    { k: keyof BoeAdjs; label: string; t12v: number; pfv: number; isNeg?: boolean; adjType?: 'pct'|'dollar'|'ppu'; adjPlaceholder?: string; note?: boolean }) {
    const gprt = gpr_t || 1; const gprp = gpr_p || 1
    const vacBaseT = (gpr_t+ltl_t)||1; const vacBaseP = (gpr_p+ltl_p)||1
    const pctT = isNeg ? (k==='vac' ? Math.abs(t12v/vacBaseT)*100 : Math.abs(t12v/gprt)*100) : 0
    const pctP = isNeg ? (k==='vac' ? Math.abs(pfv/vacBaseP)*100 : Math.abs(pfv/gprp)*100) : 0
    return (
      <div style={{ display:'grid', gridTemplateColumns:COL, alignItems:'center', borderBottom:'1px solid rgba(13,27,46,0.04)', minHeight:36 }}>
        <div style={{ fontSize:12, color:'#334155', paddingLeft:14, paddingRight:8 }}>{label}</div>
        <div style={{ textAlign:'right', fontSize:12, fontVariantNumeric:'tabular-nums', paddingRight:8 }}>
          {fmt(t12v)}
          {isNeg && t12v !== 0 && <div style={{ fontSize:9, color:'#E57373' }}>{fmtPct(pctT)}</div>}
        </div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8 }}>{fmtpu(t12v, units)}</div>
        <div style={{ textAlign:'center', fontSize:10, color:'#8A9BB0', paddingRight:4 }}>
          {isNeg && t12v !== 0 ? <span style={{color:'#E57373',fontSize:9}}>{fmtPct(pctT)}</span> : ''}
        </div>
        <div style={{ padding:'2px 6px' }}>
          <input
            type="text"
            value={a(k)}
            onChange={e => setA(k, e.target.value)}
            placeholder={adjPlaceholder || (adjType==='pct'?'%':adjType==='ppu'?'$/unit':'$ adj')}
            onKeyDown={e => {
              if (e.key === 'Tab') {
                const panel = (e.currentTarget as HTMLElement).closest('[data-boe-panel]')
                const inputs = Array.from((panel ?? document).querySelectorAll<HTMLInputElement>('input[data-adj]'))
                const idx = inputs.indexOf(e.currentTarget as HTMLInputElement)
                if (!e.shiftKey && idx >= 0 && idx < inputs.length - 1) {
                  e.preventDefault()
                  inputs[idx+1].focus()
                } else if (e.shiftKey && idx > 0) {
                  e.preventDefault()
                  inputs[idx-1].focus()
                }
              }
            }}
            data-adj="1"
            style={{ width:'100%', padding:'3px 6px', border:'1px solid #F0B429', borderRadius:4, fontSize:11, fontFamily:"'DM Sans',sans-serif", background:'rgba(240,180,41,0.06)', outline:'none', textAlign:'right' }} />
        </div>
        <div style={{ textAlign:'right', fontSize:12, fontVariantNumeric:'tabular-nums', fontWeight:600, color:'#0D1B2E', paddingRight:8 }}>
          {fmt(pfv)}
          {isNeg && pfv !== 0 && <div style={{ fontSize:9, color:'#E57373' }}>{fmtPct(pctP)}</div>}
        </div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8 }}>{fmtpu(pfv, units)}</div>
        {note && <div style={{ padding:'2px 6px 2px 4px' }}>
          <input type="text" tabIndex={-1} value={notes[k as string] ?? ''} onChange={e => setN(k as string, e.target.value)}
            placeholder="Notes…" style={{ width:'100%', padding:'3px 6px', border:'1px solid rgba(13,27,46,0.1)', borderRadius:4, fontSize:11, fontFamily:"'DM Sans',sans-serif", outline:'none' }} />
        </div>}
      </div>
    )
  }

  function SubRow({ label, t12v, pfv }: { label: string; t12v: number; pfv: number }) {
    return (
      <div style={{ display:'grid', gridTemplateColumns:COL, background:'rgba(13,27,46,0.03)', borderBottom:'1px solid rgba(13,27,46,0.06)', minHeight:34 }}>
        <div style={{ fontSize:12, fontWeight:700, color:'#0D1B2E', paddingLeft:14 }}>{label}</div>
        <div style={{ textAlign:'right', fontSize:12, fontWeight:700, fontVariantNumeric:'tabular-nums', paddingRight:8 }}>{fmt(t12v)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8 }}>{fmtpu(t12v,units)}</div>
        <div/>
        <div/>
        <div style={{ textAlign:'right', fontSize:12, fontWeight:700, fontVariantNumeric:'tabular-nums', color:'#0D1B2E', paddingRight:8 }}>{fmt(pfv)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8 }}>{fmtpu(pfv,units)}</div>
        <div/>
      </div>
    )
  }

  function SectionHead(label: string) {
    return <div style={{ padding:'8px 14px', background:'rgba(13,27,46,0.05)', fontSize:10, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.12em', textTransform:'uppercase' }}>{label}</div>
  }

  return (
    <div data-boe-panel="1" style={{ fontSize:13, fontFamily:"'DM Sans',sans-serif" }}>
      {/* KPI Strip */}
      <div style={{ display:'grid', gridTemplateColumns:'repeat(4,1fr)', background:'#0D1B2E', padding:'16px 20px', gap:1 }}>
        {[
          { label:'T12 NOI', val: pp ? `${fmt(noi_t)}` : '—', sub: pp ? `${fmtpu(noi_t,units)}/unit` : '' },
          { label:'Pro Forma NOI', val: fmt(noi_p), sub: fmtpu(noi_p,units)+'/unit', gold:true },
          { label:'Cap Rate (Non-Adj)', val: pp && cap_na ? cap_na.toFixed(2)+'%' : '—', sub:'T12 NOI ÷ Ask Price' },
          { label:'Cap Rate (Adj)', val: pp && cap_adj ? cap_adj.toFixed(2)+'%' : '—', sub:'PF NOI ÷ Ask Price', gold:true },
        ].map(k => (
          <div key={k.label} style={{ padding:'8px 16px', borderRight:'1px solid rgba(255,255,255,0.07)' }}>
            <div style={{ fontSize:9, color:'rgba(255,255,255,0.4)', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:4 }}>{k.label}</div>
            <div style={{ fontSize:20, fontWeight:700, color: k.gold ? '#F0B429' : '#fff', fontFamily:"'Cormorant Garamond',serif" }}>{k.val}</div>
            {k.sub && <div style={{ fontSize:10, color:'rgba(255,255,255,0.35)', marginTop:2 }}>{k.sub}</div>}
          </div>
        ))}
      </div>

      {/* Upload bar */}
      <div style={{ display:'flex', alignItems:'center', gap:10, padding:'8px 14px', background:'rgba(13,27,46,0.02)', borderBottom:'1px solid rgba(13,27,46,0.07)', flexWrap:'wrap' }}>
        <label style={{ display:'inline-flex', alignItems:'center', gap:5, padding:'5px 14px', borderRadius:5, background:'#F0B429', color:'#0D1B2E', fontSize:11, fontWeight:700, cursor:'pointer', letterSpacing:'0.05em' }}>
          ↑ Upload redIQ T12
          <input type="file" accept=".xlsx,.xls" style={{ display:'none' }} onChange={handleFile} />
        </label>
        {period && <span style={{ fontSize:11, color:'#8A9BB0' }}>Period: {period}</span>}
        {status && <span style={{ fontSize:11, color: status.startsWith('⚠') ? '#C0392B' : status.startsWith('✓') ? '#2E7D50' : '#8A9BB0' }}>{status}</span>}
      </div>

      {/* Column headers */}
      <div style={{ display:'grid', gridTemplateColumns:COL, background:'rgba(13,27,46,0.04)', borderBottom:'1px solid rgba(13,27,46,0.08)' }}>
        {['Line Item','T12 Total','$/Unit','%','ADJ','PF Total','PF $/Unit','Notes'].map(h => (
          <div key={h} style={{ padding:'7px 8px', fontSize:9, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', textAlign: h==='Line Item'?'left':'right', paddingLeft: h==='Line Item'?14:undefined }}>{h}</div>
        ))}
      </div>

      {/* Income */}
      {SectionHead('Income')}
      <Row k="gpr" label="Gross Potential Rent" t12v={gpr_t} pfv={gpr_p} adjType="pct" adjPlaceholder="1.6%" />
      <Row k="ltl" label="(Loss to Lease) / GTL" t12v={ltl_t} pfv={ltl_p} adjType="pct" adjPlaceholder="3%" />
      <Row k="vac" label="Vacancy" t12v={vac_t} pfv={vac_p} isNeg adjType="pct" adjPlaceholder="5.0%" />
      <Row k="bad" label="Bad Debt" t12v={bad_t} pfv={bad_p} isNeg adjType="pct" adjPlaceholder="% of GPR" />
      <Row k="conc" label="Concessions" t12v={conc_t} pfv={conc_p} isNeg adjType="pct" adjPlaceholder="% of GPR" />
      <Row k="mod" label="Model Units" t12v={mod_t} pfv={mod_p} isNeg adjType="pct" adjPlaceholder="% of GPR" />
      <Row k="emp" label="Employee Units" t12v={emp_t} pfv={emp_p} isNeg adjType="pct" adjPlaceholder="% of GPR" />
      <SubRow label="Base Rental Revenue" t12v={brr_t} pfv={brr_p} />
      <Row k="oi" label="Other Income" t12v={oi_t} pfv={oi_p} adjType="dollar" adjPlaceholder="$ adj" />
      <div style={{ display:'grid', gridTemplateColumns:COL, background:'rgba(13,27,46,0.06)', borderBottom:'1px solid rgba(13,27,46,0.1)', minHeight:36 }}>
        <div style={{ fontSize:12, fontWeight:700, color:'#0D1B2E', paddingLeft:14, display:'flex', alignItems:'center' }}>Effective Gross Revenue</div>
        <div style={{ textAlign:'right', fontSize:13, fontWeight:700, fontVariantNumeric:'tabular-nums', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(egr_t)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(egr_t,units)}</div>
        <div/><div/>
        <div style={{ textAlign:'right', fontSize:13, fontWeight:700, color:'#0D1B2E', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(egr_p)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(egr_p,units)}</div>
        <div/>
      </div>

      {/* Controllable Expenses */}
      {SectionHead('Controllable Expenses')}
      <Row k="ga" label="G&A" t12v={ga_t} pfv={ga_p} adjType="dollar" adjPlaceholder="$ adj" />
      <Row k="mkt" label="Marketing" t12v={mkt_t} pfv={mkt_p} adjType="dollar" adjPlaceholder="$ adj" />

      {/* R&M with build-up */}
      <div style={{ display:'grid', gridTemplateColumns:COL, borderBottom:'1px solid rgba(13,27,46,0.04)', minHeight:36 }}>
        <div style={{ fontSize:12, color:'#334155', paddingLeft:14, display:'flex', alignItems:'center', gap:6 }}>
          R&M
          <button onClick={() => setShowRM(p=>!p)} style={{ fontSize:9, padding:'1px 6px', borderRadius:4, border:'1px solid rgba(13,27,46,0.15)', background:'transparent', cursor:'pointer', color:'#8A9BB0' }}>Build-up</button>
        </div>
        <div style={{ textAlign:'right', fontSize:12, fontVariantNumeric:'tabular-nums', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(t12.rm)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(t12.rm,units)}</div>
        <div/>
        <div style={{ padding:'2px 6px' }}>
          <input type="number" value={a('rm')} onChange={e => setA('rm',e.target.value)} placeholder="$/unit"
            style={{ width:'100%', padding:'3px 6px', border:'1px solid #F0B429', borderRadius:4, fontSize:11, background:'rgba(240,180,41,0.06)', outline:'none', textAlign:'right', fontFamily:"'DM Sans',sans-serif" }} />
        </div>
        <div style={{ textAlign:'right', fontSize:12, fontWeight:600, color:'#0D1B2E', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(rm_p)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(rm_p,units)}</div>
        <div style={{ padding:'2px 6px 2px 4px' }}>
          <input type="text" value={notes['rm']??''} onChange={e => setN('rm',e.target.value)} placeholder="Notes…"
            style={{ width:'100%', padding:'3px 6px', border:'1px solid rgba(13,27,46,0.1)', borderRadius:4, fontSize:11, outline:'none', fontFamily:"'DM Sans',sans-serif" }} />
        </div>
      </div>
      {showRM && (
        <div style={{ background:'rgba(240,180,41,0.04)', padding:'10px 14px 12px', borderBottom:'1px solid rgba(13,27,46,0.06)' }}>
          <div style={{ fontSize:10, fontWeight:700, color:'#8A6500', letterSpacing:'0.1em', marginBottom:8 }}>R&M BUILD-UP ($/unit/yr)</div>
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:8 }}>
            {[['Base R&M','rmi-rm','750'],['Contract Svcs','rmi-ct','420'],['Turnover','rmi-tu','350']].map(([l,k,ph]) => (
              <div key={k}><label style={{ fontSize:10, color:'#8A9BB0', display:'block', marginBottom:3 }}>{l}</label>
                <input type="number" value={rmi[k]??''} onChange={e => setRmi(p=>({...p,[k]:e.target.value}))} placeholder={ph}
                  style={{ width:'100%', padding:'5px 8px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:5, fontSize:12, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
            ))}
          </div>
          <div style={{ marginTop:8, fontSize:11, color:'#8A6500', fontWeight:600 }}>Total: {fmtpu(rmCalc,1)}/unit/yr → {fmt(rmCalc)} ({units} units)</div>
        </div>
      )}

      {/* Payroll with build-up */}
      <div style={{ display:'grid', gridTemplateColumns:COL, borderBottom:'1px solid rgba(13,27,46,0.04)', minHeight:36 }}>
        <div style={{ fontSize:12, color:'#334155', paddingLeft:14, display:'flex', alignItems:'center', gap:6 }}>
          Payroll
          <button onClick={() => setShowPayroll(p=>!p)} style={{ fontSize:9, padding:'1px 6px', borderRadius:4, border:'1px solid rgba(13,27,46,0.15)', background:'transparent', cursor:'pointer', color:'#8A9BB0' }}>Build-up</button>
        </div>
        <div style={{ textAlign:'right', fontSize:12, fontVariantNumeric:'tabular-nums', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(t12.pay)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(t12.pay,units)}</div>
        <div/>
        <div style={{ padding:'2px 6px' }}>
          <input type="number" value={a('pay')} onChange={e => setA('pay',e.target.value)} placeholder="$ override"
            style={{ width:'100%', padding:'3px 6px', border:'1px solid #F0B429', borderRadius:4, fontSize:11, background:'rgba(240,180,41,0.06)', outline:'none', textAlign:'right', fontFamily:"'DM Sans',sans-serif" }} />
        </div>
        <div style={{ textAlign:'right', fontSize:12, fontWeight:600, color:'#0D1B2E', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(pay_p)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(pay_p,units)}</div>
        <div style={{ padding:'2px 6px 2px 4px' }}>
          <input type="text" value={notes['pay']??''} onChange={e => setN('pay',e.target.value)} placeholder="Notes…"
            style={{ width:'100%', padding:'3px 6px', border:'1px solid rgba(13,27,46,0.1)', borderRadius:4, fontSize:11, outline:'none', fontFamily:"'DM Sans',sans-serif" }} />
        </div>
      </div>
      {showPayroll && (
        <div style={{ background:'rgba(13,27,46,0.02)', padding:'10px 14px 12px', borderBottom:'1px solid rgba(13,27,46,0.06)' }}>
          <div style={{ fontSize:10, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.1em', marginBottom:8 }}>PAYROLL BUILD-UP</div>
          <div style={{ display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:8, marginBottom:8 }}>
            <div style={{ gridColumn:'span 4', fontSize:10, fontWeight:600, color:'#0D1B2E', letterSpacing:'0.05em' }}>INSIDE MANAGEMENT</div>
            {[['Prop Manager','py-pm','85000'],['Asst Manager','py-am','60000'],['Leasing Agent','py-la','45000'],['Bonus %','py-bi','0.25']].map(([l,k,ph]) => (
              <div key={k}><label style={{ fontSize:10, color:'#8A9BB0', display:'block', marginBottom:3 }}>{l}</label>
                <input type="number" value={payroll[k]??''} onChange={e => setPayroll(p=>({...p,[k]:e.target.value}))} placeholder={ph}
                  style={{ width:'100%', padding:'5px 8px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:5, fontSize:12, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
            ))}
            <div style={{ gridColumn:'span 4', fontSize:10, fontWeight:600, color:'#0D1B2E', letterSpacing:'0.05em', marginTop:4 }}>OUTSIDE MANAGEMENT</div>
            {[['Maint Supervisor','py-ms','80000'],['Maint Tech','py-mt','60000'],['Maint Asst','py-ma','40000'],['Bonus %','py-bo','0.05']].map(([l,k,ph]) => (
              <div key={k}><label style={{ fontSize:10, color:'#8A9BB0', display:'block', marginBottom:3 }}>{l}</label>
                <input type="number" value={payroll[k]??''} onChange={e => setPayroll(p=>({...p,[k]:e.target.value}))} placeholder={ph}
                  style={{ width:'100%', padding:'5px 8px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:5, fontSize:12, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
            ))}
            <div><label style={{ fontSize:10, color:'#8A9BB0', display:'block', marginBottom:3 }}>Benefits %</label>
              <input type="number" value={payroll['py-ben']??''} onChange={e => setPayroll(p=>({...p,'py-ben':e.target.value}))} placeholder="0.325"
                style={{ width:'100%', padding:'5px 8px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:5, fontSize:12, fontFamily:"'DM Sans',sans-serif" }} />
            </div>
          </div>
          <div style={{ fontSize:11, color:'#0D1B2E', fontWeight:600 }}>Total Payroll: {fmt(payCalc)}</div>
        </div>
      )}

      <SubRow label="Total Controllable" t12v={ctrl_t} pfv={ctrl_p} />

      {/* Non-Controllable */}
      {SectionHead('Non-Controllable Expenses')}
      <Row k="mgt" label="Mgmt Fee" t12v={t12.mgt} pfv={mgt_p} adjType="pct" adjPlaceholder="2.5%" />
      <Row k="utl" label="Utilities" t12v={utl_t} pfv={utl_p} adjType="dollar" adjPlaceholder="$ adj" />

      {/* RE Tax with build-up */}
      <div style={{ display:'grid', gridTemplateColumns:COL, borderBottom:'1px solid rgba(13,27,46,0.04)', minHeight:36 }}>
        <div style={{ fontSize:12, color:'#334155', paddingLeft:14, display:'flex', alignItems:'center', gap:6 }}>
          Real Estate Taxes
          <button onClick={() => setShowTax(p=>!p)} style={{ fontSize:9, padding:'1px 6px', borderRadius:4, border:'1px solid rgba(13,27,46,0.15)', background:'transparent', cursor:'pointer', color:'#8A9BB0' }}>Build-up</button>
        </div>
        <div style={{ textAlign:'right', fontSize:12, fontVariantNumeric:'tabular-nums', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(t12.tax)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(t12.tax,units)}</div>
        <div/>
        <div style={{ padding:'2px 6px' }}>
          <input type="text" inputMode="decimal" data-adj="1" value={a('tax')} onChange={e => setA('tax', e.target.value)}
            placeholder="$ adj"
            onKeyDown={e => {
              if (e.key === 'Tab') {
                const panel = (e.currentTarget as HTMLElement).closest('[data-boe-panel]')
                const inputs = Array.from((panel ?? document).querySelectorAll<HTMLInputElement>('input[data-adj]'))
                const idx = inputs.indexOf(e.currentTarget as HTMLInputElement)
                if (!e.shiftKey && idx >= 0 && idx < inputs.length - 1) { e.preventDefault(); inputs[idx+1].focus() }
                else if (e.shiftKey && idx > 0) { e.preventDefault(); inputs[idx-1].focus() }
              }
            }}
            style={{ width:'100%', padding:'3px 6px', border:'1px solid #F0B429', borderRadius:4, fontSize:11, background:'rgba(240,180,41,0.06)', outline:'none', textAlign:'right', fontFamily:"'DM Sans',sans-serif" }} />
        </div>
        <div style={{ textAlign:'right', fontSize:12, fontWeight:600, color:'#0D1B2E', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(tax_p)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'#8A9BB0', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(tax_p,units)}</div>
        <div style={{ padding:'2px 6px 2px 4px' }}>
          <input type="text" value={notes['tax']??''} onChange={e => setN('tax',e.target.value)} placeholder="Notes…"
            style={{ width:'100%', padding:'3px 6px', border:'1px solid rgba(13,27,46,0.1)', borderRadius:4, fontSize:11, outline:'none', fontFamily:"'DM Sans',sans-serif" }} />
        </div>
      </div>
      {showTax && (
        <div style={{ background:'rgba(13,27,46,0.02)', padding:'10px 14px 12px', borderBottom:'1px solid rgba(13,27,46,0.06)' }}>
          <div style={{ fontSize:10, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.1em', marginBottom:8 }}>TAX BUILD-UP</div>
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:8 }}>
            {[['Millage Rate (per $1K)','tx-mil',''],['Assessment Ratio %','tx-rat',''],['State Factor %','tx-sf','100'],['Non-Ad Valorem ($)','tx-nad','']].map(([l,k,ph]) => (
              <div key={k}><label style={{ fontSize:10, color:'#8A9BB0', display:'block', marginBottom:3 }}>{l}</label>
                <input type="number" value={taxHelper[k]??''} onChange={e => setTaxHelper(p=>({...p,[k]:e.target.value}))} placeholder={ph}
                  style={{ width:'100%', padding:'5px 8px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:5, fontSize:12, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
            ))}
          </div>
          {taxCalc > 0 && <div style={{ marginTop:8, fontSize:11, color:'#0D1B2E', fontWeight:600 }}>Est. Tax: {fmt(taxCalc)}</div>}
        </div>
      )}

      <Row k="taxm" label="Misc Taxes" t12v={taxm_t} pfv={taxm_p} adjType="dollar" adjPlaceholder="$ adj" />
      <Row k="ins" label="Insurance" t12v={t12.ins} pfv={ins_p} adjType="ppu" adjPlaceholder="550" />
      <SubRow label="Total Non-Controllable" t12v={nctrl_t} pfv={nctrl_p} />
      <SubRow label="Total OpEx" t12v={opex_t} pfv={opex_p} />

      {/* NOI */}
      <div style={{ display:'grid', gridTemplateColumns:COL, background:'#0D1B2E', minHeight:42 }}>
        <div style={{ fontSize:13, fontWeight:700, color:'#fff', paddingLeft:14, display:'flex', alignItems:'center' }}>NOI</div>
        <div style={{ textAlign:'right', fontSize:14, fontWeight:700, color:'#fff', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(noi_t)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'rgba(255,255,255,0.5)', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(noi_t,units)}</div>
        <div/><div/>
        <div style={{ textAlign:'right', fontSize:14, fontWeight:700, color:'#F0B429', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmt(noi_p)}</div>
        <div style={{ textAlign:'right', fontSize:10, color:'rgba(255,255,255,0.5)', paddingRight:8, display:'flex', alignItems:'center', justifyContent:'flex-end' }}>{fmtpu(noi_p,units)}</div>
        <div/>
      </div>

      {/* Cap Rate Summary */}
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:0, borderTop:'2px solid rgba(13,27,46,0.08)' }}>
        <div style={{ padding:'16px 20px', borderRight:'1px solid rgba(13,27,46,0.08)' }}>
          <div style={{ fontSize:10, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.12em', textTransform:'uppercase', marginBottom:10 }}>Pricing</div>
          {[['Purchase Price', pp ? fmt(pp) : '—'],['Per Unit', pp && units ? '$'+Math.round(pp/units).toLocaleString() : '—']].map(([l,v]) => (
            <div key={l} style={{ display:'flex', justifyContent:'space-between', padding:'4px 0', borderBottom:'1px solid rgba(13,27,46,0.05)' }}>
              <span style={{ fontSize:12, color:'#8A9BB0' }}>{l}</span>
              <span style={{ fontSize:13, fontWeight:600, color:'#0D1B2E' }}>{v}</span>
            </div>
          ))}
        </div>
        <div style={{ padding:'16px 20px' }}>
          <div style={{ fontSize:10, fontWeight:700, color:'#8A9BB0', letterSpacing:'0.12em', textTransform:'uppercase', marginBottom:10 }}>Cap Rates</div>
          {[['T12 NOI',fmt(noi_t)],['PF NOI',fmt(noi_p)],['Cap Rate (Non-Adj)', pp ? cap_na.toFixed(2)+'%' : '—'],['Cap Rate (Adj)', pp ? cap_adj.toFixed(2)+'%' : '—']].map(([l,v]) => (
            <div key={l} style={{ display:'flex', justifyContent:'space-between', padding:'4px 0', borderBottom:'1px solid rgba(13,27,46,0.05)' }}>
              <span style={{ fontSize:12, color:'#8A9BB0' }}>{l}</span>
              <span style={{ fontSize:13, fontWeight:600, color: l.includes('Adj') ? '#2E7D50' : '#0D1B2E' }}>{v}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Footer */}
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', padding:'12px 16px', borderTop:'1px solid rgba(13,27,46,0.08)', background:'rgba(13,27,46,0.02)' }}>
        <div style={{ display:'flex', gap:8, alignItems:'center' }}>
          <button onClick={handleReset} style={{ padding:'6px 14px', border:'1px solid rgba(13,27,46,0.15)', borderRadius:6, background:'#fff', color:'#8A9BB0', fontSize:11, cursor:'pointer', fontFamily:"'DM Sans',sans-serif" }}>Reset ADJ</button>
          {status && <span style={{ fontSize:11, color: status.startsWith('✓') ? '#2E7D50' : '#8A9BB0' }}>{status}</span>}
        </div>
        <button onClick={handleSave} disabled={saving} style={{ padding:'8px 22px', background: saving?'#8A9BB0':'#0D1B2E', color:'#F0B429', border:'none', borderRadius:7, fontSize:12, fontWeight:700, cursor: saving?'not-allowed':'pointer', fontFamily:"'DM Sans',sans-serif", letterSpacing:'0.05em' }}>
          {saving ? 'Saving…' : 'Save BOE'}
        </button>
      </div>
    </div>
  )
}
