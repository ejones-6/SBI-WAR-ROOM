import { type NextRequest, NextResponse } from 'next/server'

const PORTAL_URL = 'https://platform.stonebridgeinvestments.com'

export async function middleware(request: NextRequest) {
  const authCookie = request.cookies.get('sb_auth')

  // If no auth cookie, redirect to the StoneBridge portal to log in
  if (!authCookie?.value) {
    return NextResponse.redirect(PORTAL_URL)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
