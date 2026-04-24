'use client'
import { useState, useCallback } from 'react'
import * as XLSX from 'xlsx'

const NAVY = '#0D1B2E'
const GOLD = '#C9A84C'

interface UnitMixRow {
  label: string
  bed: number
  units: number
  avgSF: number
  occPct: number
  avgInPlace: number
}

interface LeaseExpMonth {
  label: string
  beds: Record<number, number>
}

interface RentRollData {
  propertyName: string
  totalUnits: number
  asOf: string
  mix: UnitMixRow[]
  expSchedule: LeaseExpMonth[]
}

const BED_COLORS: Record<number, string> = {
  0: '#8A9BB0',
  1: '#2563EB',
  2: '#93C5FD',
  3: '#F97316',
  4: '#A855F7',
}
const BED_LABELS: Record<number, string> = {
  0: 'Studio', 1: '1 Bed', 2: '2 Bed', 3: '3 Bed', 4: '4 Bed'
}

function parseRentRoll(file: ArrayBuffer): RentRollData | null {
  try {
    const wb = XLSX.read(file, { type: 'array', cellDates: true })

    // Get property name from Rent Roll sheet row 2
    const rrSheet = wb.Sheets['Rent Roll']
    const sdSheet = wb.Sheets['Source Data']
    if (!rrSheet || !sdSheet) return null

    const rrData = XLSX.utils.sheet_to_json<any[]>(rrSheet, { header: 1, raw: false, dateNF: 'yyyy-mm-dd' })
    const sdData = XLSX.utils.sheet_to_json<any[]>(sdSheet, { header: 1, raw: false, dateNF: 'yyyy-mm-dd' })

    // Property name from row 1 col 0 of Rent Roll
    const propName = String(rrData[0]?.[0] || 'Property')
    // As-of date from Source Data row 6 col 1
    const asOf = String(sdData[5]?.[1] || '')

    // Parse Rent Roll — data starts row 10 (index 9), cols: 2=UnitID,4=NetSF,5=Bed,6=Bath,9=OccStatus,11=InPlaceRent
    const units: { uid: string; bed: number; sf: number; occ: string; inplace: number }[] = []
    for (let i = 9; i < rrData.length; i++) {
      const row = rrData[i]
      if (!row[2]) break
      const bed = parseInt(row[5]) || 0
      const sf = parseFloat(row[4]) || 0
      const occ = String(row[9] || '')
      const inplace = parseFloat(String(row[11]).replace(/[,$]/g, '')) || 0
      units.push({ uid: String(row[2]), bed, sf, occ, inplace })
    }

    // Build uid->bed map
    const uidBed: Record<string, number> = {}
    units.forEach(u => { uidBed[u.uid] = u.bed })

    // Aggregate unit mix by bed type
    const mixMap: Record<number, { units: number; sfSum: number; occCount: number; ipSum: number; ipCount: number }> = {}
    for (const u of units) {
      if (!mixMap[u.bed]) mixMap[u.bed] = { units: 0, sfSum: 0, occCount: 0, ipSum: 0, ipCount: 0 }
      mixMap[u.bed].units++
      mixMap[u.bed].sfSum += u.sf
      if (u.occ.includes('Occupied') || u.occ.includes('Notice')) mixMap[u.bed].occCount++
      if (u.inplace > 0) { mixMap[u.bed].ipSum += u.inplace; mixMap[u.bed].ipCount++ }
    }

    const mix: UnitMixRow[] = [0, 1, 2, 3, 4]
      .filter(b => mixMap[b])
      .map(b => ({
        label: BED_LABELS[b],
        bed: b,
        units: mixMap[b].units,
        avgSF: Math.round(mixMap[b].sfSum / mixMap[b].units),
        occPct: mixMap[b].occCount / mixMap[b].units * 100,
        avgInPlace: mixMap[b].ipCount ? Math.round(mixMap[b].ipSum / mixMap[b].ipCount) : 0,
      }))

    // Totals row
    const totalUnits = units.length
    const totalOcc = units.filter(u => u.occ.includes('Occupied') || u.occ.includes('Notice')).length
    const totalIP = units.filter(u => u.inplace > 0)
    mix.push({
      label: 'All Units', bed: -1,
      units: totalUnits,
      avgSF: Math.round(units.reduce((s, u) => s + u.sf, 0) / totalUnits),
      occPct: totalOcc / totalUnits * 100,
      avgInPlace: totalIP.length ? Math.round(totalIP.reduce((s, u) => s + u.inplace, 0) / totalIP.length) : 0,
    })

    // Parse Source Data for lease expirations
    // Data starts row 13 (index 12), cols: 1=UnitID, 8=LeaseExp
    const now = new Date()
    const expMap: Record<string, Record<number, number>> = {}

    for (let i = 12; i < sdData.length; i++) {
      const row = sdData[i]
      if (!row[1]) break
      const uid = String(row[1])
      const expStr = String(row[8] || '')
      if (!expStr || expStr === 'undefined') continue
      const expDate = new Date(expStr)
      if (isNaN(expDate.getTime())) continue

      const bed = uidBed[uid] ?? 1
      let monthKey: string
      if (expDate < now) {
        monthKey = 'Earlier'
      } else {
        const diff = (expDate.getFullYear() - now.getFullYear()) * 12 + (expDate.getMonth() - now.getMonth())
        if (diff > 12) {
          monthKey = 'Later'
        } else {
          monthKey = expDate.toLocaleDateString('en-US', { month: 'short', year: '2-digit' })
        }
      }

      if (!expMap[monthKey]) expMap[monthKey] = {}
      expMap[monthKey][bed] = (expMap[monthKey][bed] || 0) + 1
    }

    // Order months
    const monthOrder: string[] = ['Earlier']
    const d = new Date(now)
    for (let i = 0; i <= 12; i++) {
      monthOrder.push(d.toLocaleDateString('en-US', { month: 'short', year: '2-digit' }))
      d.setMonth(d.getMonth() + 1)
    }
    monthOrder.push('Later')

    const expSchedule: LeaseExpMonth[] = monthOrder
      .filter(m => expMap[m])
      .map(m => ({ label: m, beds: expMap[m] }))

    return { propertyName: propName, totalUnits, asOf, mix, expSchedule }
  } catch (e) {
    console.error('RentRoll parse error:', e)
    return null
  }
}

