/**
 * Single Post Page Component
 */

import { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { useMsal } from '@azure/msal-react';
import { getPost, deletePost, Post } from '../services/api';

function PostPage() {
  const { slug } = useParams<{ slug: string }>();
  const navigate = useNavigate();
  const { accounts } = useMsal();
  const [post, setPost] = useState<Post | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Get current user's OID from MSAL account
  const currentUserOid = accounts[0]?.localAccountId;

  // Check if current user is the author
  const isAuthor = post?.author?.oid && currentUserOid && post.author.oid === currentUserOid;

  useEffect(() => {
    async function fetchPost() {
      if (!slug) return;

      try {
        const data = await getPost(slug);
        setPost(data);
      } catch (err) {
        setError('Post not found');
        console.error(err);
      } finally {
        setLoading(false);
      }
    }

    fetchPost();
  }, [slug]);

  const handleDelete = async () => {
    if (!post || !slug) return;
    
    if (!confirm(`Are you sure you want to delete "${post.title}"? This action cannot be undone.`)) {
      return;
    }

    try {
      setDeleting(true);
      await deletePost(slug);
      navigate('/my-posts');
    } catch (err) {
      console.error('Failed to delete post:', err);
      alert('Failed to delete post. Please try again.');
      setDeleting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-azure-600 border-t-transparent"></div>
      </div>
    );
  }

  if (error || !post) {
    return (
      <div className="text-center">
        <h1 className="mb-4 text-2xl font-bold text-gray-900">Post Not Found</h1>
        <Link to="/" className="link">
          Back to Home
        </Link>
      </div>
    );
  }

  return (
    <article className="mx-auto max-w-3xl">
      <div className="mb-4 flex items-center justify-between">
        <Link to="/" className="text-azure-600 hover:underline">
          ← Back to Posts
        </Link>
        
        {isAuthor && (
          <div className="flex items-center gap-2">
            <Link
              to={`/posts/${post.slug}/edit`}
              className="rounded-lg bg-gray-100 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-200"
            >
              Edit
            </Link>
            <button
              onClick={handleDelete}
              disabled={deleting}
              className="rounded-lg bg-red-100 px-4 py-2 text-sm font-medium text-red-700 hover:bg-red-200 disabled:opacity-50"
            >
              {deleting ? 'Deleting...' : 'Delete'}
            </button>
          </div>
        )}
      </div>

      {/* Draft indicator */}
      {post.status === 'draft' && (
        <div className="mb-4 rounded-lg bg-yellow-50 p-3 text-sm text-yellow-800">
          <strong>Draft</strong> — This post is not published yet and only visible to you.
        </div>
      )}

      {post.featuredImageUrl && (
        <img
          src={post.featuredImageUrl}
          alt={post.title}
          className="mb-6 h-64 w-full rounded-lg object-cover"
        />
      )}

      <h1 className="mb-4 text-4xl font-bold text-gray-900">{post.title}</h1>

      <div className="mb-6 flex items-center space-x-4 text-gray-600">
        <span>By {post.author?.displayName ?? 'Anonymous'}</span>
        <span>•</span>
        <span>{post.publishedAt ? new Date(post.publishedAt).toLocaleDateString() : ''}</span>
        <span>•</span>
        <span>{post.viewCount} views</span>
      </div>

      {post.tags && post.tags.length > 0 && (
        <div className="mb-6 flex flex-wrap gap-2">
          {post.tags.map((tag) => (
            <span
              key={tag}
              className="rounded-full bg-azure-100 px-3 py-1 text-sm text-azure-700"
            >
              {tag}
            </span>
          ))}
        </div>
      )}

      <div className="prose prose-lg max-w-none">
        {/* In production, use a markdown renderer */}
        <div className="whitespace-pre-wrap">{post.content}</div>
      </div>
    </article>
  );
}

export default PostPage;
