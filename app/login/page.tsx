'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError('')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      setError(error.message)
      setLoading(false)
    } else {
      router.push('/dashboard')
      router.refresh()
    }
  }

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'linear-gradient(135deg, #0D1B2E 0%, #152540 60%, #1a2f50 100%)',
      fontFamily: "'DM Sans', sans-serif"
    }}>
      <div style={{
        background: '#fff', borderRadius: 16, padding: '48px 44px', width: 400,
        boxShadow: '0 24px 80px rgba(0,0,0,0.35)'
      }}>
        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: 36 }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            width: 56, height: 56, borderRadius: 14,
            background: 'linear-gradient(135deg,#0D1B2E,#1e3a5f)', marginBottom: 16
          }}>
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#C9A84C" strokeWidth="1.8">
              <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
              <polyline points="9 22 9 12 15 12 15 22"/>
            </svg>
          </div>
          <div style={{ fontFamily: "'Cormorant Garamond',serif", fontSize: 22, fontWeight: 700, color: '#0D1B2E', letterSpacing: '0.04em' }}>
            STONEBRIDGE
          </div>
          <div style={{ fontSize: 11, color: '#8A9BB0', fontWeight: 600, letterSpacing: '0.18em', textTransform: 'uppercase', marginTop: 2 }}>
            Acquisitions War Room
          </div>
        </div>

        <form onSubmit={handleLogin}>
          <div style={{ marginBottom: 18 }}>
            <label style={{ display: 'block', fontSize: 11, fontWeight: 600, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 6 }}>
              Email
            </label>
            <input
              type="email" value={email} onChange={e => setEmail(e.target.value)} required
              style={{ width: '100%', padding: '10px 14px', border: '1.5px solid rgba(13,27,46,0.15)', borderRadius: 8, fontSize: 14, fontFamily: "'DM Sans',sans-serif", outline: 'none', color: '#0D1B2E' }}
              onFocus={e => e.target.style.borderColor = '#C9A84C'}
              onBlur={e => e.target.style.borderColor = 'rgba(13,27,46,0.15)'}
            />
          </div>
          <div style={{ marginBottom: 24 }}>
            <label style={{ display: 'block', fontSize: 11, fontWeight: 600, color: '#8A9BB0', letterSpacing: '0.1em', textTransform: 'uppercase', marginBottom: 6 }}>
              Password
            </label>
            <input
              type="password" value={password} onChange={e => setPassword(e.target.value)} required
              style={{ width: '100%', padding: '10px 14px', border: '1.5px solid rgba(13,27,46,0.15)', borderRadius: 8, fontSize: 14, fontFamily: "'DM Sans',sans-serif", outline: 'none', color: '#0D1B2E' }}
              onFocus={e => e.target.style.borderColor = '#C9A84C'}
              onBlur={e => e.target.style.borderColor = 'rgba(13,27,46,0.15)'}
            />
          </div>

          {error && (
            <div style={{ background: 'rgba(192,57,43,0.08)', border: '1px solid rgba(192,57,43,0.2)', borderRadius: 8, padding: '10px 14px', marginBottom: 18, fontSize: 13, color: '#C0392B' }}>
              {error}
            </div>
          )}

          <button type="submit" disabled={loading} style={{
            width: '100%', padding: '12px', background: loading ? '#8A9BB0' : 'linear-gradient(135deg,#0D1B2E,#1e3a5f)',
            color: '#C9A84C', border: 'none', borderRadius: 8, fontSize: 13, fontWeight: 700,
            letterSpacing: '0.12em', textTransform: 'uppercase', cursor: loading ? 'not-allowed' : 'pointer',
            fontFamily: "'DM Sans',sans-serif", transition: 'opacity .15s'
          }}>
            {loading ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  )
}
