/**
 * Edit Post Page Component
 * Form for editing existing blog posts
 */

import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { getPost, updatePost, Post } from '../services/api';

function EditPostPage() {
  const { slug } = useParams<{ slug: string }>();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [post, setPost] = useState<Post | null>(null);

  const [formData, setFormData] = useState({
    title: '',
    content: '',
    excerpt: '',
    tags: '',
    status: 'draft' as 'draft' | 'published',
  });

  useEffect(() => {
    async function fetchPost() {
      if (!slug) return;

      try {
        const data = await getPost(slug);
        setPost(data);
        setFormData({
          title: data.title,
          content: data.content,
          excerpt: data.excerpt || '',
          tags: data.tags?.join(', ') || '',
          status: data.status as 'draft' | 'published',
        });
      } catch (err) {
        setError('Failed to load post. You may not have permission to edit this post.');
        console.error(err);
      } finally {
        setLoading(false);
      }
    }

    fetchPost();
  }, [slug]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!slug) return;

    setSaving(true);
    setError(null);

    try {
      const updatedPost = await updatePost(slug, {
        title: formData.title,
        content: formData.content,
        excerpt: formData.excerpt || undefined,
        tags: formData.tags ? formData.tags.split(',').map((t) => t.trim()) : undefined,
        status: formData.status,
      });

      navigate(`/posts/${updatedPost.slug}`);
    } catch (err) {
      setError('Failed to update post. Please try again.');
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-azure-600 border-t-transparent"></div>
      </div>
    );
  }

  if (!post) {
    return (
      <div className="rounded-lg bg-red-50 p-8 text-center">
        <h2 className="mb-2 text-xl font-semibold text-red-800">Post Not Found</h2>
        <p className="text-red-700">
          The post you're trying to edit doesn't exist or you don't have permission to edit it.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="mb-8 text-3xl font-bold text-gray-900">Edit Post</h1>

      {error && (
        <div className="mb-6 rounded-lg bg-red-50 p-4 text-red-600">{error}</div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        <div>
          <label htmlFor="title" className="mb-2 block font-medium text-gray-700">
            Title *
          </label>
          <input
            type="text"
            id="title"
            required
            maxLength={200}
            className="input"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            placeholder="Enter post title"
          />
        </div>

        <div>
          <label htmlFor="excerpt" className="mb-2 block font-medium text-gray-700">
            Excerpt
          </label>
          <input
            type="text"
            id="excerpt"
            maxLength={500}
            className="input"
            value={formData.excerpt}
            onChange={(e) => setFormData({ ...formData, excerpt: e.target.value })}
            placeholder="Brief summary (optional)"
          />
        </div>

        <div>
          <label htmlFor="content" className="mb-2 block font-medium text-gray-700">
            Content *
          </label>
          <textarea
            id="content"
            required
            rows={15}
            className="input min-h-[300px] resize-y"
            value={formData.content}
            onChange={(e) => setFormData({ ...formData, content: e.target.value })}
            placeholder="Write your post content here..."
          />
        </div>

        <div>
          <label htmlFor="tags" className="mb-2 block font-medium text-gray-700">
            Tags
          </label>
          <input
            type="text"
            id="tags"
            className="input"
            value={formData.tags}
            onChange={(e) => setFormData({ ...formData, tags: e.target.value })}
            placeholder="Enter tags separated by commas (e.g., azure, cloud, tutorial)"
          />
        </div>

        <div>
          <label className="mb-2 block font-medium text-gray-700">Status</label>
          <div className="flex space-x-4">
            <label className="flex items-center">
              <input
                type="radio"
                name="status"
                value="draft"
                checked={formData.status === 'draft'}
                onChange={(e) =>
                  setFormData({ ...formData, status: e.target.value as 'draft' | 'published' })
                }
                className="mr-2"
              />
              Draft
            </label>
            <label className="flex items-center">
              <input
                type="radio"
                name="status"
                value="published"
                checked={formData.status === 'published'}
                onChange={(e) =>
                  setFormData({ ...formData, status: e.target.value as 'draft' | 'published' })
                }
                className="mr-2"
              />
              Published
            </label>
          </div>
        </div>

        <div className="flex space-x-4">
          <button type="submit" disabled={saving} className="btn-primary">
            {saving ? 'Saving...' : 'Save Changes'}
          </button>
          <button
            type="button"
            onClick={() => navigate(`/posts/${slug}`)}
            className="btn-secondary"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}

export default EditPostPage;
