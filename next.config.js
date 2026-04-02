/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: ['xlsx'],
  },
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.alias['@/lib/supabase/server'] = false
    }
    return config
  },
}

module.exports = nextConfig
