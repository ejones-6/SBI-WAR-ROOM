'use client'
import { useState, useCallback, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import type { Deal, BoeData, CapRate } from '@/lib/types'
import DealsPage from './deals/DealsPage'
import DealModal from './deals/DealModal'
import DashboardPage from './dashboard/DashboardPage'
import PipelinePage from './pipeline/PipelinePage'
import CapRatesPage from './caprates/CapRatesPage'

type Page = 'dashboard' | 'deals' | 'pipeline' | 'analytics' | 'map' | 'team' | 'caprates' | 'upload'

interface Props {
  initialDeals: Deal[]
  initialBoeData: BoeData[]
  initialCapRates: CapRate[]
  userEmail: string
  loadAllDeals?: boolean
}

export default function WarRoom({ initialDeals, initialBoeData, initialCapRates, userEmail, loadAllDeals }: Props) {
  const supabase = createClient()
  const router = useRouter()
  const [page, setPage] = useState<Page>('dashboard')
  const [resolvedEmail, setResolvedEmail] = useState(userEmail)
  const [deals, setDeals] = useState<Deal[]>(initialDeals)
  const [boeMap, setBoeMap] = useState<Record<string, BoeData>>(
    Object.fromEntries(initialBoeData.map(b => [b.deal_name, b]))
  )
  const [capRateMap, setCapRateMap] = useState<Record<string, CapRate>>(
    Object.fromEntries(initialCapRates.map(c => [c.deal_name, c]))
  )
  const [selectedDeal, setSelectedDeal] = useState<Deal | null>(null)
  const [allDealsLoaded, setAllDealsLoaded] = useState(!loadAllDeals)
  const [loadingAll, setLoadingAll] = useState(false)

  // Real-time subscription to deals
  useEffect(() => {
    const channel = supabase
      .channel('deals-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'deals' }, payload => {
        if (payload.eventType === 'INSERT') {
          setDeals(prev => [payload.new as Deal, ...prev])
        } else if (payload.eventType === 'UPDATE') {
          setDeals(prev => prev.map(d => d.name === (payload.new as Deal).name ? payload.new as Deal : d))
        } else if (payload.eventType === 'DELETE') {
          setDeals(prev => prev.filter(d => d.id !== (payload.old as Deal).id))
        }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'boe_data' }, payload => {
        if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
          const b = payload.new as BoeData
          setBoeMap(prev => ({ ...prev, [b.deal_name]: b }))
        }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'cap_rates' }, payload => {
        if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
          const c = payload.new as CapRate
          setCapRateMap(prev => ({ ...prev, [c.deal_name]: c }))
        } else if (payload.eventType === 'DELETE') {
          const c = payload.old as CapRate
          setCapRateMap(prev => { const n = { ...prev }; delete n[c.deal_name]; return n })
        }
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [supabase])

  // Client-side data fetch — runs after auth confirmed
  useEffect(() => {
    if (!loadAllDeals) return
    async function loadData() {
      setLoadingAll(true)
      const sb = createClient()

      // Wait for auth to be ready — retry up to 5 times
      let session = null
      for (let i = 0; i < 5; i++) {
        const { data } = await sb.auth.getSession()
        if (data.session) { session = data.session; break }
        await new Promise(r => setTimeout(r, 500))
      }
      if (!session) { router.push('/login'); return }
      setResolvedEmail(session.user?.email ?? '')

      // Round 1: active deals fast
      const { data: active, error: e1 } = await sb.from('deals')
        .select('*')
        .not('status', 'like', '6 -%')
        .order('modified', { ascending: false })
        .limit(2500)
      if (active && active.length > 0) {
        setDeals(active)
        setLoadingAll(false)
      }

      // Round 2: full dataset + supporting tables in parallel
      const [dealsRes, boeRes, crRes] = await Promise.all([
        sb.from('deals').select('*').order('modified', { ascending: false }).limit(2500),
        sb.from('boe_data').select('*'),
        sb.from('cap_rates').select('*'),
      ])
      if (dealsRes.data && dealsRes.data.length > 0) {
        setDeals(dealsRes.data)
        setAllDealsLoaded(true)
      }
      if (boeRes.data) setBoeMap(Object.fromEntries(boeRes.data.map((b: any) => [b.deal_name, b])))
      if (crRes.data)  setCapRateMap(Object.fromEntries(crRes.data.map((c: any) => [c.deal_name, c])))
      setLoadingAll(false)
    }
    loadData()
  }, [loadAllDeals])

  const saveDeal = useCallback(async (updates: Partial<Deal> & { name: string; id?: string }) => {
    const res = await fetch('/api/deals', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updates),
    })
    const text = await res.text()
    if (!text) { console.error('saveDeal: empty response', res.status); return }
    const data = JSON.parse(text)
    if (!res.ok) { console.error('saveDeal error:', data); return }
    const updated: Deal = data
    setDeals(prev => prev.map(d => d.name === updated.name ? updated : d))
    if (selectedDeal?.name === updated.name) setSelectedDeal(updated)
    return updated
  }, [selectedDeal])

  const addDeal = useCallback(async (deal: Omit<Deal, 'id' | 'created_at' | 'updated_at'>) => {
    const res = await fetch('/api/deals', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(deal),
    })
    if (res.ok) {
      const created: Deal = await res.json()
      setDeals(prev => [created, ...prev])
      return created
    }
  }, [])

  const saveBoe = useCallback(async (boe: BoeData) => {
    const res = await fetch('/api/boe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(boe),
    })
    if (res.ok) {
      const saved: BoeData = await res.json()
      setBoeMap(prev => ({ ...prev, [saved.deal_name]: saved }))
      return saved
    }
  }, [])

  const saveCapRateFromBoe = useCallback(async (dealName: string, capAdj: number) => {
    const deal = deals.find(d => d.name === dealName)
    if (!deal?.purchase_price) return
    const pp = deal.purchase_price
    const res = await fetch('/api/cap-rates', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        deal_name: dealName,
        noi_cap_rate: capAdj / 100,
        broker_cap_rate: null,
        purchase_price: pp / 1000,
        sold_price: deal.sold_price ? deal.sold_price / 1000 : null,
        delta: deal.sold_price && pp > 0 ? (deal.sold_price - pp) / pp : null,
      }),
    })
    if (res.ok) {
      const cr = await res.json()
      setCapRateMap(prev => ({ ...prev, [cr.deal_name]: cr }))
    }
  }, [deals])

  const saveCapRate = useCallback(async (cr: CapRate) => {
    const res = await fetch('/api/cap-rates', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(cr),
    })
    if (res.ok) {
      const saved: CapRate = await res.json()
      setCapRateMap(prev => ({ ...prev, [saved.deal_name]: saved }))
      return saved
    }
  }, [])

  async function handleSignOut() {
    await supabase.auth.signOut()
    window.location.href = '/login'
  }

  // Status counts for badges
  const statusCounts = deals.reduce((acc: Record<string, number>, d) => {
    acc[d.status] = (acc[d.status] || 0) + 1
    return acc
  }, {})

  const NAV: { id: Page; label: string; icon: React.ReactNode; badgeKey?: string }[] = [
    { id: 'dashboard', label: 'Dashboard', icon: <GridIcon /> },
    { id: 'deals', label: 'Deals', icon: <ListIcon />, badgeKey: '1 - New' },
    { id: 'pipeline', label: 'Pipeline', icon: <PipeIcon />, badgeKey: '2 - Active' },
    { id: 'analytics', label: 'Analytics', icon: <ChartIcon /> },
    { id: 'upload', label: 'Upload Pipeline', icon: <UploadIcon /> },
  ]

  if (deals.length === 0) {
    return (
      <div style={{ display:'flex', alignItems:'center', justifyContent:'center', height:'100vh', background:'#0D1B2E', flexDirection:'column', gap:16 }}>
        <div style={{ fontFamily:"'Cormorant Garamond',serif", fontSize:28, fontWeight:700, color:'#C9A84C', letterSpacing:'0.08em' }}>STONEBRIDGE</div>
        <div style={{ fontSize:13, color:'rgba(255,255,255,0.4)', letterSpacing:'0.12em', textTransform:'uppercase' }}>Loading War Room…</div>
        <div style={{ width:200, height:3, background:'rgba(255,255,255,0.08)', borderRadius:2, marginTop:8, overflow:'hidden' }}>
          <div style={{ width:'40%', height:'100%', background:'#C9A84C', borderRadius:2 }}/>
        </div>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', height: '100vh', background: '#F5F4EF', fontFamily: "'DM Sans',sans-serif" }}>
      {/* Sidebar */}
      <aside style={{
        width: 220, background: '#0D1B2E', display: 'flex', flexDirection: 'column',
        flexShrink: 0, position: 'relative', zIndex: 10
      }}>
        {/* Logo */}
        <div style={{ padding: '24px 20px 20px', borderBottom: '1px solid rgba(255,255,255,0.07)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 32, height: 32, borderRadius: 8, background: 'rgba(201,168,76,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#C9A84C" strokeWidth="1.8">
                <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
                <polyline points="9 22 9 12 15 12 15 22"/>
              </svg>
            </div>
            <div>
              <div style={{ fontFamily: "'Cormorant Garamond',serif", color: '#F0B429', fontSize: 13, fontWeight: 700, letterSpacing: '0.1em' }}>STONEBRIDGE</div>
              <div style={{ color: 'rgba(255,255,255,0.4)', fontSize: 9, letterSpacing: '0.15em', textTransform: 'uppercase' }}>Acquisitions</div>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav style={{ flex: 1, padding: '12px 0' }}>
          {NAV.map(n => (
            <button key={n.id} onClick={() => setPage(n.id)} style={{
              width: '100%', display: 'flex', alignItems: 'center', gap: 10,
              padding: '10px 20px', border: 'none', background: page === n.id ? 'rgba(201,168,76,0.12)' : 'transparent',
              borderLeft: page === n.id ? '3px solid #C9A84C' : '3px solid transparent',
              color: page === n.id ? '#F0B429' : 'rgba(255,255,255,0.55)',
              fontSize: 13, fontWeight: page === n.id ? 600 : 400, cursor: 'pointer',
              fontFamily: "'DM Sans',sans-serif", textAlign: 'left', transition: 'all .15s'
            }}>
              <span style={{ opacity: page === n.id ? 1 : 0.6 }}>{n.icon}</span>
              <span style={{ flex: 1 }}>{n.label}</span>
              {n.badgeKey && (statusCounts[n.badgeKey] ?? 0) > 0 && (
                <span style={{ background: '#C9A84C', color: '#0D1B2E', borderRadius: 10, padding: '1px 7px', fontSize: 10, fontWeight: 700 }}>
                  {statusCounts[n.badgeKey]}
                </span>
              )}
            </button>
          ))}
        </nav>

        {/* User */}
        <div style={{ padding: '16px 20px', borderTop: '1px solid rgba(255,255,255,0.07)' }}>
          <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.35)', marginBottom: 4, letterSpacing: '0.05em' }}>Signed in as</div>
          <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.7)', marginBottom: 10, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{resolvedEmail}</div>
          <button onClick={handleSignOut} style={{
            width: '100%', padding: '7px', background: 'rgba(255,255,255,0.06)',
            border: '1px solid rgba(255,255,255,0.1)', borderRadius: 6,
            color: 'rgba(255,255,255,0.5)', fontSize: 11, cursor: 'pointer',
            fontFamily: "'DM Sans',sans-serif", letterSpacing: '0.05em'
          }}>Sign Out</button>
        </div>
      </aside>

      {/* Main content */}
      <main style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        {/* Top bar */}
        <div style={{
          height: 52, background: '#fff', borderBottom: '1px solid rgba(13,27,46,0.08)',
          display: 'flex', alignItems: 'center', padding: '0 28px', gap: 16, flexShrink: 0
        }}>
          <h1 style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 18, fontWeight: 700, color: '#0D1B2E', letterSpacing: '0.04em', flex: 1 }}>
            {{ dashboard: 'Deal Dashboard', deals: 'Deals', pipeline: 'Pipeline', analytics: 'Analytics', map: 'Market Map', team: 'Our Team', caprates: 'Cap Rate Tracker', upload: 'Upload Pipeline' }[page]}
          </h1>
          <div style={{ fontSize: 12, color: '#8A9BB0', display:'flex', alignItems:'center', gap:8 }}>
            {loadingAll && <span style={{ fontSize:10, color:'#C9A84C', fontWeight:600, letterSpacing:'0.05em' }}>● Loading all deals…</span>}
            {deals.length.toLocaleString()} deals{!allDealsLoaded ? ' (active)' : ''}
          </div>
        </div>

        {/* Page content */}
        <div style={{ flex: 1, overflow: 'auto' }}>
          {page === 'dashboard' && (
            <DashboardPage deals={deals} capRateMap={capRateMap} boeMap={boeMap} onOpenDeal={setSelectedDeal} />
          )}
          {page === 'deals' && (
            <DealsPage deals={deals} capRateMap={capRateMap} boeMap={boeMap} onOpenDeal={setSelectedDeal} onAddDeal={addDeal} />
          )}
          {page === 'pipeline' && (
            <PipelinePage deals={deals} onOpenDeal={setSelectedDeal} onSaveDeal={saveDeal} />
          )}
          {page === 'analytics' && (
            <div style={{ padding: 32, color: '#8A9BB0', textAlign: 'center', marginTop: 80 }}>Analytics — coming soon</div>
          )}
          {page === 'upload' && (
            <UploadPipelinePage onDealsImported={(newDeals) => setDeals(prev => {
              const existingNames = new Set(prev.map(d => d.name))
              const fresh = newDeals.filter(d => !existingNames.has(d.name))
              return [...fresh, ...prev]
            })} addDeal={addDeal} />
          )}
        </div>
      </main>

      {/* Deal Modal */}
      {selectedDeal && (
        <DealModal
          deal={selectedDeal}
          boe={boeMap[selectedDeal.name] ?? null}
          capRate={capRateMap[selectedDeal.name] ?? null}
          onClose={() => setSelectedDeal(null)}
          onSave={saveDeal}
          onSaveBoe={saveBoe}
          onSaveCapRate={saveCapRateFromBoe}
        />
      )}
    </div>
  )
}

