/**
 * Routes Index
 * Central route configuration
 */

import { Router } from 'express';
import healthRoutes from './health.routes';
import postsRoutes from './posts.routes';

const router = Router();

// Health check routes (no /api prefix)
router.use('/', healthRoutes);

// API routes
router.use('/api/posts', postsRoutes);

// TODO: Add more routes as needed
// router.use('/api/users', usersRoutes);
// router.use('/api/comments', commentsRoutes);

export default router;
