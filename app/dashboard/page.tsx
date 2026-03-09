import { createClient } from '@/lib/supabase/server'
import WarRoom from '@/components/WarRoom'

export const dynamic = 'force-dynamic'

export default async function DashboardPage() {
  const supabase = createClient()

  const [
    { data: deals },
    { data: boeData },
    { data: capRates },
    { data: { user } },
  ] = await Promise.all([
    supabase.from('deals').select('*').order('modified', { ascending: false }),
    supabase.from('boe_data').select('*'),
    supabase.from('cap_rates').select('*'),
    supabase.auth.getUser(),
  ])

  return (
    <WarRoom
      initialDeals={deals ?? []}
      initialBoeData={boeData ?? []}
      initialCapRates={capRates ?? []}
      userEmail={user?.email ?? ''}
    />
  )
}
