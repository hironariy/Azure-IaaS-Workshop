/**
 * Post Model
 * Mongoose schema for blog posts
 * Reference: /design/DatabaseDesign.md
 */

import { randomBytes } from 'node:crypto';
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

const MAX_SLUG_CODE_POINTS = 100;
const FALLBACK_SLUG_BYTES = 6;

export type SlugExistsChecker = (slug: string) => Promise<boolean>;

function trimSlugEdges(slug: string): string {
  return slug.replace(/^-+|-+$/g, '');
}

function truncateSlug(slug: string): string {
  return trimSlugEdges(Array.from(slug).slice(0, MAX_SLUG_CODE_POINTS).join(''));
}

function buildSlugSegment(value: string): string {
  const normalizedValue = value.normalize('NFKC').toLowerCase().trim();
  const slug = normalizedValue
    .replace(/[\s_-]+/gu, '-')
    .replace(/[^\p{L}\p{M}\p{N}-]+/gu, '')
    .replace(/-+/g, '-');

  return truncateSlug(slug);
}

function createFallbackSlug(): string {
  return `post-${randomBytes(FALLBACK_SLUG_BYTES).toString('hex')}`;
}

/**
 * Generates a URL-safe slug that preserves Unicode letters and numbers.
 *
 * Azure workshop learners often test with Japanese, Chinese, or Korean titles.
 * JavaScript's `\w` only keeps ASCII word characters, so this implementation
 * uses Unicode property escapes and code point truncation to avoid corrupting
 * non-ASCII slugs or splitting surrogate pairs.
 *
 * @param title - Post title supplied by the author.
 * @returns A non-empty slug, or a title-independent `post-<id>` fallback.
 */
export function generateSlug(title: string): string {
  const slug = buildSlugSegment(title);

  if (/[\p{L}\p{N}]/u.test(slug)) {
    return slug;
  }

  return createFallbackSlug();
}

/**
 * Applies username-aware collision handling for post slugs.
 *
 * The route first tries the base slug, then `{base}-by-{username}`, then
 * `{base}-by-{username}-{n}`. The existence check is injected so this logic can
 * be unit tested without a MongoDB connection.
 *
 * @param baseSlug - Slug generated from the post title.
 * @param username - Author username used when a title collision occurs.
 * @param slugExists - Async predicate that returns true when a slug is taken.
 * @returns The first available slug following the workshop collision pattern.
 */
export async function generateUniqueSlug(
  baseSlug: string,
  username: string,
  slugExists: SlugExistsChecker
): Promise<string> {
  if (!(await slugExists(baseSlug))) {
    return baseSlug;
  }

  const usernameSlug = buildSlugSegment(username) || 'user';
  let slug = `${baseSlug}-by-${usernameSlug}`;

  if (!(await slugExists(slug))) {
    return slug;
  }

  let counter = 2;
  while (await slugExists(slug)) {
    slug = `${baseSlug}-by-${usernameSlug}-${counter}`;
    counter++;
  }

  return slug;
}

export const Post = mongoose.model<IPost>('Post', postSchema);
