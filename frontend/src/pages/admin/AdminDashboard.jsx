import { Routes, Route, Link, useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import Layout from '../../components/layout/Layout';
import TagManagement from '../../components/admin/TagManagement';
import UserManagement from '../../components/admin/UserManagement';
import CertificateManagement from '../../components/admin/CertificateManagement';
import { investigationAPI, tagAPI } from '../../services/api';
import apiClient from '../../services/api';

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
  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin-dashboard-overview'],
    queryFn: async () => {
      const countParams = { page: 1, page_size: 1, limit: 1 };

      const [investigationRes, userRes, tagRes, certificateRes] = await Promise.all([
        investigationAPI.list(countParams),
        apiClient.get('/users/users/'),
        tagAPI.list(),
        apiClient.get('/pki/certificates/'),
      ]);

      const parseCount = (payload) => {
        if (typeof payload?.count === 'number') return payload.count;
        if (Array.isArray(payload)) return payload.length;
        if (Array.isArray(payload?.results)) return payload.results.length;
        return 0;
      };

      const toArray = (payload) => {
        if (Array.isArray(payload)) return payload;
        if (Array.isArray(payload?.results)) return payload.results;
        return [];
      };

      const investigationsCount = parseCount(investigationRes.data);
      const usersList = toArray(userRes.data);
      const tagsList = toArray(tagRes.data);
      const certificatesList = toArray(certificateRes.data);

      const now = new Date();
      const activeCertificates = certificatesList.filter((cert) => {
        if (cert.revoked) return false;
        if (cert.is_valid !== undefined) return cert.is_valid;
        const expiry = cert.not_after ? new Date(cert.not_after) : null;
        if (!expiry) return true;
        return expiry > now;
      }).length;
      const inactiveCertificates = certificatesList.length - activeCertificates;

      return {
        investigations: investigationsCount,
        users: usersList.length,
        tags: tagsList.length,
        activeCertificates,
        inactiveCertificates,
      };
    },
    staleTime: 60 * 1000,
  });

  const metrics = [
    { title: 'Total Investigations', key: 'investigations' },
    { title: 'Total Users', key: 'users' },
    { title: 'Active Tags', key: 'tags' },
    { title: 'Active Certificates', key: 'activeCertificates' },
    { title: 'Inactive Certificates', key: 'inactiveCertificates' },
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-6">
      {metrics.map((metric) => (
        <StatsCard
          key={metric.key}
          title={metric.title}
          value={data?.[metric.key] ?? 0}
          loading={isLoading}
          error={isError}
        />
      ))}
    </div>
  );
}

function StatsCard({ title, value, loading, error }) {
  let displayValue = value;
  if (loading) {
    displayValue = '...';
  } else if (error) {
    displayValue = '—';
  } else if (typeof value === 'number') {
    displayValue = value.toLocaleString();
  }

  return (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h3 className="text-sm font-medium text-gray-600">{title}</h3>
      <p className="mt-2 text-3xl font-bold text-gray-900">{displayValue}</p>
    </div>
  );
}
