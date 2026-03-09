import { createBrowserClient } from '@supabase/ssr'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? 'https://basvpojiaycrrbalivrz.supabase.co'
const SUPABASE_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? 'sb_publishable_cYyun0vpOqDGdZqAqJgGMw_Px6VHf-x'

export function createClient() {
  return createBrowserClient(SUPABASE_URL, SUPABASE_KEY)
}
