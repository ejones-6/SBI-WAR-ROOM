import WarRoom from '@/components/WarRoom'

// No server-side data fetching at all — everything is client-side
export default function DashboardPage() {
  return (
    <WarRoom
      initialDeals={[]}
      initialBoeData={[]}
      initialCapRates={[]}
      userEmail=""
      loadAllDeals={true}
    />
  )
}
