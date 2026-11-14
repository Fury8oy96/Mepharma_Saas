import env from '#start/env'

export function getJwtSecret(): string {
  const secret = env.get('JWT_SECRET') || env.get('APP_KEY')
  if (!secret) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL: JWT_SECRET or APP_KEY must be configured in production.')
    }
    return 'mepharma_dev_only_jwt_secret'
  }
  return secret
}

