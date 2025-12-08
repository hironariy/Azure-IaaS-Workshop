/**
 * Environment Configuration
 * Loads and validates environment variables
 * Reference: /design/BackendApplicationDesign.md
 */

import dotenv from 'dotenv';
import path from 'path';

// Load .env file
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

interface EnvironmentConfig {
  nodeEnv: string;
  port: number;
  mongodbUri: string;
  entraTenantId: string;
  entraClientId: string;
  keyVaultName?: string;
  logLevel: string;
  corsOrigins: string[];
  rateLimitWindowMs: number;
  rateLimitMaxRequests: number;
}

function getEnvVar(key: string, defaultValue?: string): string {
  const value = process.env[key] ?? defaultValue;
  if (value === undefined) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

function getEnvVarOptional(key: string): string | undefined {
  return process.env[key];
}

function getEnvVarAsInt(key: string, defaultValue: number): number {
  const value = process.env[key];
  if (value === undefined) {
    return defaultValue;
  }
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) {
    throw new Error(`Environment variable ${key} must be a number`);
  }
  return parsed;
}

export const config: EnvironmentConfig = {
  nodeEnv: getEnvVar('NODE_ENV', 'development'),
  port: getEnvVarAsInt('PORT', 3000),
  mongodbUri: getEnvVar(
    'MONGODB_URI',
    'mongodb://localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0'
  ),
  entraTenantId: getEnvVar('ENTRA_TENANT_ID', 'your-tenant-id'),
  entraClientId: getEnvVar('ENTRA_CLIENT_ID', 'your-client-id'),
  keyVaultName: getEnvVarOptional('KEY_VAULT_NAME'),
  logLevel: getEnvVar('LOG_LEVEL', 'debug'),
  corsOrigins: getEnvVar('CORS_ORIGINS', 'http://localhost:5173,http://localhost:3000').split(','),
  rateLimitWindowMs: getEnvVarAsInt('RATE_LIMIT_WINDOW_MS', 900000),
  rateLimitMaxRequests: getEnvVarAsInt('RATE_LIMIT_MAX_REQUESTS', 100),
};

export const isProduction = (): boolean => config.nodeEnv === 'production';
export const isDevelopment = (): boolean => config.nodeEnv === 'development';
