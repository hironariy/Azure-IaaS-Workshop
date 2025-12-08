/**
 * User Model
 * Mongoose schema for blog application users
 * Reference: /design/DatabaseDesign.md
 */

import mongoose, { Document, Schema } from 'mongoose';

export interface IUser extends Document {
  oid: string; // Microsoft Entra ID Object ID
  email: string;
  displayName: string;
  username: string;
  bio?: string;
  avatarUrl?: string;
  isActive: boolean;
  role: 'user' | 'admin';
  lastLoginAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    oid: {
      type: String,
      required: true,
      unique: true,
      index: true,
      description: 'Microsoft Entra ID Object ID',
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    displayName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    username: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      minlength: 3,
      maxlength: 30,
      match: /^[a-z0-9_-]+$/,
      index: true,
    },
    bio: {
      type: String,
      maxlength: 500,
    },
    avatarUrl: {
      type: String,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    role: {
      type: String,
      enum: ['user', 'admin'],
      default: 'user',
    },
    lastLoginAt: {
      type: Date,
    },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt
    collection: 'users',
  }
);

// Compound index for listing active users
userSchema.index({ isActive: 1, createdAt: -1 });

export const User = mongoose.model<IUser>('User', userSchema);
