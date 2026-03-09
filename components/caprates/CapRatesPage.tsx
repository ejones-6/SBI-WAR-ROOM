'use client'
import { useState } from 'react'
import type { CapRate, Deal } from '@/lib/types'
import { fmtShort, fmtPct } from '@/lib/utils'

interface Props {
  capRateMap: Record<string, CapRate>
  deals: Deal[]
  onSave: (cr: CapRate) => Promise<any>
}

export default function CapRatesPage({ capRateMap, deals, onSave }: Props) {
  const [search, setSearch] = useState('')
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState<Partial<CapRate>>({})
  const [saving, setSaving] = useState(false)

  const dealsWithCR = deals.filter(d =>
    d.name.toLowerCase().includes(search.toLowerCase())
  ).slice(0, 100)

  function startEdit(dealName: string) {
    const cr = capRateMap[dealName] ?? {}
    setForm({
      deal_name: dealName,
      broker_cap_rate: cr.broker_cap_rate ?? null,
      noi_cap_rate: cr.noi_cap_rate ?? null,
      purchase_price: cr.purchase_price ?? null,
      sold_price: cr.sold_price ?? null,
      delta: cr.delta ?? null,
    })
    setEditing(dealName)
  }

  async function handleSave() {
    if (!form.deal_name) return
    setSaving(true)
    await onSave(form as CapRate)
    setSaving(false)
    setEditing(null)
  }

  const crList = Object.values(capRateMap)
  const avgBroker = crList.filter(c => c.broker_cap_rate).reduce((s, c, _, a) => s + Number(c.broker_cap_rate) / a.length, 0)
  const avgNOI = crList.filter(c => c.noi_cap_rate).reduce((s, c, _, a) => s + Number(c.noi_cap_rate) / a.length, 0)

  return (
    <div style={{ padding: '24px 32px' }}>
      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 16, marginBottom: 24 }}>
        {[
          { label: 'Tracked Deals', value: crList.length.toString() },
          { label: 'Avg Broker Cap Rate', value: avgBroker ? fmtPct(avgBroker) : '—' },
          { label: 'Avg NOI/PP Cap Rate', value: avgNOI ? fmtPct(avgNOI) : '—' },
        ].map(s => (
          <div key={s.label} style={{ background: '#fff', borderRadius: 10, padding: '16px 20px', border: '1px solid rgba(13,27,46,0.07)' }}>
            <div style={{ fontSize: 10, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 5 }}>{s.label}</div>
            <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 24, fontWeight: 700, color: '#0D1B2E' }}>{s.value}</div>
          </div>
        ))}
      </div>

      {/* Search */}
      <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search deals…"
        style={{ width: '100%', padding: '9px 14px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 8, fontSize: 13, fontFamily: "'DM Sans',sans-serif", marginBottom: 16, outline: 'none' }} />

      {/* Table */}
      <div style={{ background: '#fff', border: '1px solid rgba(13,27,46,0.08)', borderRadius: 10, overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#0D1B2E' }}>
              {['Deal Name','Broker Cap Rate','NOI/PP Cap Rate','Ask Price','Sold Price','Delta',''].map(h => (
                <th key={h} style={{ padding: '10px 14px', textAlign: 'left', fontSize: 10, fontWeight: 600, color: '#F0B429', letterSpacing: '0.1em', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {dealsWithCR.map(deal => {
              const cr = capRateMap[deal.name]
              const crPct = (v: number | null | undefined) => {
                if (!v) return <span style={{ color: '#8A9BB0' }}>—</span>
                const pct = Number(v)
                const cls = pct < 4.5 ? '#C0392B' : pct < 5.5 ? '#B87A00' : '#2E7D50'
                return <span style={{ background: `${cls}18`, color: cls, fontWeight: 700, borderRadius: 8, padding: '2px 8px', fontSize: 11 }}>{fmtPct(pct)}</span>
              }
              return (
                <tr key={deal.id} style={{ borderBottom: '1px solid rgba(13,27,46,0.05)' }}>
                  <td style={{ padding: '9px 14px', fontSize: 13, fontWeight: 500, color: '#0D1B2E', maxWidth: 260 }}>
                    {deal.name}
                    <small style={{ display: 'block', fontSize: 11, color: '#8A9BB0' }}>{deal.market}</small>
                  </td>
                  <td style={{ padding: '9px 14px' }}>{crPct(cr?.broker_cap_rate)}</td>
                  <td style={{ padding: '9px 14px' }}>{crPct(cr?.noi_cap_rate)}</td>
                  <td style={{ padding: '9px 14px', fontSize: 12, fontVariantNumeric: 'tabular-nums' }}>{cr?.purchase_price ? fmtShort(cr.purchase_price * 1000) : '—'}</td>
                  <td style={{ padding: '9px 14px', fontSize: 12, fontVariantNumeric: 'tabular-nums' }}>{cr?.sold_price ? fmtShort(cr.sold_price * 1000) : '—'}</td>
                  <td style={{ padding: '9px 14px', fontSize: 12 }}>
                    {cr?.delta != null ? (
                      <span style={{ color: Number(cr.delta) >= 0 ? '#2E7D50' : '#C0392B', fontWeight: 600 }}>
                        {Number(cr.delta) >= 0 ? '+' : ''}{(Number(cr.delta) * 100).toFixed(1)}%
                      </span>
                    ) : '—'}
                  </td>
                  <td style={{ padding: '9px 14px' }}>
                    <button onClick={() => startEdit(deal.name)} style={{ padding: '4px 12px', border: '1px solid rgba(13,27,46,0.15)', borderRadius: 6, background: '#fff', color: '#0D1B2E', fontSize: 11, cursor: 'pointer', fontFamily: "'DM Sans',sans-serif", fontWeight: 600 }}>
                      {cr ? 'Edit' : '+ Add'}
                    </button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {/* Edit Modal */}
      {editing && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(13,27,46,0.5)', zIndex: 3000, display: 'flex', alignItems: 'center', justifyContent: 'center' }} onClick={() => setEditing(null)}>
          <div style={{ background: '#fff', borderRadius: 14, padding: 32, width: 480, maxWidth: '94vw' }} onClick={e => e.stopPropagation()}>
            <h3 style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 20, fontWeight: 700, color: '#0D1B2E', marginBottom: 4 }}>Cap Rate — {editing}</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 20 }}>
              {[
                { label: 'Broker Cap Rate (%)', key: 'broker_cap_rate' },
                { label: 'NOI/PP Cap Rate (%)', key: 'noi_cap_rate' },
                { label: 'Ask/Guidance Price ($K)', key: 'purchase_price' },
                { label: 'Sold Price ($K)', key: 'sold_price' },
                { label: 'Delta (decimal, e.g. 0.02)', key: 'delta' },
              ].map(f => (
                <div key={f.key}>
                  <label style={{ display: 'block', fontSize: 10, fontWeight: 600, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 5 }}>{f.label}</label>
                  <input type="number" step="0.001" value={(form as any)[f.key] ?? ''} onChange={e => setForm(p => ({ ...p, [f.key]: e.target.value ? parseFloat(e.target.value) : null }))}
                    style={{ width: '100%', padding: '8px 10px', border: '1px solid rgba(13,27,46,0.12)', borderRadius: 7, fontSize: 13, fontFamily: "'DM Sans',sans-serif" }} />
                </div>
              ))}
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 24 }}>
              <button onClick={() => setEditing(null)} style={{ padding: '8px 20px', border: '1px solid rgba(13,27,46,0.15)', borderRadius: 8, background: '#fff', color: '#8A9BB0', fontSize: 13, cursor: 'pointer', fontFamily: "'DM Sans',sans-serif" }}>Cancel</button>
              <button onClick={handleSave} disabled={saving} style={{ padding: '8px 20px', background: saving ? '#8A9BB0' : '#0D1B2E', color: '#F0B429', border: 'none', borderRadius: 8, fontSize: 13, fontWeight: 700, cursor: 'pointer', fontFamily: "'DM Sans',sans-serif" }}>
                {saving ? 'Saving…' : 'Save'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
