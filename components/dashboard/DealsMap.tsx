'use client'
import { useEffect, useRef, useState, useMemo } from 'react'
import type { Deal } from '@/lib/types'
import { statusLabel, getRegion, REGION_LABELS } from '@/lib/utils'

interface Props {
  deals: Deal[]
  onOpenDeal: (d: Deal) => void
}

const STATUS_COLORS: Record<string, string> = {
  '1 -': '#E8A020',   // New — gold
  '2 -': '#2E6B9E',   // Active — blue
  '3 -': '#6B3FA0',   // Bid Placed — purple
  '5 -': '#8A9BB0',   // Dormant — grey
  '6 -': '#2E7D50',   // Passed — green
  '7 -': '#C0392B',   // Lost — red
  '9 -': '#1E7A6E',   // Exited
  '10-': '#C9A84C',   // Owned — light gold
  '11-': '#5D6D7E',   // Comp — slate
}

const NAMED_BROKERS = ['CBRE','Newmark','JLL','W&D','Northmarq','C&W','Berkadia','Eastdil','IPA']

function getBrokerBucket(broker: string | null | undefined): string {
  if (!broker) return 'Misc'
  const b = broker.trim()
  if (/^CBRE/i.test(b) || /CBRE/i.test(b)) return 'CBRE'
  if (/^Newmark/i.test(b) || /^NGKF/i.test(b) || /NewMark/i.test(b)) return 'Newmark'
  if (/^JLL/i.test(b)) return 'JLL'
  if (/^W&D/i.test(b) || /^Walker.*Dunlop/i.test(b)) return 'W&D'
  if (/^Northmarq/i.test(b) || /^NorthMarq/i.test(b) || /^North Marq/i.test(b)) return 'Northmarq'
  if (/^C&W/i.test(b) || /^Cushman/i.test(b)) return 'C&W'
  if (/^Berkadia/i.test(b)) return 'Berkadia'
  if (/^Eastdil/i.test(b)) return 'Eastdil'
  if (/^IPA/i.test(b) || /^Institutional Property/i.test(b)) return 'IPA'
  return 'Misc'
}

function getStatusColor(status: string): string {
  for (const [prefix, color] of Object.entries(STATUS_COLORS)) {
    if (status.startsWith(prefix) || status.includes(prefix.trim())) return color
  }
  return '#8A9BB0'
}

const STATUS_FILTERS = [
  { label: 'All', value: 'all' },
  { label: 'New', value: '1 -' },
  { label: 'Active', value: '2 -' },
  { label: 'Bid Placed', value: '3 -' },
  { label: 'Dormant', value: '5 -' },
  { label: 'Passed', value: '6 -' },
  { label: 'Lost', value: '7 -' },
  { label: 'Owned', value: '10-' },
]

const REGIONS = ['all', 'DC', 'Carolinas', 'GA', 'TX', 'TN', 'FL', 'Misc']
const REGION_DISPLAY: Record<string, string> = {
  DC: 'Mid-Atlantic', Carolinas: 'Carolinas', GA: 'Georgia',
  TX: 'Texas', TN: 'Tennessee', FL: 'Florida', Misc: 'Misc',
}
const BROKER_CHIPS = ['all', ...NAMED_BROKERS, 'Misc']

// Simple geocode cache using approximate city coordinates
const CITY_COORDS: Record<string, [number, number]> = {
  'Tampa, FL': [27.9506, -82.4572], 'Orlando, FL': [28.5383, -81.3792],
  'Jacksonville, FL': [30.3322, -81.6557], 'South Florida': [25.7617, -80.1918],
  'Naples/Fort Myers, FL': [26.1420, -81.7948], 'Atlanta, GA': [33.7490, -84.3880],
  'Savannah, GA': [32.0809, -81.0912], 'Charlotte, NC': [35.2271, -80.8431],
  'Raleigh/Durham, NC': [35.7796, -78.6382], 'Washington, DC': [38.9072, -77.0369],
  'Suburban Maryland': [39.0458, -76.6413], 'Northern Virginia': [38.8048, -77.0469],
  'Richmond, VA': [37.5407, -77.4360], 'Dallas, TX': [32.7767, -96.7970],
  'Houston, TX': [29.7604, -95.3698], 'Austin, TX': [30.2672, -97.7431],
  'San Antonio, TX': [29.4241, -98.4936], 'Nashville, TN': [36.1627, -86.7816],
}

