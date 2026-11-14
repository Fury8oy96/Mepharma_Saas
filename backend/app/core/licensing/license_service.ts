import crypto from 'node:crypto'
import env from '#start/env'

export interface LicensePayload {
  tenantId: number
  tenantCode: string
  plan: 'starter' | 'professional' | 'enterprise'
  maxTerminals: number
  maxUsers: number
  enabledModules: string[]
  issuedAt: string
  expiresAt: string
  gracePeriodDays: number
}

export class LicenseService {
  private static getSecret(): string {
    const secret = env.get('LICENSE_SECRET') || env.get('APP_KEY')
    if (!secret) {
      if (process.env.NODE_ENV === 'production') {
        throw new Error('CRITICAL: LICENSE_SECRET or APP_KEY must be configured in production.')
      }
      return 'mepharma_dev_only_license_secret'
    }
    return secret
  }

  /**
   * Generates a cryptographically signed license key string for a tenant.
   */
  static generateLicenseToken(payload: LicensePayload): string {
    const json = JSON.stringify(payload)
    const base64Data = Buffer.from(json).toString('base64url')
    const signature = crypto
      .createHmac('sha256', this.getSecret())
      .update(base64Data)
      .digest('hex')
    return `LIC-${base64Data}.${signature}`
  }

  /**
   * Verifies a license token using constant-time HMAC comparison and validates expiration.
   */
  static verifyLicenseToken(token: string): { valid: boolean; payload?: LicensePayload; error?: string } {
    if (!token || !token.startsWith('LIC-')) {
      return { valid: false, error: 'Invalid license format.' }
    }

    const raw = token.slice(4)
    const [base64Data, signature] = raw.split('.')
    if (!base64Data || !signature) {
      return { valid: false, error: 'Malformed license token.' }
    }

    const expectedSig = crypto
      .createHmac('sha256', this.getSecret())
      .update(base64Data)
      .digest('hex')

    const sigBuf = Buffer.from(signature, 'utf8')
    const expectedBuf = Buffer.from(expectedSig, 'utf8')
    if (sigBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(sigBuf, expectedBuf)) {
      return { valid: false, error: 'License cryptographic signature is invalid or tampered with.' }
    }

    try {
      const json = Buffer.from(base64Data, 'base64url').toString('utf8')
      const payload = JSON.parse(json) as LicensePayload

      const expiry = new Date(payload.expiresAt).getTime()
      const gracePeriodMs = (payload.gracePeriodDays || 7) * 24 * 60 * 60 * 1000
      const now = Date.now()

      if (Number.isNaN(expiry) || now > expiry + gracePeriodMs) {
        return { valid: false, payload, error: 'License has expired and grace period ended.' }
      }

      return { valid: true, payload }
    } catch {
      return { valid: false, error: 'Failed to decode license payload.' }
    }
  }
}
