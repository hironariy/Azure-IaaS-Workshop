/**
 * Authentication Middleware
 * JWT validation for Microsoft Entra ID tokens
 * Reference: /design/BackendApplicationDesign.md - Authentication section
 */

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import { config } from '../config/environment';
import { logger } from '../utils/logger';
import { ApiError } from './error.middleware';

// Extend Express Request to include user info
declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

/**
 * Authenticated user information extracted from JWT
 */
export interface AuthenticatedUser {
  oid: string; // Object ID (unique user identifier)
  sub: string; // Subject
  name: string;
  email: string;
  preferredUsername: string;
  roles?: string[];
}

// JWKS client for fetching Microsoft signing keys
const client = jwksClient({
  jwksUri: `https://login.microsoftonline.com/${config.entraTenantId}/discovery/v2.0/keys`,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
  rateLimit: true,
  jwksRequestsPerMinute: 10,
});

/**
 * Get signing key from JWKS
 */
function getSigningKey(header: jwt.JwtHeader): Promise<string> {
  return new Promise((resolve, reject) => {
    if (!header.kid) {
      reject(new Error('No kid in token header'));
      return;
    }

    client.getSigningKey(header.kid, (err, key) => {
      if (err) {
        reject(err);
        return;
      }
      if (!key) {
        reject(new Error('Signing key not found'));
        return;
      }
      const signingKey = key.getPublicKey();
      resolve(signingKey);
    });
  });
}

/**
 * Validate JWT token from Authorization header
 */
async function validateToken(token: string): Promise<AuthenticatedUser> {
  // Decode header to get kid
  const decoded = jwt.decode(token, { complete: true });
  if (!decoded || typeof decoded === 'string') {
    throw new Error('Invalid token format');
  }

  // Get signing key
  const signingKey = await getSigningKey(decoded.header);

  // Verify token
  // The audience can be either the client ID or the API URI (api://<client-id>)
  // Accept both v1.0 (sts.windows.net) and v2.0 (login.microsoftonline.com/.../v2.0) issuers
  // to support different Entra ID app registration configurations
  const validIssuers: [string, ...string[]] = [
    `https://login.microsoftonline.com/${config.entraTenantId}/v2.0`,
    `https://sts.windows.net/${config.entraTenantId}/`,
  ];

  const payload = jwt.verify(token, signingKey, {
    algorithms: ['RS256'],
    audience: [config.entraClientId, `api://${config.entraClientId}`],
    issuer: validIssuers,
  }) as jwt.JwtPayload;

  // Extract user info from token
  // v1.0 tokens use 'upn' and 'unique_name', v2.0 uses 'preferred_username' and 'email'
  const email = (payload.email as string) 
    ?? (payload.preferred_username as string) 
    ?? (payload.upn as string)
    ?? (payload.unique_name as string)
    ?? '';
  
  return {
    oid: payload.oid as string,
    sub: payload.sub as string,
    name: (payload.name as string) ?? 'Unknown',
    email,
    preferredUsername: (payload.preferred_username as string) ?? (payload.upn as string) ?? '',
    roles: payload.roles as string[] | undefined,
  };
}

/**
 * Authentication middleware
 * Requires valid JWT in Authorization header
 */
export async function authenticate(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      throw ApiError.unauthorized('No authorization header');
    }

    if (!authHeader.startsWith('Bearer ')) {
      throw ApiError.unauthorized('Invalid authorization format');
    }

    const token = authHeader.substring(7);

    if (!token) {
      throw ApiError.unauthorized('No token provided');
    }

    // Validate token and extract user
    const user = await validateToken(token);
    req.user = user;

    logger.debug('User authenticated:', { oid: user.oid, name: user.name });
    next();
  } catch (error) {
    if (error instanceof ApiError) {
      next(error);
    } else if (error instanceof jwt.TokenExpiredError) {
      next(ApiError.unauthorized('Token expired'));
    } else if (error instanceof jwt.JsonWebTokenError) {
      next(ApiError.unauthorized('Invalid token'));
    } else {
      logger.error('Authentication error:', error);
      next(ApiError.unauthorized('Authentication failed'));
    }
  }
}

/**
 * Optional authentication middleware
 * Attaches user if token is valid, continues without user if no token
 */
export async function optionalAuthenticate(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // No token - continue without user
      next();
      return;
    }

    const token = authHeader.substring(7);
    if (token) {
      const user = await validateToken(token);
      req.user = user;
    }

    next();
  } catch {
    // Token invalid - continue without user for optional authentication
    next();
  }
}
