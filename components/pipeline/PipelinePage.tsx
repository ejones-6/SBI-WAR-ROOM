'use client'
import type { Deal } from '@/lib/types'
import { fmtShort, statusLabel, statusClass } from '@/lib/utils'

interface Props {
  deals: Deal[]
  onOpenDeal: (d: Deal) => void
  onSaveDeal: (updates: Partial<Deal> & { name: string }) => Promise<any>
}

const PIPELINE_STATUSES = ['1 - New', '2 - Active', '5 - Dormant', '7 - Lost']

const STATUS_COLORS: Record<string, string> = {
  '1 - New': '#2E7D50',
  '2 - Active': '#1565A0',
  '5 - Dormant': '#8A7A3A',
  '7 - Lost': '#C0392B',
}

export default function PipelinePage({ deals, onOpenDeal, onSaveDeal }: Props) {
  const columns = PIPELINE_STATUSES.map(status => ({
    status,
    label: statusLabel(status),
    color: STATUS_COLORS[status] ?? '#8A9BB0',
    deals: deals.filter(d => d.status === status || d.status.startsWith(status.split(' - ')[0] + ' -')).slice(0, 30),
  }))

  return (
    <div style={{ padding: '24px 28px', height: '100%' }}>
      <div style={{ display: 'grid', gridTemplateColumns: `repeat(${PIPELINE_STATUSES.length}, 1fr)`, gap: 14, height: 'calc(100vh - 130px)', overflowX: 'auto' }}>
        {columns.map(col => (
          <div key={col.status} style={{ display: 'flex', flexDirection: 'column', minWidth: 240 }}>
            {/* Column header */}
            <div style={{ padding: '10px 14px', borderRadius: 10, marginBottom: 10, background: col.color, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 11, fontWeight: 700, color: '#fff', letterSpacing: '0.08em', textTransform: 'uppercase' }}>{col.label}</span>
              <span style={{ background: 'rgba(255,255,255,0.2)', color: '#fff', borderRadius: 10, padding: '1px 8px', fontSize: 11, fontWeight: 700 }}>{col.deals.length}</span>
            </div>
            {/* Cards */}
            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 8 }}>
              {col.deals.map(deal => (
                <div key={deal.id} onClick={() => onOpenDeal(deal)}
                  style={{ background: '#fff', borderRadius: 8, padding: '12px 14px', border: '1px solid rgba(13,27,46,0.07)', cursor: 'pointer', transition: 'all .12s' }}
                  onMouseEnter={e => { (e.currentTarget as HTMLDivElement).style.boxShadow = '0 4px 16px rgba(13,27,46,0.1)'; (e.currentTarget as HTMLDivElement).style.transform = 'translateY(-1px)' }}
                  onMouseLeave={e => { (e.currentTarget as HTMLDivElement).style.boxShadow = ''; (e.currentTarget as HTMLDivElement).style.transform = '' }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#0D1B2E', marginBottom: 3, lineHeight: 1.3 }}>{deal.name}</div>
                  <div style={{ fontSize: 11, color: '#8A9BB0', marginBottom: 6 }}>{deal.market}</div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: 12, fontWeight: 600, color: '#0D1B2E' }}>{fmtShort(deal.purchase_price)}</span>
                    {deal.units && <span style={{ fontSize: 10, color: '#8A9BB0' }}>{deal.units} units</span>}
                  </div>
                  {deal.bid_due_date && (
                    <div style={{ marginTop: 6, padding: '3px 8px', background: 'rgba(240,180,41,0.08)', borderRadius: 4, fontSize: 10, color: '#8A6500', fontWeight: 600 }}>
                      Bid: {deal.bid_due_date}
                    </div>
                  )}
                  {deal.broker && (
                    <div style={{ marginTop: 4, fontSize: 10, color: '#8A9BB0' }}>{deal.broker}</div>
                  )}
                </div>
              ))}
              {col.deals.length === 0 && (
                <div style={{ textAlign: 'center', padding: '24px 0', color: '#8A9BB0', fontSize: 12 }}>No deals</div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
