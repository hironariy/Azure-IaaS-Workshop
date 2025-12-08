/**
 * Post Model
 * Mongoose schema for blog posts
 * Reference: /design/DatabaseDesign.md
 */

import mongoose, { Document, Schema, Types } from 'mongoose';

export interface IPost extends Document {
  title: string;
  slug: string;
  content: string;
  excerpt?: string;
  author: Types.ObjectId;
  status: 'draft' | 'published' | 'archived';
  tags: string[];
  featuredImageUrl?: string;
  viewCount: number;
  publishedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const postSchema = new Schema<IPost>(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },
    slug: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    content: {
      type: String,
      required: true,
    },
    excerpt: {
      type: String,
      maxlength: 500,
    },
    author: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['draft', 'published', 'archived'],
      default: 'draft',
      index: true,
    },
    tags: [{
      type: String,
      trim: true,
      lowercase: true,
    }],
    featuredImageUrl: {
      type: String,
    },
    viewCount: {
      type: Number,
      default: 0,
    },
    publishedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
    collection: 'posts',
  }
);

// Compound indexes for common queries
postSchema.index({ status: 1, publishedAt: -1 }); // List published posts
postSchema.index({ author: 1, status: 1, createdAt: -1 }); // User's posts
postSchema.index({ tags: 1, status: 1, publishedAt: -1 }); // Posts by tag

// Text index for search
postSchema.index({ title: 'text', content: 'text', tags: 'text' });

/**
 * Generate slug from title
 */
export function generateSlug(title: string): string {
  return title
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, '') // Remove non-word chars
    .replace(/\s+/g, '-') // Replace spaces with -
    .replace(/-+/g, '-') // Replace multiple - with single -
    .substring(0, 100); // Limit length
}

export const Post = mongoose.model<IPost>('Post', postSchema);
