/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['xlsx', 'yahoo-finance2'],
  },
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.alias['@/lib/supabase/server'] = false
    }
    // Ignore yahoo-finance2 test files that pull in Deno deps
    config.resolve.alias['@std/testing/mock'] = false
    config.resolve.alias['@std/testing/bdd'] = false
    config.resolve.alias['@gadicc/fetch-mock-cache/runtimes/deno.ts'] = false
    config.resolve.alias['@gadicc/fetch-mock-cache/stores/fs.ts'] = false
    return config
  },
}

module.exports = nextConfig
