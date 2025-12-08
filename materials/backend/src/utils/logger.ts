/**
 * Winston Logger Configuration
 * Structured JSON logging for production
 * Reference: /design/RepositoryWideDesignRules.md - Section 1.4 (Log Sanitization)
 */

import winston from 'winston';
import { config } from '../config/environment';

// Custom format for development (human-readable)
const devFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.colorize(),
  winston.format.printf(({ level, message, timestamp, ...meta }) => {
    const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
    return `${timestamp} [${level}]: ${message} ${metaStr}`;
  })
);

// Custom format for production (JSON)
const prodFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.json()
);

export const logger = winston.createLogger({
  level: config.logLevel,
  format: config.nodeEnv === 'production' ? prodFormat : devFormat,
  defaultMeta: { service: 'blogapp-api' },
  transports: [
    new winston.transports.Console(),
  ],
});

/**
 * Sanitize sensitive data from logs
 * Reference: /design/RepositoryWideDesignRules.md - Section 1.4
 */
export function sanitizeForLog(data: Record<string, unknown>): Record<string, unknown> {
  const sensitiveKeys = ['password', 'token', 'authorization', 'cookie', 'secret', 'key', 'apiKey'];
  const sanitized = { ...data };

  for (const key of Object.keys(sanitized)) {
    if (sensitiveKeys.some((sk) => key.toLowerCase().includes(sk))) {
      sanitized[key] = '***REDACTED***';
    }
  }

  return sanitized;
}

/**
 * Sanitize email for logging (u***@example.com)
 */
export function sanitizeEmail(email: string): string {
  const [local, domain] = email.split('@');
  if (!local || !domain) return '***@***.***';
  return `${local.charAt(0)}***@${domain}`;
}

/**
 * Sanitize MongoDB connection string
 */
export function sanitizeConnectionString(uri: string): string {
  return uri.replace(/mongodb:\/\/([^:]+):([^@]+)@/, 'mongodb://***:***@');
}
