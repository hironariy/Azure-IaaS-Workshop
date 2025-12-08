/**
 * Create Post Page Component
 * Form for creating new blog posts
 */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { createPost } from '../services/api';

function CreatePostPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    title: '',
    content: '',
    excerpt: '',
    tags: '',
    status: 'draft' as 'draft' | 'published',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const post = await createPost({
        title: formData.title,
        content: formData.content,
        excerpt: formData.excerpt || undefined,
        tags: formData.tags ? formData.tags.split(',').map((t) => t.trim()) : undefined,
        status: formData.status,
      });

      navigate(`/posts/${post.slug}`);
    } catch (err) {
      setError('Failed to create post. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl">
      <h1 className="mb-8 text-3xl font-bold text-gray-900">Create New Post</h1>

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
              Publish Now
            </label>
          </div>
        </div>

        <div className="flex space-x-4">
          <button type="submit" disabled={loading} className="btn-primary">
            {loading ? 'Creating...' : 'Create Post'}
          </button>
          <button type="button" onClick={() => navigate('/')} className="btn-secondary">
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}

export default CreatePostPage;
