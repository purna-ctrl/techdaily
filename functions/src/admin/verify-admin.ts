import { timingSafeEqual } from 'crypto';

/**
 * Verifies `Authorization: Bearer <ADMIN_SECRET>`.
 * SECURITY: when no admin secret is configured, every request is DENIED (fail closed).
 * Returns true when authorized; otherwise writes the error response and returns false.
 */
export function verifyAdmin(req: any, res: any, adminSecret: string | undefined | null): boolean {
  const secret = (adminSecret ?? '').trim();
  if (!secret) {
    res.status(403).json({ error: 'Admin endpoints are disabled: ADMIN_SECRET is not configured on the server.' });
    return false;
  }
  const header = String(req.headers?.authorization || req.headers?.Authorization || '');
  const expected = `Bearer ${secret}`;
  const a = Buffer.from(header);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    res.status(401).json({ error: 'Unauthorized. Valid admin secret required.' });
    return false;
  }
  return true;
}
