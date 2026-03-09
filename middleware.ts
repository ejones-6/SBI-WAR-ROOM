import { type NextRequest, NextResponse } from 'next/server'

// Auth handled client-side in WarRoom.tsx for performance
// Middleware only passes through
export async function middleware(request: NextRequest) {
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
