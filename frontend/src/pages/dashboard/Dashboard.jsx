import { useAuth } from '../../contexts/AuthContext';
import Layout from '../../components/layout/Layout';
import { Link } from 'react-router-dom';
import Button from '../../components/common/Button';
import Badge from '../../components/common/Badge';
import { ROLE_NAMES } from '../../utils/constants';

export default function Dashboard() {
  const { user, isAdmin, isInvestigator, isAuditor, isCourt } = useAuth();
  const primaryRole = user?.system_roles?.[0];
  const roleName = primaryRole ? ROLE_NAMES[primaryRole.id] : 'Unknown';

  return (
    <Layout>
      <div className="space-y-6">
        {/* Welcome Header */}
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            Welcome, {user?.name || user?.username}
          </h1>
          <p className="mt-2 text-gray-600">Role: {roleName}</p>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Link to="/investigations">
            <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
              <h3 className="text-lg font-semibold">View Investigations</h3>
              <p className="mt-2 text-gray-600">Browse all cases</p>
            </div>
          </Link>

          {isCourt() && (
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold">Create Investigation</h3>
              <p className="mt-2 text-gray-600">Start new case</p>
            </div>
          )}

          {isInvestigator() && (
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold">Upload Evidence</h3>
              <p className="mt-2 text-gray-600">Add evidence to case</p>
            </div>
          )}

          {isAdmin() && (
            <Link to="/admin-dashboard">
              <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
                <h3 className="text-lg font-semibold">Admin Dashboard</h3>
                <p className="mt-2 text-gray-600">Manage system</p>
              </div>
            </Link>
          )}
        </div>

        {/* Recent Activity */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-semibold mb-4">Recent Activity</h2>
          <p className="text-gray-600">Activity feed will appear here</p>
        </div>
      </div>
    </Layout>
  );
}
