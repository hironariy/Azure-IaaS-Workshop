/**
 * Home Page Component
 * Displays list of blog posts
 */

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { getPosts, Post } from '../services/api';

function HomePage() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchPosts() {
      try {
        const data = await getPosts();
        setPosts(data.posts);
      } catch (err) {
        setError('Failed to load posts');
        console.error(err);
      } finally {
        setLoading(false);
      }
    }

    fetchPosts();
  }, []);

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
      <h1 className="mb-8 text-3xl font-bold text-gray-900">Recent Posts</h1>

      {posts.length === 0 ? (
        <div className="rounded-lg bg-gray-50 p-8 text-center text-gray-600">
          No posts yet. Be the first to write one!
        </div>
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {posts.map((post) => (
            <article key={post._id} className="card overflow-hidden">
              {post.featuredImageUrl && (
                <img
                  src={post.featuredImageUrl}
                  alt={post.title}
                  className="h-48 w-full object-cover"
                />
              )}
              <div className="p-6">
                <Link to={`/posts/${post.slug}`}>
                  <h2 className="mb-2 text-xl font-semibold text-gray-900 hover:text-azure-600">
                    {post.title}
                  </h2>
                </Link>
                {post.excerpt && (
                  <p className="mb-4 line-clamp-3 text-gray-600">{post.excerpt}</p>
                )}
                <div className="flex items-center justify-between text-sm text-gray-500">
                  <span>{post.author?.displayName ?? 'Anonymous'}</span>
                  <span>{post.publishedAt ? new Date(post.publishedAt).toLocaleDateString() : ''}</span>
                </div>
                {post.tags && post.tags.length > 0 && (
                  <div className="mt-4 flex flex-wrap gap-2">
                    {post.tags.slice(0, 3).map((tag) => (
                      <span
                        key={tag}
                        className="rounded-full bg-azure-100 px-2 py-1 text-xs text-azure-700"
                      >
                        {tag}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}

export default HomePage;
