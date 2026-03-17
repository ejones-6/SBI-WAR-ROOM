'use client'
import { useState, useMemo } from 'react'
import * as XLSX from 'xlsx'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import { fmtShort, fmtUnit, fmtPct, formatBidDate, bidDateClass, statusClass, statusLabel, getRegion, REGION_LABELS, REGION_MAP, sortDeals, ALL_STATUSES } from '@/lib/utils'
import type { Region } from '@/lib/types'

const PER_PAGE = 25

interface Props {
  deals: Deal[]
  capRateMap: Record<string, CapRate>
  boeMap: Record<string, BoeData>
  onOpenDeal: (d: Deal) => void
  onAddDeal: (d: any) => Promise<any>
}

export default function DealsPage({ deals, capRateMap, boeMap, onOpenDeal, onAddDeal }: Props) {
  const [filter, setFilter] = useState('all')
  const [region, setRegion] = useState('all')
  const [sort, setSort] = useState('modified-desc')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [showAdd, setShowAdd] = useState(false)
  const [newDeal, setNewDeal] = useState({ name: '', street: '', city: '', state: '', zip: '', market: '', units: '', yearBuilt: '', purchasePrice: '', status: '1 - New', broker: '' })
  const [newDealRegion, setNewDealRegion] = useState<Region | ''>('')

  function handleExport() {
    const rows = filtered.map(d => ({
      'Deal Name': d.name,
      'Status': d.status,
      'Market': d.market ?? '',
      'Region': REGION_LABELS[getRegion(d.market)] ?? '',
      'Units': d.units ?? '',
      'Year Built': d.year_built ?? '',
      'Guidance ($)': d.purchase_price ?? '',
      '$/Unit': d.price_per_unit ?? '',
      'Cap Rate': capRateMap[d.name]?.noi_cap_rate ?? capRateMap[d.name]?.broker_cap_rate ?? '',
      'Bid Due Date': d.bid_due_date ?? '',
      'Broker': d.broker ?? '',
      'Seller': d.seller ?? '',
      'Buyer': d.buyer ?? '',
      'Sold Price ($)': d.sold_price ?? '',
      'Address': d.address ?? '',
      'Comments': d.comments ?? '',
      'Added': d.added ?? '',
      'Modified': d.modified ?? '',
    }))
    const ws = XLSX.utils.json_to_sheet(rows)
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, 'Deals')
    const statusLabel = filter === 'all' ? 'All' : filter.replace(/^\d+ - /, '')
    const regionLabel = region === 'all' ? 'All Regions' : (REGION_LABELS as any)[region] ?? region
    const filename = `SBI War Room - ${statusLabel} - ${regionLabel}.xlsx`
    XLSX.writeFile(wb, filename)
  }

  const filtered = useMemo(() => {
    let d = deals
    if (filter !== 'all') d = d.filter(x => x.status.includes(filter.split(' - ')[0] + ' -'))
    if (region !== 'all') d = d.filter(x => getRegion(x.market) === region)
    if (search) {
      const q = search.toLowerCase()
      d = d.filter(x => x.name.toLowerCase().includes(q) || x.market?.toLowerCase().includes(q) || x.broker?.toLowerCase().includes(q))
    }
    return sortDeals(d, sort)
  }, [deals, filter, region, sort, search])

  const paginated = filtered.slice((page - 1) * PER_PAGE, page * PER_PAGE)
  const totalPages = Math.ceil(filtered.length / PER_PAGE)

  function crCell(deal: Deal) {
    const cr = capRateMap[deal.name]
    const boe = boeMap[deal.name]
    const badge = (boe as any)?.noi_badge ?? 'BOE'

    if (cr?.noi_cap_rate) {
      const pct = Number(cr.noi_cap_rate)
      return (
        <span style={{fontSize:12,fontWeight:600,color:'#0D1B2E'}}>
          {fmtPct(pct)}
          <sup style={{fontSize:7,opacity:.5,marginLeft:1}}>{badge}</sup>
        </span>
      )
    }
    if (cr?.broker_cap_rate) {
      const pct = Number(cr.broker_cap_rate)
      return <span style={{fontSize:12,fontWeight:600,color:'#0D1B2E'}}>{fmtPct(pct)}</span>
    }
    return <span className="cr-none">—</span>
  }

  async function submitAdd() {
    if (!newDeal.name || !newDeal.market) return
    const addressParts = [newDeal.street, newDeal.city, newDeal.state, newDeal.zip].filter(Boolean)
    const address = addressParts.length > 0 ? addressParts.join(', ') : null
    await onAddDeal({
      name: newDeal.name, market: newDeal.market,
      address,
      units: newDeal.units ? parseInt(newDeal.units) : null,
      year_built: newDeal.yearBuilt ? parseInt(newDeal.yearBuilt) : null,
      purchase_price: newDeal.purchasePrice ? parseFloat(newDeal.purchasePrice) : null,
      price_per_unit: (newDeal.purchasePrice && newDeal.units) ? Math.round(parseFloat(newDeal.purchasePrice) / parseInt(newDeal.units)) : null,
      status: newDeal.status, broker: newDeal.broker || null,
      added: new Date().toISOString().slice(0,10), modified: new Date().toISOString().slice(0,10),
      flagged: false, hot: false,
    })
    setShowAdd(false)
    setNewDeal({ name:'',street:'',city:'',state:'',zip:'',market:'',units:'',yearBuilt:'',purchasePrice:'',status:'1 - New',broker:'' }); setNewDealRegion('')
  }

  const FILTER_CHIPS = [
    { label: 'All', value: 'all' },
    { label: 'New', value: '1 - New' },
    { label: 'Active', value: '2 - Active' },
    { label: 'Dormant', value: '5 - Dormant' },
    { label: 'Passed', value: '6 - Passed' },
    { label: 'Lost', value: '7 - Lost' },
    { label: 'Owned', value: '10 - Owned Property' },
    { label: 'Comp', value: '11 - Property Comp' },
  ]
  const REGIONS = ['all','DC','Carolinas','GA','TX','TN','FL','Misc']
  const REGION_DISPLAY: Record<string, string> = {
    DC: 'Mid-Atlantic', Carolinas: 'Carolinas', GA: 'Georgia',
    TX: 'Texas', TN: 'Tennessee', FL: 'Florida', Misc: 'Misc',
  }

  return (
    <div style={{ padding: '24px 28px' }}>
      {/* Controls */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
        <input
          value={search} onChange={e => { setSearch(e.target.value); setPage(1) }}
          placeholder="Search deals, markets, brokers…"
          style={{ flex: '1 1 260px', padding: '8px 14px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 8, fontSize: 13, fontFamily: "'DM Sans',sans-serif", outline: 'none' }}
        />
        <select value={sort} onChange={e => setSort(e.target.value)} style={{ padding: '8px 12px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 8, fontSize: 13, fontFamily: "'DM Sans',sans-serif", background:'#fff' }}>
          <option value="modified-desc">Recently Modified</option>
          <option value="biddate-asc">Bid Date (Soonest)</option>
          <option value="price-desc">Price (High–Low)</option>
          <option value="price-asc">Price (Low–High)</option>
          <option value="units-desc">Units (Most)</option>
          <option value="name-asc">Name A–Z</option>
          <option value="location-asc">Location A–Z</option>
        </select>
        <button onClick={() => setShowAdd(true)} style={{ padding: '8px 18px', background: '#0D1B2E', color: '#F0B429', border: 'none', borderRadius: 8, fontSize: 12, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.08em', fontFamily: "'DM Sans',sans-serif" }}>
          + Add Deal
        </button>
        <button onClick={handleExport} title={`Export ${filtered.length} deals to Excel`} style={{ padding: '8px 16px', background: '#fff', color: '#0D1B2E', border: '1px solid rgba(13,27,46,0.15)', borderRadius: 8, fontSize: 12, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.05em', fontFamily: "'DM Sans',sans-serif", display:'flex', alignItems:'center', gap:6 }}>
          ↓ Export ({filtered.length})
        </button>
      </div>

      {/* Status chips */}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8 }}>
        {FILTER_CHIPS.map(c => (
          <button key={c.value} onClick={() => { setFilter(c.value); setPage(1) }} style={{
            padding: '4px 12px', borderRadius: 20, border: '1px solid',
            borderColor: filter === c.value ? '#0D1B2E' : 'rgba(13,27,46,0.15)',
            background: filter === c.value ? '#0D1B2E' : '#fff',
            color: filter === c.value ? '#F0B429' : '#8A9BB0',
            fontSize: 11, fontWeight: 600, cursor: 'pointer', fontFamily: "'DM Sans',sans-serif"
          }}>{c.label}</button>
        ))}
      </div>

      {/* Region chips */}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
        {REGIONS.map(r => (
          <button key={r} onClick={() => { setRegion(r); setPage(1) }} style={{
            padding: '3px 10px', borderRadius: 16, border: '1px solid',
            borderColor: region === r ? '#C9A84C' : 'rgba(13,27,46,0.1)',
            background: region === r ? 'rgba(201,168,76,0.12)' : 'transparent',
            color: region === r ? '#8A6500' : '#8A9BB0',
            fontSize: 10, fontWeight: 600, cursor: 'pointer', fontFamily: "'DM Sans',sans-serif"
          }}>{r === 'all' ? 'All Regions' : REGION_DISPLAY[r] || r}</button>
        ))}
      </div>


      {/* Table */}
      <div style={{ background: '#fff', border: '1px solid rgba(13,27,46,0.08)', borderRadius: 10, overflow: 'hidden' }}>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#0D1B2E' }}>
                {['Deal Name','Status','Units','Year','Guidance','$/Unit','Cap Rate','Bid Date','Seller','Buyer','Sold Price','+/− Guidance'].map((h, i) => (
                  <th key={h} style={{ padding: '11px 14px', textAlign: i === 0 ? 'left' : 'center', fontSize: 10, fontWeight: 600, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#F0B429', whiteSpace: 'nowrap' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {paginated.map(deal => {
                const sc = statusClass(deal.status)
                const sl = statusLabel(deal.status)
                const reg = getRegion(deal.market)
                const guidanceDiff = deal.sold_price && deal.purchase_price ? deal.sold_price - deal.purchase_price : null
                return (
                  <tr key={deal.id} onClick={() => onOpenDeal(deal)} style={{ cursor: 'pointer', borderBottom: '1px solid rgba(13,27,46,0.05)' }}
                    onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.04)')}
                    onMouseLeave={e => (e.currentTarget.style.background = '')}>
                    <td style={{ padding: '10px 14px', fontWeight: 500, color: '#0D1B2E', maxWidth: 220 }}>
                      {deal.name}
                      <small style={{ display: 'block', fontSize: 11, color: '#8A9BB0', fontWeight: 400, marginTop: 1 }}>
                        {deal.market}
                        {reg !== 'Misc' && <span style={{ marginLeft: 4, background: 'rgba(13,27,46,0.06)', color: '#8A9BB0', fontSize: 9, fontWeight: 600, padding: '1px 5px', borderRadius: 3 }}>{REGION_LABELS[reg]}</span>}
                        {deal.broker && (deal.status.includes('1 -') || deal.status.includes('2 -') || deal.status.includes('3 -')) && (
                          <span style={{ marginLeft: 4, background: 'rgba(240,151,10,0.12)', color: '#b87200', fontSize: 9, fontWeight: 700, padding: '1px 6px', borderRadius: 4 }}>{deal.broker}</span>
                        )}
                      </small>
                    </td>
                    <td style={{ padding: '10px 14px' }}>
                      <span className={`status-badge ${sc}`} style={{ display:'inline-flex',alignItems:'center',gap:4,padding:'3px 8px',borderRadius:12,fontSize:11,fontWeight:600,whiteSpace:'nowrap',
                        ...(sc === 's-bid' ? { background:'rgba(124,58,237,0.1)', color:'#6d28d9' } : {}) }}>
                        <span style={{ width:6,height:6,borderRadius:'50%',background:'currentColor',opacity:.7 }}/>
                        {sl}
                      </span>
                    </td>
                    <td style={{ padding: '10px 14px', fontSize: 13, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{deal.units?.toLocaleString() ?? '—'}</td>
                    <td style={{ padding: '10px 14px', fontSize: 13, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{deal.year_built ?? '—'}</td>
                    <td style={{ padding: '10px 14px', fontSize: 13, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{fmtShort(deal.purchase_price)}</td>
                    <td style={{ padding: '10px 14px', fontSize: 13, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{fmtUnit(deal.price_per_unit)}</td>
                    <td style={{ padding: '10px 14px', textAlign: 'center' }}>{crCell(deal)}</td>
                    <td style={{ padding: '10px 14px', fontSize: 12, whiteSpace: 'nowrap', textAlign: 'center' }} className={bidDateClass(deal.bid_due_date)}>{formatBidDate(deal.bid_due_date)}</td>
                    <td style={{ padding: '10px 14px', fontSize: 12, color: '#8A9BB0', textAlign: 'center' }}>{deal.seller || '—'}</td>
                    <td style={{ padding: '10px 14px', fontSize: 12, color: '#8A9BB0', textAlign: 'center' }}>{deal.buyer || '—'}</td>
                    <td style={{ padding: '10px 14px', fontSize: 12, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{deal.sold_price ? fmtShort(deal.sold_price) : '—'}</td>
                    <td style={{ padding: '10px 14px', fontSize: 12, whiteSpace: 'nowrap', textAlign: 'center' }}>
                      {guidanceDiff !== null ? (
                        <span className={guidanceDiff > 0 ? 'guidance-pos' : guidanceDiff < 0 ? 'guidance-neg' : 'guidance-zero'}>
                          {guidanceDiff >= 0 ? '+' : ''}{fmtShort(guidanceDiff)}
                          <small style={{ display: 'block', fontSize: 9, fontWeight: 400 }}>
                            {guidanceDiff >= 0 ? '+' : ''}{((guidanceDiff / deal.purchase_price!) * 100).toFixed(1)}%
                          </small>
                        </span>
                      ) : '—'}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16 }}>
        <span style={{ fontSize: 12, color: '#8A9BB0' }}>Showing {((page-1)*PER_PAGE)+1}–{Math.min(page*PER_PAGE, filtered.length)} of {filtered.length} deals</span>
        <div style={{ display: 'flex', gap: 4 }}>
          {[...Array(Math.min(totalPages, 7))].map((_, i) => (
            <button key={i+1} onClick={() => setPage(i+1)} style={{ padding: '5px 10px', borderRadius: 6, border: '1px solid', borderColor: page===i+1 ? '#0D1B2E' : 'rgba(13,27,46,0.15)', background: page===i+1 ? '#0D1B2E' : '#fff', color: page===i+1 ? '#F0B429' : '#8A9BB0', fontSize: 12, cursor: 'pointer', fontFamily: "'DM Sans',sans-serif" }}>{i+1}</button>
          ))}
          {totalPages > 7 && <>
            <span style={{ padding: '5px 4px', color: '#8A9BB0' }}>…</span>
            <button onClick={() => setPage(totalPages)} style={{ padding: '5px 10px', borderRadius: 6, border: '1px solid rgba(13,27,46,0.15)', background: '#fff', color: '#8A9BB0', fontSize: 12, cursor: 'pointer' }}>{totalPages}</button>
          </>}
        </div>
      </div>

      {/* Add Deal Modal */}
      {showAdd && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(13,27,46,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }} onClick={() => setShowAdd(false)}>
          <div style={{ background: '#fff', borderRadius: 14, padding: 32, width: 480, maxWidth: '94vw' }} onClick={e => e.stopPropagation()}>
            <h3 style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 20, fontWeight: 700, color: '#0D1B2E', marginBottom: 24 }}>Add New Deal</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              {/* Deal Name */}
              <div style={{ gridColumn: 'span 2' }}>
                <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>Deal Name</label>
                <input type="text" value={newDeal.name} onChange={e => setNewDeal(p => ({ ...p, name: e.target.value }))}
                  style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
              {/* Address */}
              <div style={{ gridColumn: 'span 2' }}>
                <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>Street Address</label>
                <input type="text" value={newDeal.street} onChange={e => setNewDeal(p => ({ ...p, street: e.target.value }))}
                  placeholder="123 Main St"
                  style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
              <div>
                <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>City</label>
                <input type="text" value={newDeal.city} onChange={e => setNewDeal(p => ({ ...p, city: e.target.value }))}
                  placeholder="Tampa"
                  style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
              <div>
                <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>State</label>
                <select value={newDeal.state} onChange={e => setNewDeal(p => ({ ...p, state: e.target.value }))}
                  style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif", background:'#fff', color: newDeal.state ? '#0D1B2E' : '#8A9BB0' }}>
                  <option value="">State…</option>
                  {['AL','AR','AZ','CO','DC','FL','GA','MD','NC','NV','SC','TN','TX','VA'].map(s => <option key={s} value={s}>{s}</option>)}
                </select>
              </div>
              <div>
                <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>Zip Code</label>
                <input type="text" value={newDeal.zip} onChange={e => setNewDeal(p => ({ ...p, zip: e.target.value }))}
                  placeholder="33601"
                  style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif" }} />
              </div>
              {/* Region → Market two-level dropdown */}
              <div style={{ gridColumn: 'span 2', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
                <div>
                  <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>Region</label>
                  <select
                    value={newDealRegion}
                    onChange={e => { setNewDealRegion(e.target.value as Region | 'Misc'); setNewDeal(p => ({ ...p, market: '' })) }}
                    style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif", background:'#fff', color: newDealRegion ? '#0D1B2E' : '#8A9BB0' }}>
                    <option value="">Select region…</option>
                    {(Object.keys(REGION_MAP) as Region[]).filter(r => r !== 'Misc').map(r => (
                      <option key={r} value={r}>{REGION_LABELS[r]}</option>
                    ))}
                    <option value="Misc">Miscellaneous</option>
                  </select>
                </div>
                <div>
                  <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>Market</label>
                  {newDealRegion === 'Misc' ? (
                    <input
                      type="text"
                      value={newDeal.market}
                      onChange={e => setNewDeal(p => ({ ...p, market: e.target.value }))}
                      placeholder="Type market name…"
                      style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif" }} />
                  ) : (
                    <select
                      value={newDeal.market}
                      onChange={e => setNewDeal(p => ({ ...p, market: e.target.value }))}
                      disabled={!newDealRegion}
                      style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif", background: newDealRegion ? '#fff' : '#f5f5f5', color: newDeal.market ? '#0D1B2E' : '#8A9BB0' }}>
                      <option value="">{newDealRegion ? 'Select market…' : '— pick region first —'}</option>
                      {newDealRegion === 'DC' && (<>
                        <option value="Washington, DC">Washington, DC</option>
                        <option value="Suburban Maryland">Suburban Maryland</option>
                        <option value="Northern Virginia">Northern Virginia</option>
                        <option value="Richmond, VA">Richmond, VA</option>
                        <option value="Charlottesville, VA">Charlottesville, VA</option>
                        <option value="Virginia Beach, VA">Virginia Beach, VA</option>
                        <option value="Misc - Mid-Atlantic">Misc</option>
                      </>)}
                      {newDealRegion === 'Carolinas' && (<>
                        <option value="Charlotte, NC">Charlotte, NC</option>
                        <option value="Raleigh/Durham, NC">Raleigh/Durham, NC</option>
                        <option value="Greensboro/Winston-Salem, NC">Greensboro/Winston-Salem, NC</option>
                        <option value="Wilmington, NC">Wilmington, NC</option>
                        <option value="Charleston, SC">Charleston, SC</option>
                        <option value="Greenville, SC">Greenville, SC</option>
                        <option value="Misc - Carolinas">Misc</option>
                      </>)}
                      {newDealRegion === 'GA' && (<>
                        <option value="Atlanta, GA">Atlanta, GA</option>
                        <option value="Savannah, GA">Savannah, GA</option>
                        <option value="Misc - Georgia">Misc</option>
                      </>)}
                      {newDealRegion === 'TX' && (<>
                        <option value="Dallas, TX">Dallas, TX</option>
                        <option value="Houston, TX">Houston, TX</option>
                        <option value="Austin, TX">Austin, TX</option>
                        <option value="San Antonio, TX">San Antonio, TX</option>
                        <option value="Misc - Texas">Misc</option>
                      </>)}
                      {newDealRegion === 'TN' && (<>
                        <option value="Nashville, TN">Nashville, TN</option>
                        <option value="Misc - Tennessee">Misc</option>
                      </>)}
                      {newDealRegion === 'FL' && (<>
                        <option value="Jacksonville, FL">Jacksonville, FL</option>
                        <option value="Orlando, FL">Orlando, FL</option>
                        <option value="Tampa, FL">Tampa, FL</option>
                        <option value="South Florida">South Florida</option>
                        <option value="Naples/Fort Myers, FL">Naples/Fort Myers, FL</option>
                        <option value="Misc - Florida">Misc</option>
                      </>)}
                    </select>
                  )}
                </div>
              </div>
              {/* Rest of fields */}
              {[
                { label:'Units', key:'units', type:'number' },
                { label:'Year Built', key:'yearBuilt', type:'number' },
                { label:'Purchase Price ($)', key:'purchasePrice', type:'number' },
                { label:'Broker', key:'broker' },
              ].map(f => (
                <div key={f.key}>
                  <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>{f.label}</label>
                  <input type={f.type || 'text'} value={(newDeal as any)[f.key]} onChange={e => setNewDeal(p => ({ ...p, [f.key]: e.target.value }))}
                    style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif" }} />
                </div>
              ))}
              <div>
                <label style={{ display:'block', fontSize:10, fontWeight:600, color:'#8A9BB0', letterSpacing:'0.1em', textTransform:'uppercase', marginBottom:5 }}>Status</label>
                <select value={newDeal.status} onChange={e => setNewDeal(p => ({ ...p, status: e.target.value }))}
                  style={{ width:'100%', padding:'8px 10px', border:'1px solid rgba(13,27,46,0.12)', borderRadius:7, fontSize:13, fontFamily:"'DM Sans',sans-serif", background:'#fff' }}>
                  {ALL_STATUSES.map(s => <option key={s} value={s}>{s}</option>)}
                </select>
              </div>
            </div>
            <div style={{ display:'flex', justifyContent:'flex-end', gap:10, marginTop:24 }}>
              <button onClick={() => setShowAdd(false)} style={{ padding:'8px 20px', border:'1px solid rgba(13,27,46,0.15)', borderRadius:8, background:'#fff', color:'#8A9BB0', fontSize:13, cursor:'pointer', fontFamily:"'DM Sans',sans-serif" }}>Cancel</button>
              <button onClick={submitAdd} style={{ padding:'8px 20px', background:'#0D1B2E', color:'#F0B429', border:'none', borderRadius:8, fontSize:13, fontWeight:700, cursor:'pointer', fontFamily:"'DM Sans',sans-serif" }}>Save Deal</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
