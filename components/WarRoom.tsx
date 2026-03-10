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

type Page = 'dashboard' | 'deals' | 'pipeline' | 'analytics' | 'map' | 'team' | 'caprates'

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

  const saveDeal = useCallback(async (updates: Partial<Deal> & { name: string }) => {
    const res = await fetch('/api/deals', {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updates),
    })
    if (res.ok) {
      const updated: Deal = await res.json()
      setDeals(prev => prev.map(d => d.name === updated.name ? updated : d))
      if (selectedDeal?.name === updated.name) setSelectedDeal(updated)
      return updated
    }
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
            {{ dashboard: 'Deal Dashboard', deals: 'Deals', pipeline: 'Pipeline', analytics: 'Analytics', map: 'Market Map', team: 'Our Team', caprates: 'Cap Rate Tracker' }[page]}
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
