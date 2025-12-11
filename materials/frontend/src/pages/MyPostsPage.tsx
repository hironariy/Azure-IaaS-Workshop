/**
 * My Posts Page Component
 * Displays list of current user's posts (including drafts)
 */

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useIsAuthenticated } from '@azure/msal-react';
import { getMyPosts, deletePost, Post } from '../services/api';

function MyPostsPage() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<'all' | 'draft' | 'published'>('all');
  const [deletingSlug, setDeletingSlug] = useState<string | null>(null);
  const isAuthenticated = useIsAuthenticated();

  const fetchPosts = async () => {
    if (!isAuthenticated) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      const data = await getMyPosts(1, 50, statusFilter);
      setPosts(data.posts);
    } catch (err) {
      setError('Failed to load your posts');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPosts();
  }, [isAuthenticated, statusFilter]);

  const handleDelete = async (slug: string, title: string) => {
    if (!confirm(`Are you sure you want to delete "${title}"? This action cannot be undone.`)) {
      return;
    }

    try {
      setDeletingSlug(slug);
      await deletePost(slug);
      // Remove from local state
      setPosts(posts.filter((p) => p.slug !== slug));
    } catch (err) {
      console.error('Failed to delete post:', err);
      alert('Failed to delete post. Please try again.');
    } finally {
      setDeletingSlug(null);
    }
  };

  if (!isAuthenticated) {
    return (
      <div className="rounded-lg bg-yellow-50 p-8 text-center">
        <h2 className="mb-2 text-xl font-semibold text-yellow-800">Login Required</h2>
        <p className="text-yellow-700">Please log in to view your posts.</p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-azure-600 border-t-transparent"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg bg-red-50 p-4 text-center text-red-600">
        {error}
      </div>
    );
  }

  return (
    <div>
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">My Posts</h1>
        <Link to="/posts/new" className="btn-primary">
          Create New Post
        </Link>
      </div>

      {/* Status Filter */}
      <div className="mb-6 flex gap-2">
        <button
          onClick={() => setStatusFilter('all')}
          className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
            statusFilter === 'all'
              ? 'bg-azure-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          }`}
        >
          All
        </button>
        <button
          onClick={() => setStatusFilter('draft')}
          className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
            statusFilter === 'draft'
              ? 'bg-azure-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          }`}
        >
          Drafts
        </button>
        <button
          onClick={() => setStatusFilter('published')}
          className={`rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
            statusFilter === 'published'
              ? 'bg-azure-600 text-white'
              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
          }`}
        >
          Published
        </button>
      </div>

      {posts.length === 0 ? (
        <div className="rounded-lg bg-gray-50 p-8 text-center text-gray-600">
          {statusFilter === 'all'
            ? "You haven't created any posts yet."
            : `No ${statusFilter} posts found.`}
        </div>
      ) : (
        <div className="space-y-4">
          {posts.map((post) => (
            <article
              key={post._id}
              className="card flex items-center justify-between p-4"
            >
              <div className="flex-1">
                <div className="flex items-center gap-3">
                  <Link to={`/posts/${post.slug}`}>
                    <h2 className="text-lg font-semibold text-gray-900 hover:text-azure-600">
                      {post.title}
                    </h2>
                  </Link>
                  <span
                    className={`rounded-full px-2 py-1 text-xs font-medium ${
                      post.status === 'published'
                        ? 'bg-green-100 text-green-800'
                        : 'bg-yellow-100 text-yellow-800'
                    }`}
                  >
                    {post.status}
                  </span>
                </div>
                <div className="mt-1 flex items-center gap-4 text-sm text-gray-500">
                  <span>
                    Updated: {new Date(post.updatedAt).toLocaleDateString()}
                  </span>
                  {post.viewCount !== undefined && (
                    <span>{post.viewCount} views</span>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Link
                  to={`/posts/${post.slug}/edit`}
                  className="rounded-lg bg-gray-100 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200"
                >
                  Edit
                </Link>
                <Link
                  to={`/posts/${post.slug}`}
                  className="rounded-lg bg-azure-100 px-3 py-2 text-sm font-medium text-azure-700 hover:bg-azure-200"
                >
                  View
                </Link>
                <button
                  onClick={() => handleDelete(post.slug, post.title)}
                  disabled={deletingSlug === post.slug}
                  className="rounded-lg bg-red-100 px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-200 disabled:opacity-50"
                >
                  {deletingSlug === post.slug ? 'Deleting...' : 'Delete'}
                </button>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}

export default MyPostsPage;
