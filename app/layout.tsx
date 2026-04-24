import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'StoneBridge | War Room',
  description: 'StoneBridge Acquisitions War Room',
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: '32x32', type: 'image/x-icon' },
      { url: '/stonebridge_favicon.png', sizes: '512x512', type: 'image/png' },
    ],
    apple: '/stonebridge_favicon.png',
    shortcut: '/favicon.ico',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
