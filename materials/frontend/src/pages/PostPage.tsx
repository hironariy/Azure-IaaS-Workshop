/**
 * Single Post Page Component
 */

import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getPost, Post } from '../services/api';

function PostPage() {
  const { slug } = useParams<{ slug: string }>();
  const [post, setPost] = useState<Post | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
      <Link to="/" className="mb-4 inline-block text-azure-600 hover:underline">
        ← Back to Posts
      </Link>

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
