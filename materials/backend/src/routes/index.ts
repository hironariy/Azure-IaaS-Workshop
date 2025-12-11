/**
 * Routes Index
 * Central route configuration
 */

import { Router } from 'express';
import healthRoutes from './health.routes';
import postsRoutes from './posts.routes';
import usersRoutes from './users.routes';
import commentsRoutes from './comments.routes';

const router = Router();

// Health check routes (no /api prefix)
router.use('/', healthRoutes);

// API routes
router.use('/api/posts', postsRoutes);
router.use('/api/users', usersRoutes);
router.use('/api', commentsRoutes); // Comments have mixed paths

export default router;
