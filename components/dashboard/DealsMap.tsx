'use client'
import { useEffect, useRef, useState, useCallback } from 'react'
import type { Deal } from '@/lib/types'
import { fmtShort, statusLabel, statusClass, formatBidDate, bidDateClass } from '@/lib/utils'

interface Props {
  deals: Deal[]
  onOpenDeal: (d: Deal) => void
}

interface GeoDeal extends Deal {
  lat: number
  lng: number
}

const NOMINATIM = 'https://nominatim.openstreetmap.org/search'

async function geocode(address: string, market: string): Promise<{ lat: number; lng: number } | null> {
  const query = `${address}, ${market}`
  try {
    const res = await fetch(`${NOMINATIM}?q=${encodeURIComponent(query)}&format=json&limit=1`, {
      headers: { 'Accept-Language': 'en', 'User-Agent': 'SBI-WarRoom/1.0' }
    })
    const data = await res.json()
    if (data?.[0]) return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
  } catch {}
  return null
}

// Cache geocoded results in memory
const geoCache: Record<string, { lat: number; lng: number } | null> = {}

export default function DealsMap({ deals, onOpenDeal }: Props) {
  const mapRef = useRef<any>(null)
  const markersRef = useRef<any[]>([])
  const leafletRef = useRef<any>(null)
  const [geoDeals, setGeoDeals] = useState<GeoDeal[]>([])
  const [loading, setLoading] = useState(true)
  const [progress, setProgress] = useState(0)
  const [selected, setSelected] = useState<Deal | null>(null)
  const mapDivRef = useRef<HTMLDivElement>(null)
  const [filter, setFilter] = useState<'all' | 'new' | 'active'>('all')

  // Load Leaflet and geocode deals
  useEffect(() => {
    async function init() {
      // Load Leaflet CSS
      if (!document.getElementById('leaflet-css')) {
        const link = document.createElement('link')
        link.id = 'leaflet-css'
        link.rel = 'stylesheet'
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
        document.head.appendChild(link)
      }

      // Load Leaflet JS
      if (!leafletRef.current) {
        await new Promise<void>(resolve => {
          if ((window as any).L) { leafletRef.current = (window as any).L; resolve(); return }
          const script = document.createElement('script')
          script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
          script.onload = () => { leafletRef.current = (window as any).L; resolve() }
          document.head.appendChild(script)
        })
      }

      // Geocode deals with addresses
      const dealsWithAddr = deals.filter(d => d.address && d.market)
      const results: GeoDeal[] = []
      let done = 0

      for (const deal of dealsWithAddr) {
        const key = `${deal.address}|${deal.market}`
        if (geoCache[key] === undefined) {
          // Rate limit Nominatim to 1 req/sec
          await new Promise(r => setTimeout(r, 1100))
          geoCache[key] = await geocode(deal.address!, deal.market || '')
        }
        const coords = geoCache[key]
        if (coords) results.push({ ...deal, ...coords })
        done++
        setProgress(Math.round((done / dealsWithAddr.length) * 100))
      }

      setGeoDeals(results)
      setLoading(false)
    }
    init()
  }, [deals])

  // Init map once loading done
  useEffect(() => {
    if (loading || !mapDivRef.current || mapRef.current) return
    const L = leafletRef.current
    if (!L) return

    const map = L.map(mapDivRef.current, { zoomControl: true }).setView([33.5, -84.4], 5)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      attribution: '© OpenStreetMap © CARTO', maxZoom: 19
    }).addTo(map)
    mapRef.current = map
  }, [loading])

  // Add/update markers when geoDeals or filter changes
  useEffect(() => {
    const L = leafletRef.current
    const map = mapRef.current
    if (!L || !map || loading) return

    // Clear old markers
    markersRef.current.forEach(m => m.remove())
    markersRef.current = []

    const filtered = geoDeals.filter(d => {
      if (filter === 'new') return d.status.includes('1 -')
      if (filter === 'active') return d.status.includes('2 -')
      return true
    })

    filtered.forEach(deal => {
      const isNew = deal.status.includes('1 -')
      const isActive = deal.status.includes('2 -')
      const color = isActive ? '#1565A0' : isNew ? '#C9A84C' : '#8A9BB0'

      const icon = L.divIcon({
        className: '',
        html: `<div style="width:10px;height:10px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,0.3);cursor:pointer"></div>`,
        iconSize: [10, 10],
        iconAnchor: [5, 5]
      })

      const marker = L.marker([deal.lat, deal.lng], { icon })
        .addTo(map)
        .on('click', () => setSelected(deal))

      markersRef.current.push(marker)
    })
  }, [geoDeals, filter, loading])

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
      {/* Toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 20px', background: '#fff', borderBottom: '1px solid rgba(13,27,46,0.07)' }}>
        <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 17, fontWeight: 700, color: '#0D1B2E', flex: 1 }}>
          Deal Map <span style={{ fontSize: 12, fontWeight: 400, color: '#8A9BB0', fontFamily: 'inherit' }}>— {geoDeals.length} mapped</span>
        </div>
        {loading && (
          <div style={{ fontSize: 12, color: '#8A9BB0' }}>Geocoding... {progress}%</div>
        )}
        {['all', 'new', 'active'].map(f => (
          <button key={f} onClick={() => setFilter(f as any)} style={{
            padding: '5px 14px', borderRadius: 6, fontSize: 11, fontWeight: 600, cursor: 'pointer', border: 'none',
            background: filter === f ? '#0D1B2E' : 'rgba(13,27,46,0.06)',
            color: filter === f ? '#C9A84C' : '#8A9BB0',
            textTransform: 'capitalize'
          }}>{f === 'all' ? 'All Deals' : f === 'new' ? 'New' : 'Active'}</button>
        ))}
        <div style={{ display: 'flex', gap: 10, fontSize: 11, color: '#8A9BB0' }}>
          <span><span style={{ display: 'inline-block', width: 8, height: 8, borderRadius: '50%', background: '#C9A84C', marginRight: 4 }} />New</span>
          <span><span style={{ display: 'inline-block', width: 8, height: 8, borderRadius: '50%', background: '#1565A0', marginRight: 4 }} />Active</span>
          <span><span style={{ display: 'inline-block', width: 8, height: 8, borderRadius: '50%', background: '#8A9BB0', marginRight: 4 }} />Other</span>
        </div>
      </div>

      {/* Map */}
      <div style={{ flex: 1, position: 'relative' }}>
        <div ref={mapDivRef} style={{ width: '100%', height: '100%' }} />

        {/* Deal popup */}
        {selected && (
          <div style={{ position: 'absolute', top: 16, right: 16, zIndex: 1000, background: '#fff', borderRadius: 12, boxShadow: '0 4px 24px rgba(13,27,46,0.15)', width: 280, overflow: 'hidden' }}>
            <div style={{ background: '#0D1B2E', padding: '12px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 15, fontWeight: 700, color: '#fff', lineHeight: 1.3 }}>{selected.name}</div>
                <div style={{ fontSize: 11, color: '#8A9BB0', marginTop: 2 }}>{selected.market}</div>
              </div>
              <button onClick={() => setSelected(null)} style={{ background: 'none', border: 'none', color: '#8A9BB0', cursor: 'pointer', fontSize: 16, lineHeight: 1, padding: 0 }}>×</button>
            </div>
            <div style={{ padding: '12px 16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 12 }}>
                {[
                  { label: 'Status', value: statusLabel(selected.status) },
                  { label: 'Units', value: selected.units?.toLocaleString() || '—' },
                  { label: 'Guidance', value: fmtShort(selected.purchase_price) },
                  { label: '$/Unit', value: selected.price_per_unit ? `$${Math.round(selected.price_per_unit).toLocaleString()}` : '—' },
                  { label: 'Broker', value: selected.broker || '—' },
                  { label: 'Bid Date', value: formatBidDate(selected.bid_due_date) || '—' },
                ].map(({ label, value }) => (
                  <div key={label}>
                    <div style={{ fontSize: 9, color: '#8A9BB0', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 2 }}>{label}</div>
                    <div style={{ fontSize: 12, fontWeight: 600, color: '#0D1B2E' }}>{value}</div>
                  </div>
                ))}
              </div>
              {selected.address && (
                <div style={{ fontSize: 11, color: '#8A9BB0', marginBottom: 12 }}>{selected.address}, {selected.market}</div>
              )}
              <button onClick={() => { onOpenDeal(selected); setSelected(null) }} style={{ width: '100%', padding: '8px', background: '#0D1B2E', color: '#C9A84C', border: 'none', borderRadius: 7, fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>
                Open Full Deal →
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
