import { NextResponse } from 'next/server'

export const revalidate = 3600 // cache 1 hour

export async function GET() {
  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY!,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': 'web-search-2025-03-05',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1500,
        tools: [{ type: 'web_search_20250305', name: 'web_search' }],
        messages: [{
          role: 'user',
          content: `Search multihousingnews.com for the 3 most recent articles about multifamily real estate acquisitions, investment, or cap rates published in the last 2 weeks. For each article return ONLY a JSON array with this exact structure, no other text:
[
  {
    "title": "exact article title",
    "url": "full article URL from multihousingnews.com",
    "date": "Mar 11, 2026",
    "summary": "1-2 sentence summary of the article relevant to multifamily acquisitions investors"
  }
]
Return ONLY the JSON array, no markdown, no explanation.`
        }],
      }),
    })

    const data = await response.json()

    // Extract text from response
    const textBlock = data.content?.find((b: any) => b.type === 'text')
    if (!textBlock?.text) throw new Error('No text in response')

    // Parse JSON from response
    const text = textBlock.text.trim()
    const jsonMatch = text.match(/\[[\s\S]*\]/)
    if (!jsonMatch) throw new Error('No JSON array found')

    const articles = JSON.parse(jsonMatch[0])

    // Validate structure
    const validated = articles.slice(0, 3).map((a: any) => ({
      title: String(a.title || ''),
      url: String(a.url || 'https://www.multihousingnews.com'),
      date: String(a.date || ''),
      summary: String(a.summary || ''),
    })).filter((a: any) => a.title && a.url)

    return NextResponse.json(validated, {
      headers: { 'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=600' }
    })
  } catch (err) {
    console.error('MHN news error:', err)
    // Return fallback so the UI doesn't break
    return NextResponse.json([
      {
        title: 'Visit Multihousing News for Latest Coverage',
        url: 'https://www.multihousingnews.com',
        date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
        summary: 'Stay current on multifamily acquisitions, cap rates, and market trends at multihousingnews.com.'
      }
    ])
  }
}
