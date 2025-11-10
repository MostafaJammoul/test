import { useState } from 'react';
import { useInvestigations } from '../../hooks/useInvestigations';
import Layout from '../../components/layout/Layout';
import InvestigationCard from '../../components/investigation/InvestigationCard';
import Button from '../../components/common/Button';
import { useAuth } from '../../contexts/AuthContext';
import { INVESTIGATION_STATUS } from '../../utils/constants';

export default function InvestigationListPage() {
  const [filters, setFilters] = useState({
    status: '',
    search: '',
  });

  const { isCourt } = useAuth();
  const { data, isLoading } = useInvestigations(filters);

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-bold text-gray-900">Investigations</h1>
          {isCourt() && <Button>Create Investigation</Button>}
        </div>

        {/* Filters */}
        <div className="bg-white rounded-lg shadow-md p-4 flex items-center space-x-4">
          <input
            type="text"
            placeholder="Search case number, title..."
            value={filters.search}
            onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          />

          <select
            value={filters.status}
            onChange={(e) => setFilters({ ...filters, status: e.target.value })}
            className="rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          >
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="archived">Archived</option>
          </select>
        </div>

        {/* Investigation Cards */}
        {isLoading ? (
          <div>Loading...</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {data?.results?.map((investigation) => (
              <InvestigationCard key={investigation.id} investigation={investigation} />
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
}
