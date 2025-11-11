import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import Layout from '../../components/layout/Layout';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import Badge from '../../components/common/Badge';
import { useAuth } from '../../contexts/AuthContext';
import apiClient from '../../services/api';
import { STATUS_DISPLAY } from '../../utils/constants';
import { formatDate } from '../../utils/formatters';

export default function CourtDashboard() {
  const { user } = useAuth();

  // Fetch ALL investigations (Court can see everything)
  const { data: investigations, isLoading } = useQuery({
    queryKey: ['investigations', 'all'],
    queryFn: async () => {
      const response = await apiClient.get('/blockchain/investigations/');
      return response.data.results || response.data;
    },
  });

  // Get active vs archived counts
  const activeCount = investigations?.filter(inv => inv.status === 'active').length || 0;
  const archivedCount = investigations?.filter(inv => inv.status === 'archived').length || 0;

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Court Dashboard</h1>
          <p className="mt-2 text-gray-600">Welcome, {user?.name || user?.username}</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <StatsCard title="Total Cases" value={investigations?.length || 0} />
          <StatsCard title="Active Cases" value={activeCount} />
          <StatsCard title="Archived Cases" value={archivedCount} />
        </div>

        {/* All Investigations */}
        <Card title="All Investigations">
          {isLoading ? (
            <div className="text-center py-8 text-gray-600">Loading...</div>
          ) : investigations?.length > 0 ? (
            <div className="space-y-3">
              {investigations.map((investigation) => (
                <Link
                  key={investigation.id}
                  to={`/investigations/${investigation.id}`}
                  className="block"
                >
                  <div className="flex items-center justify-between p-4 border border-gray-200 rounded-md hover:bg-gray-50 transition-colors">
                    <div className="flex-1">
                      <div className="flex items-center space-x-3">
                        <h3 className="text-lg font-semibold text-gray-900">
                          {investigation.case_number}
                        </h3>
                        <Badge variant={investigation.status === 'active' ? 'success' : 'secondary'}>
                          {STATUS_DISPLAY[investigation.status]}
                        </Badge>
                      </div>
                      <p className="mt-1 text-gray-600">{investigation.title}</p>
                      <p className="mt-1 text-sm text-gray-500">
                        Created {formatDate(investigation.created_at)} • {investigation.evidence_count} evidence items
                      </p>
                    </div>
                    <svg
                      className="w-5 h-5 text-gray-400"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <div className="text-center py-8">
              <p className="text-gray-600">No investigations in the system yet.</p>
            </div>
          )}
        </Card>

        {/* Quick Actions & Info */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card title="Quick Actions">
            <div className="space-y-3">
              <Button
                as={Link}
                to="/investigations"
                variant="primary"
                className="w-full"
              >
                View All Cases
              </Button>
              <p className="text-sm text-gray-600">
                You have read-only access to all investigations in the system. You can view evidence, download files, and resolve GUIDs.
              </p>
            </div>
          </Card>

          <Card title="Permissions">
            <div className="space-y-2 text-sm text-gray-600">
              <div className="flex items-start space-x-2">
                <svg className="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span>View ALL investigations (read-only)</span>
              </div>
              <div className="flex items-start space-x-2">
                <svg className="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span>Download evidence files</span>
              </div>
              <div className="flex items-start space-x-2">
                <svg className="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span>Resolve GUIDs (unmask anonymous investigators)</span>
              </div>
              <div className="flex items-start space-x-2">
                <svg className="w-5 h-5 text-green-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
                <span>View complete audit trails</span>
              </div>
              <div className="flex items-start space-x-2">
                <svg className="w-5 h-5 text-red-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                </svg>
                <span>Cannot modify investigations or upload evidence</span>
              </div>
              <div className="flex items-start space-x-2">
                <svg className="w-5 h-5 text-red-500 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                </svg>
                <span>Cannot add notes to investigations</span>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </Layout>
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
