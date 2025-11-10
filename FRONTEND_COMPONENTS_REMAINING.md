# Remaining Frontend Components to Implement

**Current Progress**: Foundation Complete ✅
**Status**: Ready for component implementation

---

## ✅ Already Created Components

### Foundation
- [x] `src/main.jsx` - React entry point with React Query
- [x] `src/App.jsx` - Main app with role-based routing
- [x] `src/index.css` - Global styles with Tailwind

### Utils
- [x] `src/utils/constants.js` - Role IDs, statuses, colors
- [x] `src/utils/formatters.js` - Date, file size, hash formatters

### Contexts & Hooks
- [x] `src/contexts/AuthContext.jsx` - Authentication context
- [x] `src/hooks/useInvestigations.js` - Investigation queries and mutations

### Common Components
- [x] `src/components/common/Badge.jsx` - Colored badges
- [x] `src/components/common/Button.jsx` - Reusable buttons
- [x] `src/components/common/Card.jsx` - Content containers
- [x] `src/components/common/Modal.jsx` - Dialog overlays

### Layout
- [x] `src/components/layout/Navbar.jsx` - Top navigation bar
- [x] `src/components/layout/Layout.jsx` - Page wrapper

### Pages
- [x] `src/pages/MFAChallenge.jsx` - MFA verification page
- [x] `src/pages/NotFound.jsx` - 404 page

---

## 📋 Components to Implement

### 1. Admin Dashboard (`src/pages/admin/AdminDashboard.jsx`)

```jsx
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
```

---

### 2. Tag Management (`src/components/admin/TagManagement.jsx`)

```jsx
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { tagAPI } from '../../services/api';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import Modal from '../common/Modal';
import { TAG_CATEGORY_DISPLAY } from '../../utils/constants';

export default function TagManagement() {
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const queryClient = useQueryClient();

  const { data: tags, isLoading } = useQuery({
    queryKey: ['tags'],
    queryFn: async () => {
      const response = await tagAPI.list();
      return response.data.results;
    },
  });

  const createMutation = useMutation({
    mutationFn: tagAPI.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      setIsCreateModalOpen(false);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: tagAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
    },
  });

  if (isLoading) return <div>Loading...</div>;

  return (
    <Card
      title="Tag Library Management"
      actions={
        <Button onClick={() => setIsCreateModalOpen(true)}>Create Tag</Button>
      }
    >
      <div className="space-y-2">
        {tags?.map((tag) => (
          <div
            key={tag.id}
            className="flex items-center justify-between p-3 border border-gray-200 rounded-md"
          >
            <div className="flex items-center space-x-3">
              <div
                className="w-6 h-6 rounded-full"
                style={{ backgroundColor: tag.color }}
              ></div>
              <div>
                <div className="font-medium">{tag.name}</div>
                <div className="text-sm text-gray-500">
                  {TAG_CATEGORY_DISPLAY[tag.category]}
                </div>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <Badge>{tag.tagged_count} cases</Badge>
              <Button
                variant="danger"
                size="sm"
                onClick={() => {
                  if (confirm(`Delete tag "${tag.name}"?`)) {
                    deleteMutation.mutate(tag.id);
                  }
                }}
              >
                Delete
              </Button>
            </div>
          </div>
        ))}
      </div>

      {/* Create Tag Modal */}
      <Modal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        title="Create Tag"
        footer={
          <>
            <Button variant="secondary" onClick={() => setIsCreateModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" form="create-tag-form">
              Create
            </Button>
          </>
        }
      >
        <TagForm
          onSubmit={(data) => createMutation.mutate(data)}
          formId="create-tag-form"
        />
      </Modal>
    </Card>
  );
}

function TagForm({ onSubmit, formId }) {
  const [formData, setFormData] = useState({
    name: '',
    category: 'crime_type',
    color: '#3B82F6',
    description: '',
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form id={formId} onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">Tag Name</label>
        <input
          type="text"
          required
          value={formData.name}
          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Category</label>
        <select
          value={formData.category}
          onChange={(e) => setFormData({ ...formData, category: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        >
          <option value="crime_type">Crime Type</option>
          <option value="priority">Priority</option>
          <option value="status">Status</option>
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Color</label>
        <input
          type="color"
          value={formData.color}
          onChange={(e) => setFormData({ ...formData, color: e.target.value })}
          className="mt-1 block w-full h-10 rounded-md border-gray-300"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Description</label>
        <textarea
          value={formData.description}
          onChange={(e) => setFormData({ ...formData, description: e.target.value })}
          rows={3}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        />
      </div>
    </form>
  );
}
```

