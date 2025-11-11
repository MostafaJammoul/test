import { Routes, Route, Link, useLocation } from 'react-router-dom';
import Layout from '../../components/layout/Layout';
import TagManagement from '../../components/admin/TagManagement';
import UserManagement from '../../components/admin/UserManagement';
import CertificateManagement from '../../components/admin/CertificateManagement';

export default function AdminDashboard() {
  const location = useLocation();

  const tabs = [
    { name: 'Overview', path: '/admin-dashboard' },
    { name: 'Users', path: '/admin-dashboard/users' },
    { name: 'Tags', path: '/admin-dashboard/tags' },
    { name: 'Certificates', path: '/admin-dashboard/certificates' },
  ];

  return (
    <Layout>
      <div className="space-y-6">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>

        {/* Tab Navigation */}
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            {tabs.map((tab) => {
              const isActive = location.pathname === tab.path;
              return (
                <Link
                  key={tab.path}
                  to={tab.path}
                  className={`
                    whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors
                    ${
                      isActive
                        ? 'border-primary-500 text-primary-600'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }
                  `}
                >
                  {tab.name}
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Tab Content */}
        <Routes>
          <Route index element={<AdminOverview />} />
          <Route path="tags" element={<TagManagement />} />
          <Route path="users" element={<UserManagement />} />
          <Route path="certificates" element={<CertificateManagement />} />
        </Routes>
      </div>
    </Layout>
  );
}

function AdminOverview() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
      <StatsCard title="Total Investigations" value="42" />
      <StatsCard title="Total Users" value="15" />
      <StatsCard title="Active Tags" value="28" />
    </div>
  );
}

function StatsCard({ title, value }) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h3 className="text-sm font-medium text-gray-600">{title}</h3>
      <p className="mt-2 text-3xl font-bold text-gray-900">{value}</p>
    </div>
  );
}
