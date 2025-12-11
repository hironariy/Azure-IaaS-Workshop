/**
 * Layout Component
 * Common layout with header and navigation
 * Reference: /design/FrontendApplicationDesign.md
 */

import { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useIsAuthenticated, useMsal } from '@azure/msal-react';
import { loginRequest } from '../config/authConfig';

interface LayoutProps {
  children: ReactNode;
}

/**
 * Layout Component
 * Provides consistent header, navigation, and footer
 */
function Layout({ children }: LayoutProps) {
  const isAuthenticated = useIsAuthenticated();
  const { instance, accounts } = useMsal();

  const handleLogin = () => {
    instance.loginRedirect(loginRequest);
  };

  const handleLogout = () => {
    // Clear sessionStorage on logout
    // Reference: /design/RepositoryWideDesignRules.md - Section 1.3
    instance.logoutRedirect({
      postLogoutRedirectUri: window.location.origin,
    });
  };

  const userName = accounts[0]?.name ?? 'User';

  return (
    <div className="flex min-h-screen flex-col">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white shadow-sm">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4">
          {/* Logo */}
          <Link to="/" className="text-2xl font-bold text-azure-600">
            BlogApp
          </Link>

          {/* Navigation */}
          <nav className="flex items-center space-x-6">
            <Link to="/" className="text-gray-600 hover:text-azure-600">
              Home
            </Link>

            {isAuthenticated ? (
              <>
                <Link to="/my-posts" className="text-gray-600 hover:text-azure-600">
                  My Posts
                </Link>
                <Link to="/create" className="text-gray-600 hover:text-azure-600">
                  Write Post
                </Link>
                <Link to="/profile" className="text-gray-600 hover:text-azure-600">
                  Profile
                </Link>
                <div className="flex items-center space-x-4">
                  <span className="text-sm text-gray-500">Hello, {userName}</span>
                  <button onClick={handleLogout} className="btn-secondary text-sm">
                    Sign Out
                  </button>
                </div>
              </>
            ) : (
              <button onClick={handleLogin} className="btn-primary text-sm">
                Sign In
              </button>
            )}
          </nav>
        </div>
      </header>

      {/* Main Content */}
      <main className="mx-auto w-full max-w-7xl flex-grow px-4 py-8">{children}</main>

      {/* Footer */}
      <footer className="border-t border-gray-200 bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 text-center text-sm text-gray-500">
          <p>Azure IaaS Workshop - Multi-user Blog Application</p>
          <p className="mt-1">
            Built with React, TypeScript, and Microsoft Entra ID
          </p>
        </div>
      </footer>
    </div>
  );
}

export default Layout;