---

### 3. Dashboard (`src/pages/dashboard/Dashboard.jsx`)

```jsx
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
```

---

### 4. Investigation List (`src/pages/dashboard/InvestigationListPage.jsx`)

```jsx
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
```

---

### 5. Investigation Card (`src/components/investigation/InvestigationCard.jsx`)

```jsx
import { Link } from 'react-router-dom';
import Badge from '../common/Badge';
import { formatDate, isRecent } from '../../utils/formatters';
import { STATUS_COLORS } from '../../utils/constants';

export default function InvestigationCard({ investigation }) {
  const hasRecentActivity = investigation.activities?.some((a) => isRecent(a.timestamp));

  return (
    <Link to={`/investigations/${investigation.id}`}>
      <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow relative">
        {/* Recent Activity Badge */}
        {hasRecentActivity && (
          <Badge variant="recent" className="absolute top-2 right-2">
            New Activity
          </Badge>
        )}

        {/* Case Number */}
        <div className="text-sm font-medium text-primary-600 mb-2">
          {investigation.case_number}
        </div>

        {/* Title */}
        <h3 className="text-lg font-semibold text-gray-900 mb-2">{investigation.title}</h3>

        {/* Description */}
        <p className="text-sm text-gray-600 line-clamp-2 mb-4">{investigation.description}</p>

        {/* Status & Evidence Count */}
        <div className="flex items-center justify-between">
          <Badge className={STATUS_COLORS[investigation.status]}>
            {investigation.status}
          </Badge>
          <span className="text-sm text-gray-600">
            {investigation.evidence_count} evidence files
          </span>
        </div>

        {/* Created At */}
        <div className="mt-4 text-xs text-gray-500">
          Created {formatDate(investigation.created_at)}
        </div>
      </div>
    </Link>
  );
}
```

---

## Installation and Testing

### 1. Install Dependencies
```bash
cd c:\Users\mosta\Desktop\FYP\JumpServer\truefypjs\frontend
npm install
```

### 2. Start Development Server
```bash
npm run dev
```

### 3. Access Application
- Open browser to `http://localhost:3000`
- Certificate authentication (mTLS) will proxy through to backend
- Enter MFA code from authenticator app
- Dashboard loads based on user role

---

## Next Steps for Full Implementation

1. **Implement remaining hooks**:
   - `useEvidence.js`
   - `useTags.js`
   - `useActivities.js`
   - `useNotes.js`

2. **Create Investigation Detail Page** with tabs:
   - Evidence list with upload form (Investigator)
   - Notes timeline with add form (Investigator)
   - Blockchain transaction history
   - Activity feed with 24h indicators
   - Tag assignment (Court, max 3)

3. **Add Charts** using Recharts:
   - Evidence upload frequency over time
   - Activity breakdown by type
   - Investigation statistics

4. **Implement WebSocket** for real-time updates:
   - Activity notifications
   - Evidence upload progress
   - Blockchain confirmation status

5. **Add Export Functionality**:
   - PDF report generation
   - CSV data export
   - Evidence integrity verification report

---

## Component File Summary

**Created**:
- 12 core files (main.jsx, App.jsx, contexts, hooks, utils)
- 7 common/layout components
- 2 pages (MFA, NotFound)

**Remaining**:
- 3 admin components (UserManagement, CertificateManagement, TagManagement)
- 5 investigation components (InvestigationList, InvestigationCard, InvestigationDetail, EvidenceList, ActivityFeed)
- 2 dashboard pages (Dashboard, InvestigationListPage, InvestigationDetailPage)

**Total**: 24 components for complete implementation

---

**Current Status**: Frontend foundation complete, ready for full component implementation following this guide.
