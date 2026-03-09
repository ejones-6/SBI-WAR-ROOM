import { createServerSupabaseClient as createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import WarRoom from '@/components/WarRoom'

export const dynamic = 'force-dynamic'

export default async function DashboardPage() {
  // Only verify auth server-side — all data loads client-side
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  return (
    <WarRoom
      initialDeals={[]}
      initialBoeData={[]}
      initialCapRates={[]}
      userEmail={user.email ?? ''}
      loadAllDeals={true}
    />
  )
}
