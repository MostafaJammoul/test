import { Routes, Route } from 'react-router-dom';
import Layout from '../../components/layout/Layout';
import TagManagement from '../../components/admin/TagManagement';
import UserManagement from '../../components/admin/UserManagement';
import CertificateManagement from '../../components/admin/CertificateManagement';

export default function AdminDashboard() {
  return (
    <Layout>
      <div className="space-y-6">
        <h1 className="text-3xl font-bold text-gray-900">Admin Dashboard</h1>

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
