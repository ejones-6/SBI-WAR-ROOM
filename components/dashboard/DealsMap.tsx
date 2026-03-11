'use client'
import type { Deal } from '@/lib/types'

interface Props {
  deals: Deal[]
  onOpenDeal: (d: Deal) => void
}

export default function DealsMap({ deals, onOpenDeal }: Props) {
  return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 12, color: '#8A9BB0' }}>
      <div style={{ fontSize: 32 }}>🗺️</div>
      <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 18, fontWeight: 700, color: '#0D1B2E' }}>Market Map</div>
      <div style={{ fontSize: 13 }}>Coming soon</div>
    </div>
  )
}
