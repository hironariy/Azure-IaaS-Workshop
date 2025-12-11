/**
 * Posts Routes
 * CRUD operations for blog posts
 * Reference: /design/BackendApplicationDesign.md
 */

import { Router, Request, Response, NextFunction } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authenticate, optionalAuthenticate } from '../middleware/auth.middleware';
import { ApiError } from '../middleware/error.middleware';
import { Post, generateSlug, User } from '../models';
import { logger } from '../utils/logger';

const router = Router();

/**
 * Validation error handler
 */
function handleValidation(req: Request, _res: Response, next: NextFunction): void {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    next(ApiError.badRequest('Validation failed', { errors: errors.array() }));
    return;
  }
  next();
}

/**
 * GET /api/posts
 * List published posts with pagination
 */
router.get(
  '/',
  optionalAuthenticate,
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
    query('tag').optional().isString().trim(),
    query('author').optional().isString().trim(),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const page = (req.query.page as unknown as number) || 1;
      const limit = (req.query.limit as unknown as number) || 10;
      const skip = (page - 1) * limit;
      const tag = req.query.tag as string | undefined;
      const authorUsername = req.query.author as string | undefined;

      // Build query
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const filter: Record<string, any> = { status: 'published' };

      if (tag) {
        filter.tags = tag.toLowerCase();
      }

      if (authorUsername) {
        const author = await User.findOne({ username: authorUsername });
        if (author) {
          filter.author = author._id;
        } else {
          // No posts for non-existent author
          res.json({ posts: [], total: 0, page, limit });
          return;
        }
      }

      const [posts, total] = await Promise.all([
        Post.find(filter)
          .sort({ publishedAt: -1 })
          .skip(skip)
          .limit(limit)
          .populate('author', 'displayName username avatarUrl')
          .lean(),
        Post.countDocuments(filter),
      ]);

      res.json({
        posts,
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/posts/my
 * List current user's posts (including drafts)
 * Only accessible to authenticated users
 */
router.get(
  '/my',
  authenticate,
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
    query('status').optional().isIn(['draft', 'published', 'all']),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const page = (req.query.page as unknown as number) || 1;
      const limit = (req.query.limit as unknown as number) || 10;
      const skip = (page - 1) * limit;
      const statusFilter = req.query.status as string | undefined;

      // Find user by oid
      const user = await User.findOne({ oid: req.user!.oid });
      if (!user) {
        res.json({ posts: [], total: 0, page, limit, totalPages: 0 });
        return;
      }

      // Build query for user's posts
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const filter: Record<string, any> = { author: user._id };

      if (statusFilter && statusFilter !== 'all') {
        filter.status = statusFilter;
      }

      const [posts, total] = await Promise.all([
        Post.find(filter)
          .sort({ updatedAt: -1 })
          .skip(skip)
          .limit(limit)
          .populate('author', 'displayName username avatarUrl')
          .lean(),
        Post.countDocuments(filter),
      ]);

      res.json({
        posts,
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/posts/:slug
 * Get single post by slug
 */
router.get(
  '/:slug',
  optionalAuthenticate,
  [param('slug').isString().trim()],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const post = await Post.findOne({ slug: req.params.slug })
        .populate('author', 'displayName username avatarUrl bio oid')
        .lean();

      if (!post) {
        next(ApiError.notFound('Post'));
        return;
      }

      // Only show non-published posts to the author
      if (post.status !== 'published') {
        const authorOid = (post.author as unknown as { oid?: string })?.oid;
        if (!req.user || req.user.oid !== authorOid) {
          next(ApiError.notFound('Post'));
          return;
        }
      }

      // Increment view count (fire and forget)
      Post.updateOne({ _id: post._id }, { $inc: { viewCount: 1 } }).catch((err) => {
        logger.error('Failed to increment view count:', err);
      });

      res.json(post);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /api/posts
 * Create a new post (authenticated)
 */
router.post(
  '/',
  authenticate,
  [
    body('title').isString().trim().isLength({ min: 1, max: 200 }),
    body('content').isString().isLength({ min: 1 }),
    body('excerpt').optional().isString().trim().isLength({ max: 500 }),
    body('tags').optional().isArray(),
    body('tags.*').optional().isString().trim(),
    body('status').optional().isIn(['draft', 'published']),
    body('featuredImageUrl').optional().isURL(),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Find or create user from token
      let user = await User.findOne({ oid: req.user!.oid });

      if (!user) {
        // First-time user - create profile
        user = await User.create({
          oid: req.user!.oid,
          email: req.user!.email,
          displayName: req.user!.name,
          username: req.user!.email.split('@')[0].toLowerCase().replace(/[^a-z0-9_-]/g, ''),
        });
      }

      // Generate unique slug with username-aware collision handling
      // 1. Try base slug (from title)
      // 2. If exists → try {base-slug}-by-{username}
      // 3. If still exists → try {base-slug}-by-{username}-{counter}
      const baseSlug = generateSlug(req.body.title);
      let slug = baseSlug;
      let slugExists = await Post.exists({ slug });

      if (slugExists) {
        // Collision - add username
        slug = `${baseSlug}-by-${user.username}`;
        slugExists = await Post.exists({ slug });

        if (slugExists) {
          // Same user has duplicate titles - add counter
          let counter = 2;
          while (slugExists) {
            slug = `${baseSlug}-by-${user.username}-${counter}`;
            slugExists = await Post.exists({ slug });
            counter++;
          }
        }
      }

      const postData = {
        title: req.body.title,
        slug,
        content: req.body.content,
        excerpt: req.body.excerpt,
        author: user._id,
        status: req.body.status ?? 'draft',
        tags: req.body.tags?.map((t: string) => t.toLowerCase()) ?? [],
        featuredImageUrl: req.body.featuredImageUrl,
        publishedAt: req.body.status === 'published' ? new Date() : undefined,
      };

      const post = await Post.create(postData);
      const populatedPost = await Post.findById(post._id)
        .populate('author', 'displayName username avatarUrl')
        .lean();

      logger.info('Post created:', { postId: post._id, author: user._id });

      res.status(201).json(populatedPost);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/posts/:slug
 * Update a post (authenticated, author only)
 */
router.put(
  '/:slug',
  authenticate,
  [
    param('slug').isString().trim(),
    body('title').optional().isString().trim().isLength({ min: 1, max: 200 }),
    body('content').optional().isString().isLength({ min: 1 }),
    body('excerpt').optional().isString().trim().isLength({ max: 500 }),
    body('tags').optional().isArray(),
    body('status').optional().isIn(['draft', 'published', 'archived']),
    body('featuredImageUrl').optional().isURL(),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const post = await Post.findOne({ slug: req.params.slug }).populate('author', 'oid');

      if (!post) {
        next(ApiError.notFound('Post'));
        return;
      }

      // Check ownership
      const authorOid = (post.author as unknown as { oid: string }).oid;
      if (authorOid !== req.user!.oid) {
        next(ApiError.forbidden('You can only edit your own posts'));
        return;
      }

      // Update fields
      if (req.body.title) post.title = req.body.title;
      if (req.body.content) post.content = req.body.content;
      if (req.body.excerpt !== undefined) post.excerpt = req.body.excerpt;
      if (req.body.tags) post.tags = req.body.tags.map((t: string) => t.toLowerCase());
      if (req.body.featuredImageUrl !== undefined) post.featuredImageUrl = req.body.featuredImageUrl;
      if (req.body.status) {
        post.status = req.body.status;
        if (req.body.status === 'published' && !post.publishedAt) {
          post.publishedAt = new Date();
        }
      }

      await post.save();

      const updatedPost = await Post.findById(post._id)
        .populate('author', 'displayName username avatarUrl')
        .lean();

      logger.info('Post updated:', { postId: post._id });

      res.json(updatedPost);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/posts/:slug
 * Delete a post (authenticated, author only)
 */
router.delete(
  '/:slug',
  authenticate,
  [param('slug').isString().trim()],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const post = await Post.findOne({ slug: req.params.slug }).populate('author', 'oid');

      if (!post) {
        next(ApiError.notFound('Post'));
        return;
      }

      // Check ownership
      const authorOid = (post.author as unknown as { oid: string }).oid;
      if (authorOid !== req.user!.oid) {
        next(ApiError.forbidden('You can only delete your own posts'));
        return;
      }

      await Post.deleteOne({ _id: post._id });

      logger.info('Post deleted:', { postId: post._id });

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
);

export default router;