// Icons
function GridIcon() { return <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg> }
function ListIcon() { return <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg> }
function PipeIcon() { return <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="4" height="18" rx="1"/><rect x="10" y="3" width="4" height="12" rx="1"/><rect x="17" y="3" width="4" height="8" rx="1"/></svg> }
function ChartIcon() { return <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg> }
function CapIcon() { return <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg> }
function UploadIcon() { return <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg> }

// Upload Pipeline Page
function UploadPipelinePage({ onDealsImported, addDeal }: { onDealsImported: (deals: any[]) => void, addDeal: (deal: any) => Promise<any> }) {
  const [status, setStatus] = useState<'idle' | 'parsing' | 'preview' | 'importing' | 'done'>('idle')
  const [preview, setPreview] = useState<any[]>([])
  const [imported, setImported] = useState(0)
  const [error, setError] = useState('')

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setStatus('parsing')
    setError('')
    try {
      const XLSX = await import('xlsx')
      const buf = await file.arrayBuffer()
      const wb = XLSX.read(buf)
      const ws = wb.Sheets['Deal Log'] ?? wb.Sheets[wb.SheetNames[0]]
      const rows: any[] = XLSX.utils.sheet_to_json(ws, { defval: '' })

      // Map columns to deal fields
      const deals = rows.map((r: any) => ({
        name: r['Deal Name'] || r['name'] || '',
        status: (r['Status'] || r['status'] || '1 - New').toString().trim(),
        market: r['Market'] || r['market'] || '',
        units: parseInt(r['Units'] || r['units']) || null,
        year_built: parseInt(r['Year Built'] || r['year_built']) || null,
        purchase_price: parseFloat(r['Purchase Price'] || r['purchase_price']) || null,
        price_per_unit: parseFloat(r['$ / Unit'] || r['price_per_unit']) || null,
        bid_due_date: r['Bid Due Date'] || r['bid_due_date'] || null,
        broker: r['Broker'] || r['broker'] || null,
        comments: r['Comments'] || r['comments'] || null,
        added: r['Added'] ? new Date(r['Added']).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
        modified: new Date().toISOString().split('T')[0],
      })).filter(d => d.name)

      setPreview(deals)
      setStatus('preview')
    } catch (err: any) {
      setError('Failed to parse file: ' + err.message)
      setStatus('idle')
    }
  }

  async function handleImport() {
    setStatus('importing')
    let count = 0
    for (const deal of preview) {
      try { await addDeal(deal); count++ } catch {}
    }
    onDealsImported(preview)
    setImported(count)
    setStatus('done')
  }

  const cardStyle = { background: '#fff', borderRadius: 12, padding: 32, border: '1px solid rgba(13,27,46,0.08)' }
  const labelStyle: React.CSSProperties = { fontSize: 10, fontWeight: 600, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', display: 'block', marginBottom: 6 }

  return (
    <div style={{ padding: 32, maxWidth: 800, margin: '0 auto' }}>
      <div style={{ marginBottom: 24 }}>
        <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 24, fontWeight: 700, color: '#0D1B2E' }}>Upload Pipeline from Rediq</div>
        <div style={{ fontSize: 13, color: '#8A9BB0', marginTop: 4 }}>Drop your latest Deal Log Excel file to import new deals into the War Room</div>
      </div>

      {status === 'idle' || status === 'parsing' ? (
        <div style={cardStyle}>
          <label style={{ display: 'block', border: '2px dashed rgba(13,27,46,0.15)', borderRadius: 10, padding: '48px 32px', textAlign: 'center', cursor: 'pointer', transition: 'border-color .2s' }}
            onMouseEnter={e => (e.currentTarget.style.borderColor = '#C9A84C')}
            onMouseLeave={e => (e.currentTarget.style.borderColor = 'rgba(13,27,46,0.15)')}>
            <input type="file" accept=".xlsx,.xls" onChange={handleFile} style={{ display: 'none' }} />
            <div style={{ fontSize: 32, marginBottom: 12 }}>📊</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#0D1B2E', marginBottom: 6 }}>
              {status === 'parsing' ? 'Parsing file…' : 'Drop your Rediq Deal Log here'}
            </div>
            <div style={{ fontSize: 12, color: '#8A9BB0' }}>Supports .xlsx and .xls files from Rediq</div>
          </label>
          {error && <div style={{ marginTop: 12, color: '#C0392B', fontSize: 13 }}>{error}</div>}
        </div>
      ) : status === 'preview' ? (
        <div style={cardStyle}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
            <div>
              <div style={{ fontSize: 15, fontWeight: 700, color: '#0D1B2E' }}>{preview.length} deals found</div>
              <div style={{ fontSize: 12, color: '#8A9BB0', marginTop: 2 }}>Review before importing</div>
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button onClick={() => setStatus('idle')} style={{ padding: '8px 18px', border: '1px solid rgba(13,27,46,0.15)', borderRadius: 7, background: '#fff', color: '#8A9BB0', fontSize: 13, cursor: 'pointer' }}>Cancel</button>
              <button onClick={handleImport} style={{ padding: '8px 18px', background: '#0D1B2E', color: '#F0B429', border: 'none', borderRadius: 7, fontSize: 13, fontWeight: 700, cursor: 'pointer' }}>
                Import {preview.length} Deals →
              </button>
            </div>
          </div>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead>
                <tr style={{ background: '#0D1B2E' }}>
                  {['Deal Name', 'Status', 'Market', 'Units', 'Year', 'Price', 'Broker'].map(h => (
                    <th key={h} style={{ padding: '8px 12px', textAlign: 'left', color: '#F0B429', fontSize: 10, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {preview.slice(0, 20).map((d, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid rgba(13,27,46,0.05)', background: i % 2 === 0 ? '#fff' : 'rgba(13,27,46,0.01)' }}>
                    <td style={{ padding: '7px 12px', fontWeight: 500, color: '#0D1B2E', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.name}</td>
                    <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.status}</td>
                    <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.market}</td>
                    <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.units ?? '—'}</td>
                    <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.year_built ?? '—'}</td>
                    <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.purchase_price ? `$${(d.purchase_price/1e6).toFixed(1)}M` : '—'}</td>
                    <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.broker || '—'}</td>
                  </tr>
                ))}
                {preview.length > 20 && (
                  <tr><td colSpan={7} style={{ padding: '8px 12px', color: '#8A9BB0', fontSize: 11, textAlign: 'center' }}>…and {preview.length - 20} more deals</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      ) : status === 'importing' ? (
        <div style={{ ...cardStyle, textAlign: 'center', padding: 64 }}>
          <div style={{ fontSize: 13, color: '#8A9BB0' }}>Importing deals into Supabase…</div>
        </div>
      ) : (
        <div style={{ ...cardStyle, textAlign: 'center', padding: 64 }}>
          <div style={{ fontSize: 32, marginBottom: 12 }}>✅</div>
          <div style={{ fontSize: 16, fontWeight: 700, color: '#0D1B2E', marginBottom: 6 }}>{imported} deals imported!</div>
          <div style={{ fontSize: 13, color: '#8A9BB0', marginBottom: 24 }}>Your pipeline is up to date</div>
          <button onClick={() => { setStatus('idle'); setPreview([]); setImported(0) }} style={{ padding: '9px 22px', background: '#0D1B2E', color: '#F0B429', border: 'none', borderRadius: 8, fontSize: 13, fontWeight: 700, cursor: 'pointer' }}>Upload Another</button>
        </div>
      )}
    </div>
  )
}