interface Props {
  savedData: RentRollData | null
  onSave: (data: RentRollData) => void
}

export default function RentRollPanel({ savedData, onSave }: Props) {
  const [data, setData] = useState<RentRollData | null>(savedData)
  const [loading, setLoading] = useState(false)
  const [err, setErr] = useState('')

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setLoading(true); setErr('')
    try {
      const buf = await file.arrayBuffer()
      const parsed = parseRentRoll(buf)
      if (!parsed) { setErr('Could not parse rent roll — make sure this is a redIQ Floor Plan Summary file'); setLoading(false); return }
      setData(parsed)
      onSave(parsed)
    } catch { setErr('Error reading file') }
    setLoading(false)
    e.target.value = ''
  }

  if (!data) return (
    <div style={{ padding: 40, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: 300 }}>
      <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 20, fontWeight: 700, color: NAVY, marginBottom: 8 }}>Rent Roll</div>
      <div style={{ fontSize: 12, color: '#8A9BB0', marginBottom: 24 }}>Upload a redIQ Floor Plan Summary to get started</div>
      <label style={{ padding: '10px 24px', background: NAVY, color: GOLD, borderRadius: 8, fontSize: 12, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.08em' }}>
        {loading ? 'Parsing…' : '↑ Upload Rent Roll'}
        <input type="file" accept=".xlsx,.xls" style={{ display: 'none' }} onChange={handleFile} />
      </label>
      {err && <div style={{ marginTop: 12, fontSize: 11, color: '#C0392B' }}>{err}</div>}
    </div>
  )

  const bedTypes = [...new Set(data.mix.filter(r => r.bed >= 0).map(r => r.bed))].sort()
  const maxExp = Math.max(...data.expSchedule.map(m => Object.values(m.beds).reduce((a,b)=>a+b,0)), 1)

  return (
    <div style={{ padding: '20px 24px', fontFamily: "'DM Sans',sans-serif" }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20 }}>
        <div>
          <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 18, fontWeight: 700, color: NAVY }}>Rent Roll</div>
          <div style={{ fontSize: 11, color: '#8A9BB0', marginTop: 2 }}>{data.propertyName}{data.asOf ? ` · ${data.asOf}` : ''} · {data.totalUnits} units</div>
        </div>
        <label style={{ padding: '6px 14px', background: 'rgba(13,27,46,0.06)', color: NAVY, borderRadius: 7, fontSize: 11, fontWeight: 600, cursor: 'pointer', border: '1px solid rgba(13,27,46,0.1)' }}>
          Re-upload
          <input type="file" accept=".xlsx,.xls" style={{ display: 'none' }} onChange={handleFile} />
        </label>
      </div>

      {/* Unit Mix Table */}
      <div style={{ marginBottom: 28 }}>
        <div style={{ fontSize: 12, fontWeight: 700, color: NAVY, letterSpacing: '0.05em', textTransform: 'uppercase', marginBottom: 10 }}>Unit Mix</div>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr style={{ background: NAVY }}>
              {['Unit Type', '# Units', 'Avg Size', 'Occupancy', 'In-Place Rent'].map(h => (
                <th key={h} style={{ padding: '8px 14px', textAlign: h === 'Unit Type' ? 'left' : 'right', fontSize: 10, fontWeight: 700, color: GOLD, letterSpacing: '0.1em', textTransform: 'uppercase' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.mix.map((row, i) => {
              const isTotal = row.label === 'All Units'
              return (
                <tr key={row.label} style={{ background: isTotal ? 'rgba(13,27,46,0.04)' : i % 2 === 0 ? '#fff' : 'rgba(13,27,46,0.015)', borderBottom: '1px solid rgba(13,27,46,0.06)', fontWeight: isTotal ? 700 : 400 }}>
                  <td style={{ padding: '9px 14px', color: NAVY, display: 'flex', alignItems: 'center', gap: 8 }}>
                    {row.bed >= 0 && <span style={{ width: 8, height: 8, borderRadius: '50%', background: BED_COLORS[row.bed], flexShrink: 0, display: 'inline-block' }} />}
                    {row.label}
                  </td>
                  <td style={{ padding: '9px 14px', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{row.units.toLocaleString()}</td>
                  <td style={{ padding: '9px 14px', textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>{row.avgSF.toLocaleString()} sf</td>
                  <td style={{ padding: '9px 14px', textAlign: 'right', color: row.occPct >= 95 ? '#2E7D50' : row.occPct >= 90 ? '#C9A84C' : '#C0392B', fontWeight: 600 }}>{row.occPct.toFixed(1)}%</td>
                  <td style={{ padding: '9px 14px', textAlign: 'right', color: isTotal ? GOLD : NAVY, fontVariantNumeric: 'tabular-nums' }}>${row.avgInPlace.toLocaleString()}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {/* Lease Expiration Chart */}
      {data.expSchedule.length > 0 && (
        <div>
          <div style={{ fontSize: 12, fontWeight: 700, color: NAVY, letterSpacing: '0.05em', textTransform: 'uppercase', marginBottom: 16 }}>Lease Expiration Schedule</div>
          {/* Legend */}
          <div style={{ display: 'flex', gap: 16, marginBottom: 12, flexWrap: 'wrap' }}>
            {bedTypes.map(b => (
              <div key={b} style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11 }}>
                <span style={{ width: 10, height: 10, borderRadius: 2, background: BED_COLORS[b], display: 'inline-block' }} />
                {BED_LABELS[b]}
              </div>
            ))}
          </div>
          {/* Bars */}
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 160, overflowX: 'auto', paddingBottom: 4 }}>
            {data.expSchedule.map(month => {
              const total = Object.values(month.beds).reduce((a,b)=>a+b,0)
              const barH = (total / maxExp) * 140
              let stackY = 0
              return (
                <div key={month.label} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', minWidth: 44, flex: '1 1 44px' }}>
                  <div style={{ fontSize: 9, color: total > maxExp * 0.7 ? '#C0392B' : '#555', fontWeight: 600, marginBottom: 2 }}>{total}</div>
                  <div style={{ position: 'relative', width: '100%', height: barH, display: 'flex', flexDirection: 'column-reverse' }}>
                    {bedTypes.map(b => {
                      const count = month.beds[b] || 0
                      if (!count) return null
                      const h = (count / maxExp) * 140
                      return (
                        <div key={b} style={{ width: '100%', height: h, background: BED_COLORS[b], opacity: 0.85 }} title={`${BED_LABELS[b]}: ${count}`} />
                      )
                    })}
                  </div>
                  <div style={{ fontSize: 9, color: '#8A9BB0', marginTop: 4, textAlign: 'center', lineHeight: 1.1 }}>{month.label}</div>
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
