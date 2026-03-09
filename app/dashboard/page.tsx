import { createServerSupabaseClient as createClient } from '@/lib/supabase/server'
import WarRoom from '@/components/WarRoom'

export const dynamic = 'force-dynamic'

export default async function DashboardPage() {
  const supabase = createClient()

  // Fetch active pipeline fast — exclude "Passed" (1,800+ deals) on server
  // Full dataset loads client-side after render
  const [
    { data: activeDeals },
    { data: boeData },
    { data: capRates },
    { data: { user } },
  ] = await Promise.all([
    supabase
      .from('deals')
      .select('*')
      .not('status', 'like', '6 -%')
      .order('modified', { ascending: false })
      .limit(300),
    supabase.from('boe_data').select('*'),
    supabase.from('cap_rates').select('*'),
    supabase.auth.getUser(),
  ])

  return (
    <WarRoom
      initialDeals={activeDeals ?? []}
      initialBoeData={boeData ?? []}
      initialCapRates={capRates ?? []}
      userEmail={user?.email ?? ''}
      loadAllDeals={true}
    />
  )
}
