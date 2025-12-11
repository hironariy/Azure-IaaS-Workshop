/**
 * Comments Routes
 * Comment management for blog posts
 * Reference: /design/BackendApplicationDesign.md
 */

import { Router, Request, Response, NextFunction } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { authenticate, optionalAuthenticate } from '../middleware/auth.middleware';
import { ApiError } from '../middleware/error.middleware';
import { Comment, Post, User } from '../models';
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
 * GET /api/posts/:slug/comments
 * Get comments for a post
 */
router.get(
  '/posts/:slug/comments',
  optionalAuthenticate,
  [
    param('slug').isString().trim(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const page = (req.query.page as unknown as number) || 1;
      const limit = (req.query.limit as unknown as number) || 20;
      const skip = (page - 1) * limit;

      // Find the post
      const post = await Post.findOne({ slug: req.params.slug, status: 'published' });
      if (!post) {
        next(ApiError.notFound('Post'));
        return;
      }

      // Get comments
      const [comments, total] = await Promise.all([
        Comment.find({ post: post._id, isDeleted: false, parentComment: null })
          .sort({ createdAt: -1 })
          .skip(skip)
          .limit(limit)
          .populate('author', 'displayName username avatarUrl')
          .lean(),
        Comment.countDocuments({ post: post._id, isDeleted: false, parentComment: null }),
      ]);

      res.json({
        comments,
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
 * POST /api/posts/:slug/comments
 * Add a comment to a post (authenticated)
 */
router.post(
  '/posts/:slug/comments',
  authenticate,
  [
    param('slug').isString().trim(),
    body('content').isString().trim().isLength({ min: 1, max: 2000 }),
    body('parentCommentId').optional().isMongoId(),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Find the post
      const post = await Post.findOne({ slug: req.params.slug, status: 'published' });
      if (!post) {
        next(ApiError.notFound('Post'));
        return;
      }

      // Find or create user
      let user = await User.findOne({ oid: req.user!.oid });
      if (!user) {
        user = await User.create({
          oid: req.user!.oid,
          email: req.user!.email,
          displayName: req.user!.name,
          username: req.user!.email.split('@')[0].toLowerCase().replace(/[^a-z0-9_-]/g, ''),
        });
      }

      // Validate parent comment if provided
      if (req.body.parentCommentId) {
        const parentComment = await Comment.findOne({
          _id: req.body.parentCommentId,
          post: post._id,
          isDeleted: false,
        });
        if (!parentComment) {
          next(ApiError.notFound('Parent comment'));
          return;
        }
      }

      const comment = await Comment.create({
        post: post._id,
        author: user._id,
        content: req.body.content,
        parentComment: req.body.parentCommentId || null,
      });

      const populatedComment = await Comment.findById(comment._id)
        .populate('author', 'displayName username avatarUrl')
        .lean();

      logger.info('Comment created:', { commentId: comment._id, postId: post._id });

      res.status(201).json(populatedComment);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/comments/:id
 * Update a comment (authenticated, author only)
 */
router.put(
  '/comments/:id',
  authenticate,
  [
    param('id').isMongoId(),
    body('content').isString().trim().isLength({ min: 1, max: 2000 }),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const comment = await Comment.findById(req.params.id).populate('author', 'oid');

      if (!comment || comment.isDeleted) {
        next(ApiError.notFound('Comment'));
        return;
      }

      // Check ownership
      const authorOid = (comment.author as unknown as { oid: string }).oid;
      if (authorOid !== req.user!.oid) {
        next(ApiError.forbidden('You can only edit your own comments'));
        return;
      }

      comment.content = req.body.content;
      comment.isEdited = true;
      await comment.save();

      const updatedComment = await Comment.findById(comment._id)
        .populate('author', 'displayName username avatarUrl')
        .lean();

      logger.info('Comment updated:', { commentId: comment._id });

      res.json(updatedComment);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/comments/:id
 * Delete a comment (authenticated, author only) - soft delete
 */
router.delete(
  '/comments/:id',
  authenticate,
  [param('id').isMongoId()],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const comment = await Comment.findById(req.params.id).populate('author', 'oid');

      if (!comment || comment.isDeleted) {
        next(ApiError.notFound('Comment'));
        return;
      }

      // Check ownership
      const authorOid = (comment.author as unknown as { oid: string }).oid;
      if (authorOid !== req.user!.oid) {
        next(ApiError.forbidden('You can only delete your own comments'));
        return;
      }

      // Soft delete
      comment.isDeleted = true;
      comment.content = '[deleted]';
      await comment.save();

      logger.info('Comment deleted:', { commentId: comment._id });

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
);

export default router;
