'use client'
import { useState, useEffect } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, fmtUnit, ALL_STATUSES } from '@/lib/utils'
import BoePanel from '../boe/BoePanel'

interface Props {
  deal: Deal
  boe: BoeData | null
  capRate: CapRate | null
  onClose: () => void
  onSave: (updates: Partial<Deal> & { name: string }) => Promise<any>
  onSaveBoe: (boe: BoeData) => Promise<any>
}

type Tab = 'details' | 'boe'

export default function DealModal({ deal, boe, capRate, onClose, onSave, onSaveBoe }: Props) {
  const [tab, setTab] = useState<Tab>('details')
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
  })
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)

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
    })
    setTab('details')
  }, [deal.name])

  const pp = parseFloat(form.purchase_price) || null
  const u = parseInt(form.units) || null
  const ppu = pp && u ? Math.round(pp / u) : deal.price_per_unit
  const soldP = parseFloat(form.sold_price) || null
  const guidanceDiff = soldP && pp ? soldP - pp : null

  async function handleSave() {
    setSaving(true)
    await onSave({
      name: deal.name,
      status: form.status,
      purchase_price: pp,
      units: u,
      year_built: parseInt(form.year_built) || null,
      broker: form.broker || null,
      bid_due_date: form.bid_due_date || null,
      price_per_unit: ppu,
      buyer: form.buyer || null,
      seller: form.seller || null,
      sold_price: soldP,
    })
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
    <div style={{ position:'fixed', inset:0, background:'rgba(13,27,46,0.55)', zIndex:2000, display:'flex', alignItems:'center', justifyContent:'center', padding:16 }}
      onClick={onClose}>
      <div style={{ background:'#fff', borderRadius:16, width:'min(1080px,96vw)', maxHeight:'94vh', display:'flex', flexDirection:'column', overflow:'hidden' }}
        onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div style={{ padding:'20px 28px 0', borderBottom:'1px solid rgba(13,27,46,0.08)', flexShrink:0 }}>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', marginBottom:14 }}>
            <div>
              <a
                href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(deal.name)}`}
                target="_blank"
                rel="noopener noreferrer"
                title="Search on Google Maps"
                style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:22, fontWeight:700, color:'#0D1B2E', textDecoration:'none', display:'inline-block' }}
                onMouseEnter={e => (e.currentTarget.style.color = '#C9A84C')}
                onMouseLeave={e => (e.currentTarget.style.color = '#0D1B2E')}
              >
                {deal.name} <span style={{ fontSize:14, verticalAlign:'middle' }}>↗</span>
              </a>
              <div style={{ fontSize:12, color:'#8A9BB0', marginTop:3 }}>📍 {deal.market}</div>
            </div>
            <button onClick={onClose} style={{ background:'none', border:'none', cursor:'pointer', color:'#8A9BB0', fontSize:20, padding:4, lineHeight:1 }}>✕</button>
          </div>

          {/* Tabs */}
          <div style={{ display:'flex', gap:0 }}>
            {(['details','boe'] as Tab[]).map(t => (
              <button key={t} onClick={() => setTab(t)} style={{
                padding:'8px 20px', border:'none', background:'none', cursor:'pointer',
                fontFamily:"'DM Sans',sans-serif", fontSize:12, fontWeight:600,
                color: tab===t ? '#0D1B2E' : '#8A9BB0',
                borderBottom: tab===t ? '2px solid #C9A84C' : '2px solid transparent',
                textTransform:'uppercase', letterSpacing:'0.08em',
              }}>
                {t === 'details' ? 'Deal Details' : 'BOE Underwriting'}
                {t === 'boe' && boe && Object.keys(boe.t12 ?? {}).length > 0 && (
                  <span style={{ marginLeft:6, background:'#2E7D50', color:'#fff', borderRadius:8, padding:'1px 6px', fontSize:9 }}>T12</span>
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Body */}
        <div style={{ flex:1, overflowY:'auto' }}>
          {tab === 'details' && (
            <div style={{ padding:'24px 28px' }}>
              <div style={{ display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:16 }}>
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
                  <input style={inputStyle} type="number" value={form.year_built} onChange={e => setForm(p => ({...p, year_built:e.target.value}))} /></div>

                <div><label style={labelStyle}>Broker</label>
                  <input style={inputStyle} type="text" value={form.broker} onChange={e => setForm(p => ({...p, broker:e.target.value}))} /></div>

                <div><label style={labelStyle}>Bid Due Date</label>
                  <input style={inputStyle} type="date" value={form.bid_due_date} onChange={e => setForm(p => ({...p, bid_due_date:e.target.value}))} /></div>

                <div><label style={labelStyle}>Buyer</label>
                  <input style={inputStyle} type="text" placeholder="Acquiring entity…" value={form.buyer} onChange={e => setForm(p => ({...p, buyer:e.target.value}))} /></div>

                <div><label style={labelStyle}>Seller</label>
                  <input style={inputStyle} type="text" placeholder="Selling entity…" value={form.seller} onChange={e => setForm(p => ({...p, seller:e.target.value}))} /></div>

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

                {/* Comments — full width */}
                <div style={{ gridColumn:'span 3' }}>
                  <label style={labelStyle}>Comments</label>
                  <div style={{ padding:'12px 14px', border:'1px solid rgba(13,27,46,0.08)', borderRadius:8, fontSize:13, color:'#444', background:'rgba(13,27,46,.015)', lineHeight:1.7, whiteSpace:'pre-wrap', maxHeight:200, overflowY:'auto' }}>
                    {deal.comments || 'No comments on file.'}
                  </div>
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
            <BoePanel deal={deal} boe={boe} onSave={onSaveBoe} />
          )}
        </div>
      </div>
    </div>
  )
}
'use client'
import { useState, useEffect } from 'react'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, fmtUnit, ALL_STATUSES } from '@/lib/utils'
import BoePanel from '../boe/BoePanel'

interface Props {
  deal: Deal
  boe: BoeData | null
  capRate: CapRate | null
  onClose: () => void
  onSave: (updates: Partial<Deal> & { name: string }) => Promise<any>
  onSaveBoe: (boe: BoeData) => Promise<any>
}

type Tab = 'details' | 'boe'

export default function DealModal({ deal, boe, capRate, onClose, onSave, onSaveBoe }: Props) {
  const [tab, setTab] = useState<Tab>('details')
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
  })
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)

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
    })
    setTab('details')
  }, [deal.name])

  const pp = parseFloat(form.purchase_price) || null
  const u = parseInt(form.units) || null
  const ppu = pp && u ? Math.round(pp / u) : deal.price_per_unit
  const soldP = parseFloat(form.sold_price) || null
  const guidanceDiff = soldP && pp ? soldP - pp : null

  async function handleSave() {
    setSaving(true)
    await onSave({
      name: deal.name,
      status: form.status,
      purchase_price: pp,
      units: u,
      year_built: parseInt(form.year_built) || null,
      broker: form.broker || null,
      bid_due_date: form.bid_due_date || null,
      price_per_unit: ppu,
      buyer: form.buyer || null,
      seller: form.seller || null,
      sold_price: soldP,
    })
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
    <div style={{ position:'fixed', inset:0, background:'rgba(13,27,46,0.55)', zIndex:2000, display:'flex', alignItems:'center', justifyContent:'center', padding:16 }}
      onClick={onClose}>
      <div style={{ background:'#fff', borderRadius:16, width:'min(1080px,96vw)', maxHeight:'94vh', display:'flex', flexDirection:'column', overflow:'hidden' }}
        onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div style={{ padding:'20px 28px 0', borderBottom:'1px solid rgba(13,27,46,0.08)', flexShrink:0 }}>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', marginBottom:14 }}>
            <div>
              <h2 style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:22, fontWeight:700, color:'#0D1B2E' }}>{deal.name}</h2>
              <div style={{ fontSize:12, color:'#8A9BB0', marginTop:3 }}>📍 {deal.market}</div>
            </div>
            <button onClick={onClose} style={{ background:'none', border:'none', cursor:'pointer', color:'#8A9BB0', fontSize:20, padding:4, lineHeight:1 }}>✕</button>
          </div>

          {/* Tabs */}
          <div style={{ display:'flex', gap:0 }}>
            {(['details','boe'] as Tab[]).map(t => (
              <button key={t} onClick={() => setTab(t)} style={{
                padding:'8px 20px', border:'none', background:'none', cursor:'pointer',
                fontFamily:"'DM Sans',sans-serif", fontSize:12, fontWeight:600,
                color: tab===t ? '#0D1B2E' : '#8A9BB0',
                borderBottom: tab===t ? '2px solid #C9A84C' : '2px solid transparent',
                textTransform:'uppercase', letterSpacing:'0.08em',
              }}>
                {t === 'details' ? 'Deal Details' : 'BOE Underwriting'}
                {t === 'boe' && boe && Object.keys(boe.t12 ?? {}).length > 0 && (
                  <span style={{ marginLeft:6, background:'#2E7D50', color:'#fff', borderRadius:8, padding:'1px 6px', fontSize:9 }}>T12</span>
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Body */}
        <div style={{ flex:1, overflowY:'auto' }}>
          {tab === 'details' && (
            <div style={{ padding:'24px 28px' }}>
              <div style={{ display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:16 }}>
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
                  <input style={inputStyle} type="number" value={form.year_built} onChange={e => setForm(p => ({...p, year_built:e.target.value}))} /></div>

                <div><label style={labelStyle}>Broker</label>
                  <input style={inputStyle} type="text" value={form.broker} onChange={e => setForm(p => ({...p, broker:e.target.value}))} /></div>

                <div><label style={labelStyle}>Bid Due Date</label>
                  <input style={inputStyle} type="date" value={form.bid_due_date} onChange={e => setForm(p => ({...p, bid_due_date:e.target.value}))} /></div>

                <div><label style={labelStyle}>Buyer</label>
                  <input style={inputStyle} type="text" placeholder="Acquiring entity…" value={form.buyer} onChange={e => setForm(p => ({...p, buyer:e.target.value}))} /></div>

                <div><label style={labelStyle}>Seller</label>
                  <input style={inputStyle} type="text" placeholder="Selling entity…" value={form.seller} onChange={e => setForm(p => ({...p, seller:e.target.value}))} /></div>

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

                {/* Comments — full width */}
                <div style={{ gridColumn:'span 3' }}>
                  <label style={labelStyle}>Comments</label>
                  <div style={{ padding:'12px 14px', border:'1px solid rgba(13,27,46,0.08)', borderRadius:8, fontSize:13, color:'#444', background:'rgba(13,27,46,.015)', lineHeight:1.7, whiteSpace:'pre-wrap', maxHeight:200, overflowY:'auto' }}>
                    {deal.comments || 'No comments on file.'}
                  </div>
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
            <BoePanel deal={deal} boe={boe} onSave={onSaveBoe} />
          )}
        </div>
      </div>
    </div>
  )
}
