/**
 * Main App Component
 * Application routing and layout
 * Reference: /design/FrontendApplicationDesign.md
 */

import { Routes, Route } from 'react-router-dom';
import { useIsAuthenticated } from '@azure/msal-react';
import Layout from './components/Layout';
import HomePage from './pages/HomePage';
import PostPage from './pages/PostPage';
import CreatePostPage from './pages/CreatePostPage';
import EditPostPage from './pages/EditPostPage';
import ProfilePage from './pages/ProfilePage';
import LoginPage from './pages/LoginPage';
import MyPostsPage from './pages/MyPostsPage';

/**
 * App Component
 * Defines application routes
 */
function App() {
  const isAuthenticated = useIsAuthenticated();

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/posts/:slug" element={<PostPage />} />
        <Route path="/login" element={<LoginPage />} />

        {/* Protected routes - only for authenticated users */}
        {isAuthenticated && (
          <>
            <Route path="/create" element={<CreatePostPage />} />
            <Route path="/posts/:slug/edit" element={<EditPostPage />} />
            <Route path="/my-posts" element={<MyPostsPage />} />
            <Route path="/profile" element={<ProfilePage />} />
          </>
        )}

        {/* Fallback for unmatched routes */}
        <Route path="*" element={<HomePage />} />
      </Routes>
    </Layout>
  );
}

export default App;
