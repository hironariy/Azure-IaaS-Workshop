/**
 * Database Configuration
 * MongoDB connection with Mongoose
 * Reference: /design/DatabaseDesign.md
 */

import mongoose from 'mongoose';
import { config } from './environment';
import { logger } from '../utils/logger';

/**
 * Connect to MongoDB replica set
 * Handles connection events and retries
 */
export async function connectDatabase(): Promise<void> {
  try {
    // Sanitize connection string for logging (hide credentials if any)
    const sanitizedUri = config.mongodbUri.replace(
      /mongodb:\/\/([^:]+):([^@]+)@/,
      'mongodb://***:***@'
    );
    logger.info(`Connecting to MongoDB: ${sanitizedUri}`);

    // Mongoose connection options
    const options: mongoose.ConnectOptions = {
      // Replica set options are inferred from URI
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    };

    await mongoose.connect(config.mongodbUri, options);

    logger.info('✅ Connected to MongoDB replica set');

    // Connection event handlers
    mongoose.connection.on('error', (err) => {
      logger.error('MongoDB connection error:', err);
    });

    mongoose.connection.on('disconnected', () => {
      logger.warn('MongoDB disconnected. Attempting to reconnect...');
    });

    mongoose.connection.on('reconnected', () => {
      logger.info('MongoDB reconnected');
    });
  } catch (error) {
    logger.error('Failed to connect to MongoDB:', error);
    throw error;
  }
}

/**
 * Disconnect from MongoDB
 * Use during graceful shutdown
 */
export async function disconnectDatabase(): Promise<void> {
  try {
    await mongoose.disconnect();
    logger.info('Disconnected from MongoDB');
  } catch (error) {
    logger.error('Error disconnecting from MongoDB:', error);
    throw error;
  }
}

/**
 * Check database connection health
 * Used by health check endpoint
 */
export function isDatabaseConnected(): boolean {
  return mongoose.connection.readyState === 1;
}

/**
 * Get database connection state as string
 */
export function getDatabaseState(): string {
  const states: Record<number, string> = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  };
  return states[mongoose.connection.readyState] ?? 'unknown';
}
