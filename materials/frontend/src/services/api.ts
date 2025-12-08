/**
 * API Service
 * HTTP client for backend API communication
 * Reference: /design/FrontendApplicationDesign.md
 */

import axios, { AxiosInstance } from 'axios';
import { PublicClientApplication } from '@azure/msal-browser';
import { msalConfig, apiRequest } from '../config/authConfig';

// Types
export interface Author {
  _id: string;
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

// MSAL instance for acquiring tokens
let msalInstance: PublicClientApplication | null = null;

function getMsalInstance(): PublicClientApplication {
  if (!msalInstance) {
    msalInstance = new PublicClientApplication(msalConfig);
  }
  return msalInstance;
}

/**
 * Get access token for API calls
 * Uses MSAL to acquire token silently or via redirect
 */
async function getAccessToken(): Promise<string | null> {
  try {
    const msal = getMsalInstance();
    const accounts = msal.getAllAccounts();

    if (accounts.length === 0) {
      return null;
    }

    const response = await msal.acquireTokenSilent({
      ...apiRequest,
      account: accounts[0],
    });

    return response.accessToken;
  } catch (error) {
    console.error('Failed to acquire token:', error);
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

  // Request interceptor to add auth token
  client.interceptors.request.use(
    async (config) => {
      const token = await getAccessToken();
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

// API Functions

/**
 * Get list of published posts
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

  const response = await api.get<PostsResponse>(`/api/posts?${params}`);
  return response.data;
}

/**
 * Get single post by slug
 */
export async function getPost(slug: string): Promise<Post> {
  const response = await api.get<Post>(`/api/posts/${slug}`);
  return response.data;
}

/**
 * Create a new post (requires authentication)
 */
export async function createPost(data: CreatePostData): Promise<Post> {
  const response = await api.post<Post>('/api/posts', data);
  return response.data;
}

/**
 * Update a post (requires authentication, author only)
 */
export async function updatePost(slug: string, data: Partial<CreatePostData>): Promise<Post> {
  const response = await api.put<Post>(`/api/posts/${slug}`, data);
  return response.data;
}

/**
 * Delete a post (requires authentication, author only)
 */
export async function deletePost(slug: string): Promise<void> {
  await api.delete(`/api/posts/${slug}`);
}
