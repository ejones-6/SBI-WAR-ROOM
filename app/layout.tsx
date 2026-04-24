import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'StoneBridge | War Room',
  description: 'StoneBridge Acquisitions War Room',
  icons: {
    icon: '/stonebridge_favicon.jpeg',
    apple: '/stonebridge_favicon.jpeg',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
