'use client'
import { useState, useMemo, useEffect } from 'react'

interface Broker {
  id: string
  name: string
  title: string | null
  firm: string
  region: string
  email: string | null
  phone: string | null
  cell: string | null
  notes: string | null
}

const REGIONS = ['All', 'DC / Mid-Atlantic', 'Georgia', 'Florida', 'Carolinas', 'Texas', 'Tennessee', 'Philadelphia', 'Arizona']
const FIRMS = ['All', 'CBRE', 'JLL', 'Newmark', 'Berkadia', 'Walker & Dunlop', 'Cushman & Wakefield', 'Eastdil Secured', 'IPA', 'Northmarq', 'Colliers', 'Transwestern', 'Greysteel', 'Other']

const NAVY = '#0D1B2E'
const GOLD = '#C9A84C'
const inp = { width: '100%', padding: '8px 10px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 7, fontSize: 13, fontFamily: "'DM Sans',sans-serif", color: NAVY, outline: 'none', boxSizing: 'border-box' as const }
const lbl = { display: 'block', fontSize: 10, fontWeight: 600, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase' as const, marginBottom: 5 }

const EMPTY: Omit<Broker, 'id'> = { name: '', title: '', firm: 'CBRE', region: 'DC / Mid-Atlantic', email: '', phone: '', cell: '', notes: '' }

export default function BrokersPage() {
  const [brokers, setBrokers] = useState<Broker[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [region, setRegion] = useState('All')
  const [firm, setFirm] = useState('All')
  const [editing, setEditing] = useState<Broker | null>(null)
  const [adding, setAdding] = useState(false)
  const [form, setForm] = useState<Omit<Broker, 'id'>>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [status, setStatus] = useState('')

  useEffect(() => {
    fetch('/api/brokers')
      .then(r => r.json())
      .then(d => { setBrokers(Array.isArray(d) ? d : []); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  const filtered = useMemo(() => {
    let d = brokers
    if (region !== 'All') d = d.filter(b => b.region === region)
    if (firm !== 'All') d = d.filter(b => b.firm === firm)
    if (search) {
      const q = search.toLowerCase()
      d = d.filter(b => b.name.toLowerCase().includes(q) || b.firm.toLowerCase().includes(q) || b.email?.toLowerCase().includes(q) || b.notes?.toLowerCase().includes(q))
    }
    return d
  }, [brokers, region, firm, search])

  // Group by region → firm
  const grouped = useMemo(() => {
    const out: Record<string, Record<string, Broker[]>> = {}
    for (const b of filtered) {
      if (!out[b.region]) out[b.region] = {}
      if (!out[b.region][b.firm]) out[b.region][b.firm] = []
      out[b.region][b.firm].push(b)
    }
    return out
  }, [filtered])

  async function handleSave() {
    setSaving(true)
    try {
      if (adding) {
        const res = await fetch('/api/brokers', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(form) })
        const d = await res.json()
        if (d.id) setBrokers(prev => [...prev, d])
      } else if (editing) {
        const res = await fetch('/api/brokers', { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id: editing.id, ...form }) })
        const d = await res.json()
        if (d.id) setBrokers(prev => prev.map(b => b.id === d.id ? d : b))
      }
      setAdding(false); setEditing(null); setForm(EMPTY)
      setStatus('✓ Saved'); setTimeout(() => setStatus(''), 2500)
    } catch { setStatus('⚠ Error saving') }
    setSaving(false)
  }

  async function handleDelete(id: string) {
    if (!confirm('Remove this broker?')) return
    await fetch('/api/brokers', { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id }) })
    setBrokers(prev => prev.filter(b => b.id !== id))
  }

  function openEdit(b: Broker) {
    setEditing(b)
    setForm({ name: b.name, title: b.title || '', firm: b.firm, region: b.region, email: b.email || '', phone: b.phone || '', cell: b.cell || '', notes: b.notes || '' })
    setAdding(false)
  }

  function openAdd() {
    setAdding(true); setEditing(null)
    setForm(EMPTY)
  }

  const regionOrder = ['DC / Mid-Atlantic', 'Georgia', 'Florida', 'Carolinas', 'Texas', 'Tennessee', 'Philadelphia', 'Arizona']

  return (
    <div style={{ padding: '24px 28px', fontFamily: "'DM Sans',sans-serif" }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <div>
          <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 22, fontWeight: 700, color: NAVY }}>Broker Directory</div>
          <div style={{ fontSize: 12, color: '#8A9BB0', marginTop: 2 }}>{brokers.length} contacts across {new Set(brokers.map(b => b.region)).size} regions</div>
        </div>
        <button onClick={openAdd} style={{ padding: '8px 18px', background: NAVY, color: GOLD, border: 'none', borderRadius: 8, fontSize: 12, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.08em' }}>
          + Add Broker
        </button>
      </div>

      {/* Filters */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
        <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search name, firm, email…"
          style={{ flex: '1 1 220px', padding: '8px 12px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 8, fontSize: 13, fontFamily: "'DM Sans',sans-serif", outline: 'none' }} />
        <select value={region} onChange={e => setRegion(e.target.value)}
          style={{ padding: '8px 12px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 8, fontSize: 13, fontFamily: "'DM Sans',sans-serif", background: '#fff' }}>
          {REGIONS.map(r => <option key={r}>{r}</option>)}
        </select>
        <select value={firm} onChange={e => setFirm(e.target.value)}
          style={{ padding: '8px 12px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 8, fontSize: 13, fontFamily: "'DM Sans',sans-serif", background: '#fff' }}>
          {FIRMS.map(f => <option key={f}>{f}</option>)}
        </select>
        <span style={{ fontSize: 12, color: '#8A9BB0' }}>{filtered.length} contacts</span>
        {status && <span style={{ fontSize: 12, color: status.startsWith('✓') ? '#2E7D50' : '#C0392B' }}>{status}</span>}
      </div>

      {/* Content */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: '#8A9BB0' }}>Loading brokers…</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
          {regionOrder.filter(r => grouped[r]).map(regionName => (
            <div key={regionName}>
              {/* Region header */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: GOLD, letterSpacing: '0.15em', textTransform: 'uppercase' }}>{regionName}</div>
                <div style={{ flex: 1, height: 1, background: 'rgba(201,168,76,0.2)' }} />
                <div style={{ fontSize: 11, color: '#8A9BB0' }}>{Object.values(grouped[regionName]).flat().length} contacts</div>
              </div>

              {/* Firms in this region */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {Object.entries(grouped[regionName]).sort(([a],[b]) => a.localeCompare(b)).map(([firmName, people]) => (
                  <div key={firmName} style={{ background: '#fff', border: '1px solid rgba(13,27,46,0.08)', borderRadius: 10, overflow: 'hidden' }}>
                    {/* Firm header */}
                    <div style={{ background: NAVY, padding: '7px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <span style={{ fontSize: 11, fontWeight: 700, color: GOLD, letterSpacing: '0.08em' }}>{firmName}</span>
                      <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.35)' }}>{people.length}</span>
                    </div>
                    {/* Contact rows */}
                    <div>
                      {people.map((b, i) => (
                        <div key={b.id} style={{ display: 'grid', gridTemplateColumns: '180px 60px 220px 160px 160px 1fr auto', gap: 0, alignItems: 'center', borderBottom: i < people.length-1 ? '1px solid rgba(13,27,46,0.04)' : 'none', padding: '8px 14px' }}
                          onMouseEnter={e => (e.currentTarget.style.background = 'rgba(201,168,76,0.03)')}
                          onMouseLeave={e => (e.currentTarget.style.background = '')}>
                          <div style={{ fontSize: 13, fontWeight: 600, color: NAVY }}>{b.name}</div>
                          <div style={{ fontSize: 11, color: '#8A9BB0' }}>{b.title || '—'}</div>
                          <div>
                            {b.email ? (
                              <a href={`mailto:${b.email}`} style={{ fontSize: 11, color: '#2E6B9E', textDecoration: 'none' }}>{b.email}</a>
                            ) : <span style={{ fontSize: 11, color: '#8A9BB0' }}>—</span>}
                          </div>
                          <div style={{ fontSize: 11, color: '#555' }}>
                            {b.phone ? <a href={`tel:${b.phone}`} style={{ color: 'inherit', textDecoration: 'none' }}>{b.phone}</a> : '—'}
                          </div>
                          <div style={{ fontSize: 11, color: '#555' }}>
                            {b.cell ? <a href={`tel:${b.cell}`} style={{ color: 'inherit', textDecoration: 'none' }}>{b.cell} <span style={{ fontSize: 9, color: '#8A9BB0' }}>cell</span></a> : ''}
                          </div>
                          <div style={{ fontSize: 11, color: '#8A9BB0', fontStyle: b.notes ? 'italic' : 'normal' }}>{b.notes || ''}</div>
                          <div style={{ display: 'flex', gap: 6 }}>
                            <button onClick={() => openEdit(b)} style={{ padding: '3px 8px', fontSize: 10, border: '1px solid rgba(13,27,46,0.12)', borderRadius: 5, background: '#fff', cursor: 'pointer', color: '#8A9BB0' }}>Edit</button>
                            <button onClick={() => handleDelete(b.id)} style={{ padding: '3px 8px', fontSize: 10, border: '1px solid rgba(192,57,43,0.2)', borderRadius: 5, background: '#fff', cursor: 'pointer', color: '#C0392B' }}>✕</button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add / Edit Modal */}
      {(adding || editing) && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(13,27,46,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          onClick={() => { setAdding(false); setEditing(null) }}>
          <div style={{ background: '#fff', borderRadius: 14, padding: 32, width: 520, maxWidth: '94vw' }} onClick={e => e.stopPropagation()}>
            <h3 style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 20, fontWeight: 700, color: NAVY, marginBottom: 24 }}>
              {adding ? 'Add Broker' : 'Edit Broker'}
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div style={{ gridColumn: 'span 2' }}>
                <label style={lbl}>Name</label>
                <input style={inp} value={form.name} onChange={e => setForm(p => ({...p, name: e.target.value}))} />
              </div>
              <div>
                <label style={lbl}>Title</label>
                <input style={inp} value={form.title || ''} onChange={e => setForm(p => ({...p, title: e.target.value}))} placeholder="e.g. VC, MD, EVP" />
              </div>
              <div>
                <label style={lbl}>Firm</label>
                <input style={inp} value={form.firm} onChange={e => setForm(p => ({...p, firm: e.target.value}))} list="firms-list" />
                <datalist id="firms-list">{FIRMS.slice(1).map(f => <option key={f} value={f} />)}</datalist>
              </div>
              <div style={{ gridColumn: 'span 2' }}>
                <label style={lbl}>Region</label>
                <select style={inp} value={form.region} onChange={e => setForm(p => ({...p, region: e.target.value}))}>
                  {REGIONS.slice(1).map(r => <option key={r}>{r}</option>)}
                </select>
              </div>
              <div style={{ gridColumn: 'span 2' }}>
                <label style={lbl}>Email</label>
                <input style={inp} type="email" value={form.email || ''} onChange={e => setForm(p => ({...p, email: e.target.value}))} />
              </div>
              <div>
                <label style={lbl}>Work Phone</label>
                <input style={inp} value={form.phone || ''} onChange={e => setForm(p => ({...p, phone: e.target.value}))} />
              </div>
              <div>
                <label style={lbl}>Cell</label>
                <input style={inp} value={form.cell || ''} onChange={e => setForm(p => ({...p, cell: e.target.value}))} />
              </div>
              <div style={{ gridColumn: 'span 2' }}>
                <label style={lbl}>Notes</label>
                <input style={inp} value={form.notes || ''} onChange={e => setForm(p => ({...p, notes: e.target.value}))} placeholder="e.g. Richmond, Middle Markets…" />
              </div>
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 24 }}>
              <button onClick={() => { setAdding(false); setEditing(null) }} style={{ padding: '8px 20px', border: '1px solid rgba(13,27,46,0.15)', borderRadius: 8, background: '#fff', color: '#8A9BB0', fontSize: 13, cursor: 'pointer' }}>Cancel</button>
              <button onClick={handleSave} disabled={saving || !form.name} style={{ padding: '8px 20px', background: saving ? '#8A9BB0' : NAVY, color: GOLD, border: 'none', borderRadius: 8, fontSize: 13, fontWeight: 700, cursor: saving ? 'not-allowed' : 'pointer' }}>
                {saving ? 'Saving…' : 'Save'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
