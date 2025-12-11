/**
 * API Service
 * HTTP client for backend API communication
 * Reference: /design/FrontendApplicationDesign.md
 * Auth Requirements: /design/BackendApplicationDesign.md - API Authentication Requirements
 */

import axios, { AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import { msalInstance, msalInitPromise } from '../config/msalInstance';
import { apiRequest } from '../config/authConfig';

/**
 * Authentication mode for API requests
 * Reference: /AIdocs/recommendations/auth-flow-revision-strategy.md
 *
 * - 'required': Must have valid token, throws error if unavailable
 * - 'optional': Include token if available, continue without if not
 * - 'none': Don't attempt token acquisition (public endpoints)
 */
type AuthMode = 'required' | 'optional' | 'none';

// Extend axios config to include our custom authMode property
declare module 'axios' {
  interface AxiosRequestConfig {
    authMode?: AuthMode;
  }
}

// Types
export interface Author {
  _id: string;
  oid?: string;
  displayName: string;
  username: string;
  avatarUrl?: string;
  bio?: string;
}

export interface Post {
  _id: string;
  title: string;
  slug: string;
  content: string;
  excerpt?: string;
  author?: Author;
  status: 'draft' | 'published' | 'archived';
  tags?: string[];
  featuredImageUrl?: string;
  viewCount: number;
  publishedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PostsResponse {
  posts: Post[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface CreatePostData {
  title: string;
  content: string;
  excerpt?: string;
  tags?: string[];
  status?: 'draft' | 'published';
  featuredImageUrl?: string;
}

/**
 * Get access token for API calls
 * Uses the shared MSAL instance to acquire token silently
 *
 * @param mode - Authentication mode (required, optional, none)
 * @returns Access token or null
 * @throws Error if mode is 'required' and no token available
 *
 * For AWS-experienced engineers:
 * - Similar to Auth.currentSession() in Amplify
 * - MSAL handles token caching and refresh automatically
 */
async function getAccessToken(mode: AuthMode = 'optional'): Promise<string | null> {
  // Skip token acquisition for public endpoints
  if (mode === 'none') {
    return null;
  }

  try {
    // Wait for MSAL to be initialized before attempting token acquisition
    await msalInitPromise;

    const accounts = msalInstance.getAllAccounts();
    const activeAccount = msalInstance.getActiveAccount() || accounts[0];

    if (!activeAccount) {
      // User not logged in
      if (mode === 'required') {
        throw new Error('Authentication required - please log in');
      }
      return null;
    }

    try {
      const response = await msalInstance.acquireTokenSilent({
        ...apiRequest,
        account: activeAccount,
      });
      return response.accessToken;
    } catch (silentError) {
      // Handle InteractionRequiredAuthError - need user consent or re-auth
      if (
        silentError instanceof Error &&
        (silentError.name === 'InteractionRequiredAuthError' ||
          silentError.message.includes('AADSTS65001') ||
          silentError.message.includes('interaction_required'))
      ) {
        // Trigger interactive popup for consent
        const response = await msalInstance.acquireTokenPopup({
          ...apiRequest,
          account: activeAccount,
        });
        return response.accessToken;
      }
      throw silentError;
    }
  } catch (error) {
    if (mode === 'required') {
      // Re-throw if authentication was required - let the caller handle the error
      throw error;
    }
    // For optional auth, silently continue without token
    return null;
  }
}

/**
 * Create axios instance with interceptors
 */
function createApiClient(): AxiosInstance {
  const client = axios.create({
    baseURL: import.meta.env.VITE_API_BASE_URL || '',
    timeout: 30000,
    headers: {
      'Content-Type': 'application/json',
    },
  });

  // Request interceptor to add auth token based on authMode
  client.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
      const authMode = config.authMode || 'optional';
      const token = await getAccessToken(authMode);
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    },
    (error) => Promise.reject(error)
  );

  // Response interceptor for error handling
  client.interceptors.response.use(
    (response) => response,
    (error) => {
      if (error.response?.status === 401) {
        // Token expired or invalid - trigger re-auth
        console.warn('Authentication required');
      }
      return Promise.reject(error);
    }
  );

  return client;
}

const api = createApiClient();

// ============================================================================
// API Functions
// Auth requirements based on /design/BackendApplicationDesign.md
// ============================================================================

/**
 * Get list of published posts
 * Auth: Optional - works without auth, includes token if available
 */
export async function getPosts(
  page = 1,
  limit = 10,
  tag?: string,
  author?: string
): Promise<PostsResponse> {
  const params = new URLSearchParams({
    page: String(page),
    limit: String(limit),
  });

  if (tag) params.append('tag', tag);
  if (author) params.append('author', author);

  const response = await api.get<PostsResponse>(`/api/posts?${params}`, {
    authMode: 'optional',
  });
  return response.data;
}

/**
 * Get current user's posts (including drafts)
 * Auth: Required - must be authenticated
 */
export async function getMyPosts(
  page = 1,
  limit = 10,
  status?: 'draft' | 'published' | 'all'
): Promise<PostsResponse> {
  const params = new URLSearchParams({
    page: String(page),
    limit: String(limit),
  });

  if (status) params.append('status', status);

  const response = await api.get<PostsResponse>(`/api/posts/my?${params}`, {
    authMode: 'required',
  });
  return response.data;
}

/**
 * Get single post by slug
 * Auth: Optional - works without auth for published posts, requires auth for drafts
 */
export async function getPost(slug: string): Promise<Post> {
  const response = await api.get<Post>(`/api/posts/${slug}`, {
    authMode: 'optional',
  });
  return response.data;
}

/**
 * Create a new post
 * Auth: Required - must be authenticated
 */
export async function createPost(data: CreatePostData): Promise<Post> {
  const response = await api.post<Post>('/api/posts', data, {
    authMode: 'required',
  });
  return response.data;
}

/**
 * Update a post
 * Auth: Required - must be authenticated and post author
 */
export async function updatePost(slug: string, data: Partial<CreatePostData>): Promise<Post> {
  const response = await api.put<Post>(`/api/posts/${slug}`, data, {
    authMode: 'required',
  });
  return response.data;
}

/**
 * Delete a post
 * Auth: Required - must be authenticated and post author
 */
export async function deletePost(slug: string): Promise<void> {
  await api.delete(`/api/posts/${slug}`, {
    authMode: 'required',
  });
}
