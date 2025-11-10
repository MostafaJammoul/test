import { Link } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import Badge from '../common/Badge';
import { ROLE_NAMES, ROLE_COLORS } from '../../utils/constants';

export default function Navbar() {
  const { user, isAdmin } = useAuth();

  const primaryRole = user?.system_roles?.[0];
  const roleName = primaryRole ? ROLE_NAMES[primaryRole.id] : 'Unknown';
  const roleColorClass = primaryRole ? ROLE_COLORS[primaryRole.id] : 'bg-gray-100 text-gray-800';

  return (
    <nav className="bg-white shadow-md border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          {/* Logo and Title */}
          <div className="flex items-center">
            <Link to="/dashboard" className="flex items-center">
              <div className="flex-shrink-0 flex items-center">
                <svg
                  className="h-8 w-8 text-primary-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                  />
                </svg>
                <span className="ml-2 text-xl font-bold text-gray-900">
                  Blockchain Chain of Custody
                </span>
              </div>
            </Link>
          </div>

          {/* Navigation Links */}
          <div className="flex items-center space-x-4">
            <Link
              to="/investigations"
              className="text-gray-700 hover:text-primary-600 px-3 py-2 rounded-md text-sm font-medium transition-colors"
            >
              Investigations
            </Link>

            {isAdmin() && (
              <Link
                to="/admin-dashboard"
                className="text-gray-700 hover:text-primary-600 px-3 py-2 rounded-md text-sm font-medium transition-colors"
              >
                Admin Dashboard
              </Link>
            )}

            {/* User Info */}
            <div className="flex items-center space-x-3 border-l border-gray-300 pl-4">
              <div className="text-right">
                <div className="text-sm font-medium text-gray-900">{user?.username}</div>
                <Badge className={roleColorClass}>{roleName}</Badge>
              </div>
              <div className="h-8 w-8 rounded-full bg-primary-600 flex items-center justify-center text-white font-semibold">
                {user?.username?.[0]?.toUpperCase()}
              </div>
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}