export default function DealsMap({ deals, onOpenDeal }: Props) {
  const mapRef = useRef<HTMLDivElement>(null)
  const leafletRef = useRef<any>(null)
  const markersRef = useRef<any[]>([])
  const mapInstanceRef = useRef<any>(null)
  const [statusFilter, setStatusFilter] = useState(new Set(['all']))
  const [regionFilter, setRegionFilter] = useState(new Set(['all']))
  const [brokerFilter, setBrokerFilter] = useState(new Set(['all']))
  const [geocodeCache, setGeocodeCache] = useState<Record<string, [number, number] | null>>({})
  const [geocoding, setGeocoding] = useState(false)
  const [geocodedCount, setGeocodedCount] = useState(0)

  // Deals with addresses
  const dealsWithAddr = useMemo(() => deals.filter(d => d.address && d.address.trim()), [deals])

  // Filtered deals
  const filtered = useMemo(() => {
    let d = dealsWithAddr
    if (!statusFilter.has('all')) d = d.filter(x => Array.from(statusFilter).some(f => x.status.includes(f)))
    if (!regionFilter.has('all')) d = d.filter(x => regionFilter.has(getRegion(x.market)))
    if (!brokerFilter.has('all')) d = d.filter(x => brokerFilter.has(getBrokerBucket(x.broker)))
    return d
  }, [dealsWithAddr, statusFilter, regionFilter, brokerFilter])

  // Geocode addresses using Nominatim (free OSM geocoder)
  useEffect(() => {
    const toGeocode = dealsWithAddr.filter(d => d.address && !(d.address in geocodeCache))
    if (toGeocode.length === 0) return

    setGeocoding(true)
    let count = 0

    async function geocodeNext(i: number) {
      if (i >= toGeocode.length) { setGeocoding(false); return }
      const deal = toGeocode[i]
      const addr = deal.address!

      try {
        const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(addr)}&format=json&limit=1&countrycodes=us`
        const res = await fetch(url, { headers: { 'User-Agent': 'SBI-WarRoom/1.0' } })
        const data = await res.json()
        if (data?.[0]) {
          const coords: [number, number] = [parseFloat(data[0].lat), parseFloat(data[0].lon)]
          setGeocodeCache(prev => ({ ...prev, [addr]: coords }))
          count++
          setGeocodedCount(prev => prev + 1)
        } else {
          // Try city fallback
          const cityCoords = CITY_COORDS[deal.market || '']
          setGeocodeCache(prev => ({ ...prev, [addr]: cityCoords || null }))
        }
      } catch {
        setGeocodeCache(prev => ({ ...prev, [addr]: null }))
      }
      // Nominatim rate limit: 1 req/sec
      setTimeout(() => geocodeNext(i + 1), 1100)
    }

    geocodeNext(0)
  }, [dealsWithAddr])

  // Initialize Leaflet map
  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return

    import('leaflet').then(L => {
      leafletRef.current = L

      // Fix default marker icons
      delete (L.Icon.Default.prototype as any)._getIconUrl
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
        iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
        shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
      })

      const map = L.map(mapRef.current!, { zoomControl: true, scrollWheelZoom: true })
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 18,
      }).addTo(map)
      map.setView([33.5, -84.0], 5)
      mapInstanceRef.current = map
    })

    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove()
        mapInstanceRef.current = null
      }
    }
  }, [])

  // Update markers when filtered deals or geocode cache changes
  useEffect(() => {
    const L = leafletRef.current
    const map = mapInstanceRef.current
    if (!L || !map) return

    // Remove old markers
    markersRef.current.forEach(m => m.remove())
    markersRef.current = []

    filtered.forEach(deal => {
      const addr = deal.address!
      const coords = geocodeCache[addr]
      if (!coords) return

      const color = getStatusColor(deal.status)
      const icon = L.divIcon({
        className: '',
        html: `<div style="width:12px;height:12px;border-radius:50%;background:${color};border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,0.4);cursor:pointer;"></div>`,
        iconSize: [12, 12],
        iconAnchor: [6, 6],
      })

      const marker = L.marker(coords, { icon })
        .addTo(map)
        .bindPopup(`
          <div style="font-family:'DM Sans',sans-serif;min-width:200px">
            <div style="font-weight:700;font-size:13px;color:#0D1B2E;margin-bottom:4px">${deal.name}</div>
            <div style="font-size:11px;color:#8A9BB0;margin-bottom:6px">${deal.market ?? ''}</div>
            <div style="font-size:11px;color:#8A9BB0">${addr}</div>
            <div style="display:flex;justify-content:space-between;margin-top:8px;padding-top:6px;border-top:1px solid rgba(13,27,46,0.08)">
              <span style="font-size:11px;font-weight:600;color:${color}">${statusLabel(deal.status)}</span>
              <span style="font-size:11px;color:#8A9BB0">${deal.units ? deal.units.toLocaleString() + ' units' : ''}</span>
            </div>
            <button onclick="window.__openDeal_${deal.name.replace(/[^a-z0-9]/gi,'_')}()" 
              style="margin-top:8px;width:100%;padding:5px;background:#0D1B2E;color:#F0B429;border:none;border-radius:5px;font-size:11px;font-weight:700;cursor:pointer;font-family:'DM Sans',sans-serif">
              Open Deal →
            </button>
          </div>
        `)

      // Register click handler globally for popup button
      const key = `__openDeal_${deal.name.replace(/[^a-z0-9]/gi,'_')}`
      ;(window as any)[key] = () => { map.closePopup(); onOpenDeal(deal) }

      markersRef.current.push(marker)
    })
  }, [filtered, geocodeCache, onOpenDeal])

  function toggleSet(set: Set<string>, val: string, isAll: boolean): Set<string> {
    if (val === 'all') return new Set(['all'])
    const next = new Set(set)
    next.delete('all')
    if (next.has(val)) { next.delete(val); if (next.size === 0) next.add('all') }
    else next.add(val)
    return next
  }

  const chipStyle = (active: boolean, activeColor = '#0D1B2E', activeText = '#F0B429') => ({
    padding: '3px 10px', borderRadius: 16, border: '1px solid',
    borderColor: active ? activeColor : 'rgba(13,27,46,0.12)',
    background: active ? activeColor : '#fff',
    color: active ? activeText : '#8A9BB0',
    fontSize: 10, fontWeight: 600 as const, cursor: 'pointer' as const,
    fontFamily: "'DM Sans',sans-serif",
  })

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Filters */}
      <div style={{ padding: '10px 16px', borderBottom: '1px solid rgba(13,27,46,0.07)', background: '#fafafa', display: 'flex', flexDirection: 'column', gap: 6 }}>
        {/* Status */}
        <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', alignItems: 'center' }}>
          <span style={{ fontSize: 9, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginRight: 4 }}>Status</span>
          {STATUS_FILTERS.map(f => {
            const active = f.value === 'all' ? statusFilter.has('all') : statusFilter.has(f.value)
            const color = f.value === 'all' ? '#0D1B2E' : getStatusColor(f.value + ' New')
            return <button key={f.value} onClick={() => setStatusFilter(toggleSet(statusFilter, f.value, f.value === 'all'))}
              style={{ ...chipStyle(active, color, '#fff'), borderColor: active ? color : 'rgba(13,27,46,0.12)' }}>{f.label}</button>
          })}
        </div>
        {/* Region */}
        <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', alignItems: 'center' }}>
          <span style={{ fontSize: 9, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginRight: 4 }}>Region</span>
          {REGIONS.map(r => {
            const active = r === 'all' ? regionFilter.has('all') : regionFilter.has(r)
            return <button key={r} onClick={() => setRegionFilter(toggleSet(regionFilter, r, r === 'all'))}
              style={{ ...chipStyle(active, '#C9A84C', '#0D1B2E'), borderColor: active ? '#C9A84C' : 'rgba(13,27,46,0.12)' }}>
              {r === 'all' ? 'All Regions' : REGION_DISPLAY[r] || r}
            </button>
          })}
        </div>
        {/* Broker */}
        <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap', alignItems: 'center' }}>
          <span style={{ fontSize: 9, fontWeight: 700, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginRight: 4 }}>Broker</span>
          {BROKER_CHIPS.map(b => {
            const active = b === 'all' ? brokerFilter.has('all') : brokerFilter.has(b)
            return <button key={b} onClick={() => setBrokerFilter(toggleSet(brokerFilter, b, b === 'all'))}
              style={{ ...chipStyle(active, '#2E6B9E', '#fff'), borderColor: active ? '#2E6B9E' : 'rgba(13,27,46,0.12)' }}>
              {b === 'all' ? 'All Brokers' : b}
            </button>
          })}
        </div>
        <div style={{ fontSize: 10, color: '#8A9BB0' }}>
          {filtered.length} deals · {Object.values(geocodeCache).filter(Boolean).length} geocoded
          {geocoding && <span style={{ color: '#E8A020', marginLeft: 8 }}>⟳ Geocoding…</span>}
        </div>
      </div>

      {/* Map */}
      <div style={{ flex: 1, position: 'relative' }}>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css" />
        <div ref={mapRef} style={{ width: '100%', height: '100%' }} />

        {/* Legend */}
        <div style={{ position: 'absolute', bottom: 24, right: 10, zIndex: 1000, background: 'rgba(255,255,255,0.95)', borderRadius: 8, padding: '8px 12px', boxShadow: '0 2px 8px rgba(0,0,0,0.15)', fontSize: 10, fontFamily: "'DM Sans',sans-serif" }}>
          {[['New','#E8A020'],['Active','#2E6B9E'],['Bid Placed','#6B3FA0'],['Passed','#2E7D50'],['Lost','#C0392B'],['Owned','#C9A84C'],['Dormant','#8A9BB0']].map(([label, color]) => (
            <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 3 }}>
              <div style={{ width: 8, height: 8, borderRadius: '50%', background: color, border: '1.5px solid #fff', boxShadow: '0 1px 3px rgba(0,0,0,0.3)' }} />
              <span style={{ color: '#334155' }}>{label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
