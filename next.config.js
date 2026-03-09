/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['xlsx'],
  },
  // Force webpack to treat these as server-only
  webpack: (config, { isServer }) => {
    if (!isServer) {
      // Prevent server-only modules from being bundled client-side
      config.resolve.alias['@/lib/supabase/server'] = false
    }
    return config
  },
}

module.exports = nextConfig
