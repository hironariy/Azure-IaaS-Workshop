/**
 * Main App Component
 * Application routing and layout
 * Reference: /design/FrontendApplicationDesign.md
 */

import { ReactNode } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
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
 * ProtectedRoute Component
 * Wraps routes that require authentication
 *
 * For AWS-experienced engineers:
 * - Similar to using AWS Amplify's withAuthenticator HOC
 * - Redirects to login page if user is not authenticated
 * - Preserves the original URL so user can be redirected back after login
 *
 * @param children - The protected component to render
 */
interface ProtectedRouteProps {
  children: ReactNode;
}

function ProtectedRoute({ children }: ProtectedRouteProps) {
  const isAuthenticated = useIsAuthenticated();
  const location = useLocation();

  if (!isAuthenticated) {
    // Redirect to login page, preserving the intended destination
    // The 'state' prop allows LoginPage to redirect back after successful auth
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}

/**
 * App Component
 * Defines application routes
 */
function App() {
  return (
    <Layout>
      <Routes>
        {/* Public routes */}
        <Route path="/" element={<HomePage />} />
        <Route path="/posts/:slug" element={<PostPage />} />
        <Route path="/login" element={<LoginPage />} />

        {/* Protected routes - require authentication */}
        <Route
          path="/create"
          element={
            <ProtectedRoute>
              <CreatePostPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/posts/:slug/edit"
          element={
            <ProtectedRoute>
              <EditPostPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/my-posts"
          element={
            <ProtectedRoute>
              <MyPostsPage />
            </ProtectedRoute>
          }
        />
        <Route
          path="/profile"
          element={
            <ProtectedRoute>
              <ProfilePage />
            </ProtectedRoute>
          }
        />

        {/* Fallback for unmatched routes */}
        <Route path="*" element={<HomePage />} />
      </Routes>
    </Layout>
  );
}

export default App;
