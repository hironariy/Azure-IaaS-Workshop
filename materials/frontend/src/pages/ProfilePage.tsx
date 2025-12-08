/**
 * Profile Page Component
 * User profile display
 */

import { useMsal } from '@azure/msal-react';

function ProfilePage() {
  const { accounts } = useMsal();
  const account = accounts[0];

  if (!account) {
    return (
      <div className="text-center text-gray-600">
        Please sign in to view your profile.
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl">
      <h1 className="mb-8 text-3xl font-bold text-gray-900">Your Profile</h1>

      <div className="card p-6">
        <div className="mb-6 flex items-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-azure-100 text-2xl font-bold text-azure-600">
            {account.name?.charAt(0).toUpperCase() ?? 'U'}
          </div>
          <div className="ml-4">
            <h2 className="text-xl font-semibold text-gray-900">{account.name}</h2>
            <p className="text-gray-600">{account.username}</p>
          </div>
        </div>

        <div className="space-y-4 border-t border-gray-200 pt-6">
          <div>
            <span className="text-sm font-medium text-gray-500">Name</span>
            <p className="text-gray-900">{account.name}</p>
          </div>
          <div>
            <span className="text-sm font-medium text-gray-500">Email</span>
            <p className="text-gray-900">{account.username}</p>
          </div>
          <div>
            <span className="text-sm font-medium text-gray-500">Tenant ID</span>
            <p className="font-mono text-sm text-gray-600">{account.tenantId}</p>
          </div>
        </div>
      </div>

      <div className="mt-8 rounded-lg bg-azure-50 p-6">
        <h3 className="mb-2 font-semibold text-azure-800">Azure IaaS Workshop</h3>
        <p className="text-sm text-azure-700">
          You are authenticated via Microsoft Entra ID. This is similar to using
          AWS Cognito for user authentication, but uses Microsoft's identity platform.
        </p>
      </div>
    </div>
  );
}

export default ProfilePage;
