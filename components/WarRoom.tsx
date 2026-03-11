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
  const [page, setPage] = useState<Page>('deals')
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
        .order('modified', { ascending: false })
        .range(0, 999)
      if (active && active.length > 0) {
        setDeals(active)
        setLoadingAll(false)
      }

      // Round 2: fetch ALL deals in pages of 1000
      let allDeals: any[] = []
      let page = 0
      while (true) {
        const { data: page_data } = await sb.from('deals')
          .select('*')
          .order('modified', { ascending: false })
          .range(page * 1000, (page + 1) * 1000 - 1)
        if (!page_data || page_data.length === 0) break
        allDeals = [...allDeals, ...page_data]
        if (page_data.length < 1000) break
        page++
      }

      const [boeRes, crRes] = await Promise.all([
        sb.from('boe_data').select('*'),
        sb.from('cap_rates').select('*'),
      ])
      if (allDeals.length > 0) {
        setDeals(allDeals)
        setAllDealsLoaded(true)
      }
      if (boeRes.data) setBoeMap(Object.fromEntries(boeRes.data.map((b: any) => [b.deal_name, b])))
      if (crRes.data)  setCapRateMap(Object.fromEntries(crRes.data.map((c: any) => [c.deal_name, c])))
      setLoadingAll(false)
    }
    loadData()
  }, [loadAllDeals])

  const refreshDeals = useCallback(async () => {
    const sb = createClient()
    // Fetch ALL deals paginated — no limit, so nothing gets missed after upload
    let allDeals: any[] = []
    let pg = 0
    while (true) {
      const { data } = await sb.from('deals').select('*').order('modified', { ascending: false }).range(pg * 1000, (pg + 1) * 1000 - 1)
      if (!data || data.length === 0) break
      allDeals = [...allDeals, ...data]
      if (data.length < 1000) break
      pg++
    }
    const [boeRes, crRes] = await Promise.all([
      sb.from('boe_data').select('*'),
      sb.from('cap_rates').select('*'),
    ])
    if (allDeals.length > 0) setDeals(allDeals)
    if (boeRes.data) setBoeMap(Object.fromEntries(boeRes.data.map((b: any) => [b.deal_name, b])))
    if (crRes.data)  setCapRateMap(Object.fromEntries(crRes.data.map((c: any) => [c.deal_name, c])))
  }, [])

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
      // Also refresh cap rates after BOE save to pick up any new value
      setTimeout(async () => {
        const crRes = await fetch('/api/cap-rates')
        if (crRes.ok) {
          const crData = await crRes.json()
          if (Array.isArray(crData)) setCapRateMap(Object.fromEntries(crData.map((c: any) => [c.deal_name, c])))
        }
      }, 800)
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
            <UploadPipelinePage onDealsImported={refreshDeals} addDeal={addDeal} onGoToDeals={() => setPage('deals')} />
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
function UploadPipelinePage({ onDealsImported, addDeal, onGoToDeals }: { onDealsImported: () => Promise<void>, addDeal: (deal: any) => Promise<any>, onGoToDeals: () => void }) {
  const [status, setStatus] = useState<'idle' | 'parsing' | 'preview' | 'importing' | 'done'>('idle')
  const [preview, setPreview] = useState<any[]>([])
  const [insertedCount, setInsertedCount] = useState(0)
  const [updatedCount, setUpdatedCount] = useState(0)
  const [skippedCount, setSkippedCount] = useState(0)
  const [importProgress, setImportProgress] = useState('')
  const [error, setError] = useState('')
  const [activeTab, setActiveTab] = useState<'new'|'active'|'passed'|'all'>('new')

  function reset() {
    setStatus('idle'); setPreview([]); setInsertedCount(0); setUpdatedCount(0); setSkippedCount(0)
    setImportProgress(''); setError(''); setActiveTab('new')
  }

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    // Reset input so same file can be re-uploaded
    e.target.value = ''
    setStatus('parsing')
    setError('')
    try {
      const XLSX = await import('xlsx')
      const buf = await file.arrayBuffer()
      const wb = XLSX.read(buf, { cellDates: true })
      const ws = wb.Sheets['Deal Log'] ?? wb.Sheets[wb.SheetNames[0]]
      const allRows: any[][] = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' })
      const headerRowIdx = allRows.findIndex(r => r.some((c: any) => String(c).trim() === 'Deal Name'))
      if (headerRowIdx < 0) throw new Error('Could not find "Deal Name" column — is this a Rediq Deal Log?')
      const headers: string[] = allRows[headerRowIdx].map((c: any) => String(c).trim())
      const dataRows = allRows.slice(headerRowIdx + 1)

      const col = (r: any[], name: string) => {
        const idx = headers.indexOf(name)
        return idx >= 0 ? r[idx] : ''
      }

      // Handles JS Date objects (SheetJS cellDates:true), Excel serials, and strings
      const parseDate = (v: any): string | null => {
        if (!v && v !== 0) return null
        if (v instanceof Date) return isNaN(v.getTime()) ? null : v.toISOString().split('T')[0]
        if (typeof v === 'number') {
          const d = new Date(Math.round((v - 25569) * 86400 * 1000))
          return isNaN(d.getTime()) ? null : d.toISOString().split('T')[0]
        }
        const s = String(v).trim()
        if (!s) return null
        const d = new Date(s)
        return isNaN(d.getTime()) ? null : d.toISOString().split('T')[0]
      }

      // Send ALL deals — API mirrors Rediq fields, preserves War Room fields
      const deals = dataRows
        .map((r: any[]) => ({
          name:           String(col(r, 'Deal Name') || '').trim(),
          status:         String(col(r, 'Status') || '1 - New').trim(),
          market:         String(col(r, 'Market') || '').trim(),
          units:          parseInt(String(col(r, 'Units'))) || null,
          year_built:     parseInt(String(col(r, 'Year Built'))) || null,
          purchase_price: parseFloat(String(col(r, 'Purchase Price') || '').replace(/[,$]/g, '')) || null,
          price_per_unit: parseFloat(String(col(r, '$ / Unit') || '').replace(/[,$]/g, '')) || null,
          bid_due_date:   parseDate(col(r, 'Bid Due Date')),
          broker:         String(col(r, 'Broker') || '').trim() || null,
          address:        String(col(r, 'Address') || '').trim() || null,
          added:          parseDate(col(r, 'Added')) ?? new Date().toISOString().split('T')[0],
          modified:       parseDate(col(r, 'Modified')) ?? new Date().toISOString().split('T')[0],
        }))
        .filter(d => d.name)
        .filter(d => {
          // Always include active pipeline
          if (['1 - New', '2 - Active', '5 - Dormant'].includes(d.status)) return true
          // Include recently changed Passed/Lost so status updates flow through (e.g. Active → Passed)
          if (['6 - Passed', '7 - Lost'].includes(d.status) && d.modified) {
            const cutoff = new Date()
            cutoff.setDate(cutoff.getDate() - 7)
            return new Date(d.modified) >= cutoff
          }
          return false
        })

      setPreview(deals)
      setActiveTab('new')
      setStatus('preview')
    } catch (err: any) {
      setError('Failed to parse file: ' + err.message)
      setStatus('idle')
    }
  }

  async function handleImport() {
    setStatus('importing')
    setImportProgress('Comparing ' + preview.length + ' deals against database…')
    try {
      const res = await fetch('/api/deals', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ _batch: true, deals: preview }),
      })
      if (res.ok) {
        const result = await res.json()
        setInsertedCount(result.inserted ?? 0)
        setUpdatedCount(result.updated ?? 0)
        setImportProgress('')
        await onDealsImported()
        setStatus('done')
      } else {
        const err = await res.json()
        setError('Import failed: ' + (err.error ?? res.status))
        setStatus('preview')
      }
    } catch (e: any) {
      setError('Import failed: ' + e.message)
      setStatus('preview')
    }
  }

  // Preview breakdown
  const newDeals     = preview.filter(d => d.status.startsWith('1 -'))
  const activeDeals  = preview.filter(d => d.status.startsWith('2 -'))
  const passedDeals  = preview.filter(d => d.status.startsWith('6 -') || d.status.startsWith('7 -'))
  const otherDeals   = preview.filter(d => !d.status.startsWith('1 -') && !d.status.startsWith('2 -') && !d.status.startsWith('6 -') && !d.status.startsWith('7 -'))

  const tabDeals = activeTab === 'new' ? newDeals : activeTab === 'active' ? activeDeals : activeTab === 'passed' ? passedDeals : preview

  const card: React.CSSProperties = { background: '#fff', borderRadius: 12, padding: 32, border: '1px solid rgba(13,27,46,0.08)' }

  const statusColor = (s: string) => {
    if (s.startsWith('1 -')) return { bg: 'rgba(46,125,80,0.1)', color: '#1E7A4A' }
    if (s.startsWith('2 -')) return { bg: 'rgba(201,168,76,0.15)', color: '#8A6500' }
    if (s.startsWith('6 -') || s.startsWith('7 -')) return { bg: 'rgba(192,57,43,0.08)', color: '#C0392B' }
    return { bg: 'rgba(13,27,46,0.06)', color: '#8A9BB0' }
  }

  return (
    <div style={{ padding: 32, maxWidth: 900, margin: '0 auto' }}>
      <div style={{ marginBottom: 24 }}>
        <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 24, fontWeight: 700, color: '#0D1B2E' }}>Upload Pipeline from Rediq</div>
        <div style={{ fontSize: 13, color: '#8A9BB0', marginTop: 4 }}>
          Mirrors your Rediq Deal Log exactly — status, bid dates, new deals. Preserves all BOE, comments, buyer/seller info.
        </div>
      </div>

      {/* ── Drop zone ── */}
      {(status === 'idle' || status === 'parsing') && (
        <div style={card}>
          <label style={{ display: 'block', border: '2px dashed rgba(13,27,46,0.15)', borderRadius: 10, padding: '48px 32px', textAlign: 'center', cursor: 'pointer', transition: 'border-color .2s' }}
            onMouseEnter={e => (e.currentTarget.style.borderColor = '#C9A84C')}
            onMouseLeave={e => (e.currentTarget.style.borderColor = 'rgba(13,27,46,0.15)')}>
            <input type="file" accept=".xlsx,.xls" onChange={handleFile} style={{ display: 'none' }} />
            <div style={{ fontSize: 32, marginBottom: 12 }}>{status === 'parsing' ? '⏳' : '📊'}</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#0D1B2E', marginBottom: 6 }}>
              {status === 'parsing' ? 'Reading file…' : 'Click to select your Rediq Deal Log'}
            </div>
            <div style={{ fontSize: 12, color: '#8A9BB0' }}>Supports .xlsx and .xls · All 2,000+ deals synced in one shot</div>
          </label>
          {error && <div style={{ marginTop: 16, padding: '10px 14px', background: 'rgba(192,57,43,0.07)', borderRadius: 8, color: '#C0392B', fontSize: 13 }}>{error}</div>}
        </div>
      )}

      {/* ── Preview ── */}
      {status === 'preview' && (
        <div style={card}>
          {/* Summary stats */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
            {[
              { label: 'New', count: newDeals.length, color: '#1E7A4A', bg: 'rgba(46,125,80,0.08)', tab: 'new' as const },
              { label: 'Active', count: activeDeals.length, color: '#8A6500', bg: 'rgba(201,168,76,0.12)', tab: 'active' as const },
              { label: 'Passed / Lost', count: passedDeals.length, color: '#C0392B', bg: 'rgba(192,57,43,0.06)', tab: 'passed' as const },
              { label: 'Total in file', count: preview.length, color: '#0D1B2E', bg: 'rgba(13,27,46,0.04)', tab: 'all' as const },
            ].map(s => (
              <button key={s.tab} onClick={() => setActiveTab(s.tab)} style={{
                padding: '14px 16px', borderRadius: 10, border: `2px solid ${activeTab === s.tab ? s.color : 'transparent'}`,
                background: s.bg, cursor: 'pointer', textAlign: 'left',
              }}>
                <div style={{ fontSize: 22, fontWeight: 700, color: s.color, fontVariantNumeric: 'tabular-nums' }}>{s.count}</div>
                <div style={{ fontSize: 11, color: s.color, fontWeight: 600, marginTop: 2, opacity: 0.8 }}>{s.label}</div>
              </button>
            ))}
          </div>

          {/* Tab label + actions */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <div style={{ fontSize: 12, color: '#8A9BB0' }}>
              Showing <strong style={{ color: '#0D1B2E' }}>{tabDeals.length}</strong> {activeTab === 'all' ? 'total' : activeTab} deals
              {otherDeals.length > 0 && activeTab !== 'all' && <span> · {otherDeals.length} dormant/owned/exited also included</span>}
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button onClick={reset} style={{ padding: '8px 18px', border: '1px solid rgba(13,27,46,0.15)', borderRadius: 7, background: '#fff', color: '#8A9BB0', fontSize: 13, cursor: 'pointer' }}>Cancel</button>
              <button onClick={handleImport} style={{ padding: '8px 22px', background: '#0D1B2E', color: '#F0B429', border: 'none', borderRadius: 7, fontSize: 13, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.04em' }}>
                Sync {preview.length} Deals to War Room →
              </button>
            </div>
          </div>

          {error && <div style={{ marginBottom: 12, padding: '10px 14px', background: 'rgba(192,57,43,0.07)', borderRadius: 8, color: '#C0392B', fontSize: 13 }}>{error}</div>}

          {/* Deals table */}
          <div style={{ overflowX: 'auto', maxHeight: 420, overflowY: 'auto', borderRadius: 8, border: '1px solid rgba(13,27,46,0.07)' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
              <thead style={{ position: 'sticky', top: 0, zIndex: 1 }}>
                <tr style={{ background: '#0D1B2E' }}>
                  {['Deal Name', 'Status', 'Market', 'Units', 'Bid Date', 'Price', 'Broker'].map(h => (
                    <th key={h} style={{ padding: '9px 12px', textAlign: 'left', color: '#F0B429', fontSize: 10, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {tabDeals.map((d, i) => {
                  const sc = statusColor(d.status)
                  return (
                    <tr key={i} style={{ borderBottom: '1px solid rgba(13,27,46,0.05)', background: i % 2 === 0 ? '#fff' : 'rgba(13,27,46,0.01)' }}>
                      <td style={{ padding: '7px 12px', fontWeight: 500, color: '#0D1B2E', maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.name}</td>
                      <td style={{ padding: '7px 12px' }}>
                        <span style={{ background: sc.bg, color: sc.color, borderRadius: 10, padding: '2px 8px', fontSize: 11, fontWeight: 600, whiteSpace: 'nowrap' }}>{d.status}</span>
                      </td>
                      <td style={{ padding: '7px 12px', color: '#8A9BB0', maxWidth: 160, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.market || '—'}</td>
                      <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.units?.toLocaleString() ?? '—'}</td>
                      <td style={{ padding: '7px 12px', color: d.bid_due_date ? '#0D1B2E' : '#8A9BB0', fontWeight: d.bid_due_date ? 500 : 400 }}>{d.bid_due_date ?? '—'}</td>
                      <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.purchase_price ? `$${(d.purchase_price/1e6).toFixed(1)}M` : '—'}</td>
                      <td style={{ padding: '7px 12px', color: '#8A9BB0' }}>{d.broker || '—'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── Importing ── */}
      {status === 'importing' && (
        <div style={{ ...card, textAlign: 'center', padding: 64 }}>
          <div style={{ fontSize: 28, marginBottom: 16 }}>⏳</div>
          <div style={{ fontSize: 14, fontWeight: 600, color: '#0D1B2E', marginBottom: 8 }}>Syncing with Supabase…</div>
          <div style={{ fontSize: 13, color: '#8A9BB0' }}>{importProgress}</div>
          <div style={{ width: 200, height: 3, background: 'rgba(13,27,46,0.08)', borderRadius: 2, margin: '20px auto 0', overflow: 'hidden' }}>
            <div style={{ width: '60%', height: '100%', background: '#C9A84C', borderRadius: 2, animation: 'pulse 1.2s ease-in-out infinite' }} />
          </div>
        </div>
      )}

      {/* ── Done ── */}
      {status === 'done' && (
        <div style={{ ...card, padding: 40 }}>
          <div style={{ textAlign: 'center', marginBottom: 32 }}>
            <div style={{ fontSize: 36, marginBottom: 12 }}>✅</div>
            <div style={{ fontSize: 18, fontWeight: 700, color: '#0D1B2E', marginBottom: 8 }}>War Room synced with Rediq</div>
            <div style={{ display: 'flex', justifyContent: 'center', gap: 24, marginTop: 16 }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 28, fontWeight: 700, color: '#1E7A4A' }}>{insertedCount}</div>
                <div style={{ fontSize: 11, color: '#8A9BB0', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>New deals added</div>
              </div>
              <div style={{ width: 1, background: 'rgba(13,27,46,0.1)' }} />
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 28, fontWeight: 700, color: '#C9A84C' }}>{updatedCount}</div>
                <div style={{ fontSize: 11, color: '#8A9BB0', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Deals updated</div>
              </div>
              <div style={{ width: 1, background: 'rgba(13,27,46,0.1)' }} />
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 28, fontWeight: 700, color: '#8A9BB0' }}>{skippedCount}</div>
                <div style={{ fontSize: 11, color: '#8A9BB0', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Unchanged</div>
              </div>
            </div>
          </div>
          <div style={{ background: 'rgba(13,27,46,0.02)', border: '1px solid rgba(13,27,46,0.07)', borderRadius: 10, padding: '14px 20px', fontSize: 12, color: '#8A9BB0', marginBottom: 24 }}>
            ✓ &nbsp;BOE underwriting data preserved &nbsp;·&nbsp; ✓ Comments preserved &nbsp;·&nbsp; ✓ Buyer / Seller / Sold Price preserved
          </div>
          <div style={{ textAlign: 'center', display: 'flex', gap: 12, justifyContent: 'center' }}>
            <button onClick={reset} style={{ padding: '10px 24px', background: '#fff', color: '#0D1B2E', border: '1px solid rgba(13,27,46,0.15)', borderRadius: 8, fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>Upload Another</button>
            <button onClick={onGoToDeals} style={{ padding: '10px 28px', background: '#0D1B2E', color: '#F0B429', border: 'none', borderRadius: 8, fontSize: 13, fontWeight: 700, cursor: 'pointer' }}>View Deals →</button>
          </div>
        </div>
      )}
    </div>
  )
}
