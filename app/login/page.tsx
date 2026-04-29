'use client'
import { useEffect } from 'react'

// Auth is handled by the StoneBridge portal via MSAL
// This page should never be reached — middleware redirects unauthenticated users
// If somehow reached, send them to the portal
export default function LoginPage() {
  useEffect(() => {
    window.location.href = 'https://platform.stonebridgeinvestments.com'
  }, [])
  return null
}
