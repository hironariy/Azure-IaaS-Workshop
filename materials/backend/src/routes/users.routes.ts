/**
 * Users Routes
 * User profile management
 * Reference: /design/BackendApplicationDesign.md
 */

import { Router, Request, Response, NextFunction } from 'express';
import { body, param, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.middleware';
import { ApiError } from '../middleware/error.middleware';
import { User } from '../models';
import { logger, sanitizeEmail } from '../utils/logger';
import { sanitizePlain } from '../utils/sanitize';

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
 * GET /api/users/me
 * Get current authenticated user's profile
 */
router.get(
  '/me',
  authenticate,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const existingUser = await User.findOne({ oid: req.user!.oid }).lean();

      if (!existingUser) {
        // First-time user - create profile from token info
        const newUser = await User.create({
          oid: req.user!.oid,
          email: req.user!.email,
          displayName: sanitizePlain(req.user!.name),
          username: req.user!.email.split('@')[0].toLowerCase().replace(/[^a-z0-9_-]/g, ''),
          lastLoginAt: new Date(),
        });
        logger.info('New user created:', { oid: req.user!.oid, email: sanitizeEmail(req.user!.email) });
        res.json(newUser.toObject());
        return;
      }

      // Update last login
      await User.updateOne({ oid: req.user!.oid }, { lastLoginAt: new Date() });
      res.json(existingUser);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * GET /api/users/:username
 * Get user by username (public profile)
 */
router.get(
  '/:username',
  [param('username').isString().trim().isLength({ min: 3, max: 30 })],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const user = await User.findOne({
        username: req.params.username,
        isActive: true,
      })
        .select('displayName username bio avatarUrl createdAt')
        .lean();

      if (!user) {
        next(ApiError.notFound('User'));
        return;
      }

      res.json(user);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * PUT /api/users/me
 * Update current user's profile
 */
router.put(
  '/me',
  authenticate,
  [
    body('displayName').optional().isString().trim().isLength({ min: 1, max: 100 }),
    body('bio').optional().isString().trim().isLength({ max: 500 }),
    body('avatarUrl').optional().isURL(),
  ],
  handleValidation,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const updates: Record<string, unknown> = {};

      if (req.body.displayName) updates.displayName = sanitizePlain(req.body.displayName);
      if (req.body.bio !== undefined) updates.bio = sanitizePlain(req.body.bio);
      if (req.body.avatarUrl !== undefined) updates.avatarUrl = req.body.avatarUrl;

      const user = await User.findOneAndUpdate(
        { oid: req.user!.oid },
        { $set: updates },
        { new: true, runValidators: true }
      ).lean();

      if (!user) {
        next(ApiError.notFound('User'));
        return;
      }

      logger.info('User profile updated:', { oid: req.user!.oid });

      res.json(user);
    } catch (error) {
      next(error);
    }
  }
);

export default router;
