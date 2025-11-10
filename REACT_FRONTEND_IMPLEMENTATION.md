# React Frontend Implementation Guide

**Complete implementation instructions for Blockchain Chain of Custody Dashboard**

---

## Setup Complete ✅

The following files have been created:

### Configuration Files
- `frontend/package.json` - Dependencies and scripts
- `frontend/vite.config.js` - Vite build configuration with API proxy
- `frontend/tailwind.config.js` - TailwindCSS theme (custom blockchain colors)
- `frontend/postcss.config.js` - PostCSS configuration
- `frontend/index.html` - HTML entry point

### Source Files
- `frontend/src/index.css` - Global styles and Tailwind utilities
- `frontend/src/services/api.js` - Complete API client with all endpoints

---

## Installation Steps

### 1. Install Dependencies

```bash
cd c:\Users\mosta\Desktop\FYP\JumpServer\truefypjs\frontend
npm install
```

### 2. Start Development Server

```bash
npm run dev
```

Frontend will run on `http://localhost:3000` and proxy API requests to `https://192.168.148.154`.

### 3. Build for Production

```bash
npm run build
```

Outputs to `truefypjs/apps/static/frontend/` for Django to serve.

---

## Directory Structure

```
frontend/
├── src/
│   ├── components/          # Reusable UI components
│   │   ├── common/
│   │   │   ├── Badge.jsx
│   │   │   ├── Button.jsx
│   │   │   ├── Card.jsx
│   │   │   ├── Modal.jsx
│   │   │   └── Spinner.jsx
│   │   ├── investigation/
│   │   │   ├── InvestigationCard.jsx
│   │   │   ├── InvestigationList.jsx
│   │   │   ├── InvestigationDetail.jsx
│   │   │   ├── InvestigationForm.jsx
│   │   │   ├── EvidenceList.jsx
│   │   │   ├── EvidenceUploadForm.jsx
│   │   │   ├── TagPicker.jsx
│   │   │   ├── NoteForm.jsx
│   │   │   └── ActivityFeed.jsx
│   │   ├── admin/
│   │   │   ├── UserManagement.jsx
│   │   │   ├── CertificateManagement.jsx
│   │   │   └── TagManagement.jsx
│   │   └── layout/
│   │       ├── Navbar.jsx
│   │       ├── Sidebar.jsx
│   │       └── Footer.jsx
│   ├── pages/               # Page components
│   │   ├── admin/
│   │   │   ├── AdminDashboard.jsx
│   │   │   ├── UserListPage.jsx
│   │   │   ├── CertificateListPage.jsx
│   │   │   └── TagListPage.jsx
│   │   ├── dashboard/
│   │   │   ├── Dashboard.jsx (role-based conditional rendering)
│   │   │   ├── InvestigationListPage.jsx
│   │   │   ├── InvestigationDetailPage.jsx
│   │   │   └── EvidenceListPage.jsx
│   │   ├── MFAChallenge.jsx
│   │   └── NotFound.jsx
│   ├── contexts/            # React contexts
│   │   ├── AuthContext.jsx
│   │   └── RoleContext.jsx
│   ├── hooks/               # Custom React hooks
│   │   ├── useAuth.js
│   │   ├── useInvestigations.js
│   │   ├── useEvidence.js
│   │   ├── useTags.js
│   │   ├── useActivities.js
│   │   └── useWebSocket.js
│   ├── services/
│   │   ├── api.js           # ✅ Already created
│   │   └── websocket.js     # WebSocket client for real-time updates
│   ├── utils/
│   │   ├── constants.js     # Role IDs, colors, etc.
│   │   ├── formatters.js    # Date, file size formatters
│   │   └── validators.js    # Form validation helpers
│   ├── App.jsx              # Main app component
│   ├── main.jsx             # React entry point
│   └── index.css            # ✅ Already created
├── package.json             # ✅ Already created
├── vite.config.js           # ✅ Already created
├── tailwind.config.js       # ✅ Already created
└── postcss.config.js        # ✅ Already created
```

---

## Next Steps: Component Implementation

### Step 1: Create `src/main.jsx`

```jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from './App.jsx'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 5 * 60 * 1000, // 5 minutes
    },
  },
})

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
)
```

### Step 2: Create `src/utils/constants.js`

```javascript
// Blockchain role IDs (must match Django RBAC)
export const ROLES = {
  SYSTEM_ADMIN: '00000000-0000-0000-0000-000000000001',
  BLOCKCHAIN_INVESTIGATOR: '00000000-0000-0000-0000-000000000008',
  BLOCKCHAIN_AUDITOR: '00000000-0000-0000-0000-000000000009',
  BLOCKCHAIN_COURT: '00000000-0000-0000-0000-00000000000A',
};

// Role display names
export const ROLE_NAMES = {
  [ROLES.SYSTEM_ADMIN]: 'System Administrator',
  [ROLES.BLOCKCHAIN_INVESTIGATOR]: 'Investigator',
  [ROLES.BLOCKCHAIN_AUDITOR]: 'Auditor',
  [ROLES.BLOCKCHAIN_COURT]: 'Court',
};

// Role colors (matches tailwind.config.js)
export const ROLE_COLORS = {
  [ROLES.SYSTEM_ADMIN]: 'role-admin',
  [ROLES.BLOCKCHAIN_INVESTIGATOR]: 'role-investigator',
  [ROLES.BLOCKCHAIN_AUDITOR]: 'role-auditor',
  [ROLES.BLOCKCHAIN_COURT]: 'role-court',
};

// Investigation statuses
export const INVESTIGATION_STATUS = {
  ACTIVE: 'active',
  ARCHIVED: 'archived',
};

// Activity types
export const ACTIVITY_TYPES = {
  EVIDENCE_ADDED: 'evidence_added',
  NOTE_ADDED: 'note_added',
  TAG_CHANGED: 'tag_changed',
  STATUS_CHANGED: 'status_changed',
  ASSIGNED: 'assigned',
};

// Tag categories
export const TAG_CATEGORIES = {
  CRIME_TYPE: 'crime_type',
  PRIORITY: 'priority',
  STATUS: 'status',
};

// Chain types
export const CHAIN_TYPES = {
  HOT: 'hot',
  COLD: 'cold',
};
```

### Step 3: Create `src/contexts/AuthContext.jsx`

```jsx
import { createContext, useContext, useState, useEffect } from 'react';
import { userAPI } from '../services/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [mfaRequired, setMfaRequired] = useState(false);

  // Fetch current user on mount
  useEffect(() => {
    const fetchUser = async () => {
      try {
        const response = await userAPI.me();
        setUser(response.data);
      } catch (error) {
        console.error('Failed to fetch user:', error);
        // Check if MFA required
        if (error.response?.status === 401 && error.response?.data?.mtls_mfa_required) {
          setMfaRequired(true);
        }
      } finally {
        setLoading(false);
      }
    };

    fetchUser();
  }, []);

  // Verify MFA code
  const verifyMFA = async (code) => {
    try {
      await userAPI.mfaVerify(code);
      // Fetch user after MFA verification
      const response = await userAPI.me();
      setUser(response.data);
      setMfaRequired(false);
      return { success: true };
    } catch (error) {
      return { success: false, error: error.response?.data?.error || 'Invalid MFA code' };
    }
  };

  // Get user roles (array of role IDs)
  const getUserRoles = () => user?.roles?.map(r => r.id) || [];

  // Check if user has specific role
  const hasRole = (roleId) => getUserRoles().includes(roleId);

  // Check if user has admin role
  const isAdmin = () => hasRole('00000000-0000-0000-0000-000000000001');

  const value = {
    user,
    loading,
    mfaRequired,
    verifyMFA,
    getUserRoles,
    hasRole,
    isAdmin,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

### Step 4: Create `src/App.jsx` (Role-Based Routing)

```jsx
import { Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import MFAChallenge from './pages/MFAChallenge';
import AdminDashboard from './pages/admin/AdminDashboard';
import Dashboard from './pages/dashboard/Dashboard';
import InvestigationDetailPage from './pages/dashboard/InvestigationDetailPage';
import NotFound from './pages/NotFound';
import Spinner from './components/common/Spinner';
import { ROLES } from './utils/constants';

// Protected route wrapper
const ProtectedRoute = ({ children, requireAdmin = false }) => {
  const { user, loading, mfaRequired, isAdmin } = useAuth();

  if (loading) return <Spinner />;
  if (mfaRequired) return <Navigate to="/mfa-challenge" replace />;
  if (!user) return <Navigate to="/mfa-challenge" replace />;
  if (requireAdmin && !isAdmin()) return <Navigate to="/dashboard" replace />;

  return children;
};

function AppRoutes() {
  return (
    <Routes>
      {/* MFA Challenge Page */}
      <Route path="/mfa-challenge" element={<MFAChallenge />} />

      {/* Admin Dashboard (SystemAdmin only) */}
      <Route
        path="/admin-dashboard/*"
        element={
          <ProtectedRoute requireAdmin>
            <AdminDashboard />
          </ProtectedRoute>
        }
      />

      {/* Role-Based Dashboard (All blockchain roles) */}
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <Dashboard />
          </ProtectedRoute>
        }
      />

      {/* Investigation Detail Page */}
      <Route
        path="/investigations/:id"
        element={
          <ProtectedRoute>
            <InvestigationDetailPage />
          </ProtectedRoute>
        }
      />

      {/* Redirect root to dashboard */}
      <Route path="/" element={<Navigate to="/dashboard" replace />} />

      {/* 404 Not Found */}
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}

export default App;
```

---

## Key Features to Implement

### 1. **Admin Dashboard** (`/admin-dashboard/`)
**Components needed**:
- User management table (create/deactivate users)
- Certificate issuance form
- Tag management (create/edit/delete predefined tags)
- System statistics (total investigations, evidence files, blockchain transactions)

**Permissions**: SystemAdmin only

---

### 2. **Investigation List** (All roles)
**Features**:
- Card grid with investigation details
- Tag filters (multi-select dropdown)
- Status filter (active/archived)
- Search by case number, title
- Sort by created_at, case_number
- Color-coded tag badges
- 24-hour activity indicators (red badge if `is_recent`)

**Conditional rendering by role**:
- **Court**: "Create Investigation" button visible
- **Investigator**: Cannot create investigations
- **Auditor**: Read-only view

---

### 3. **Investigation Detail Page**
**Tabs**:

#### Tab 1: Overview
- Investigation metadata (case_number, title, description, status)
- Tags (Court can add/remove up to 3)
- Timeline of status changes (created → archived → reopened)

#### Tab 2: Evidence
- Evidence list with file_name, file_size, uploaded_by, uploaded_at
- **Investigator**: "Upload Evidence" button
- Download button for all users
- Verify integrity button (shows blockchain verification status)
- IPFS CID link
- Blockchain transaction hash link

#### Tab 3: Notes
- Chronological note timeline
- **Investigator**: "Add Note" form
- Each note shows: content, created_by, created_at, blockchain verification status
- Green checkmark if `is_blockchain_verified: true`

#### Tab 4: Blockchain History
- All blockchain transactions (hot + cold chain)
- Transaction hash, block_number, chain_type, timestamp
- Merkle proof verification

#### Tab 5: Activity Feed
- All activities sorted by timestamp (newest first)
- Filter buttons: "All", "Unread", "Last 24 Hours"
- Mark as viewed button
- Activity type icons (evidence, note, tag, status)
- Performed_by user display

---

### 4. **Tag Management** (Admin only)
**Features**:
- Create tag form (name, category dropdown, color picker, description)
- Tag list table (name, category, color badge, tagged_count, created_at)
- Edit/delete buttons
- Category filters (crime_type, priority, status)

**Validation**:
- Unique tag names
- Valid hex color codes

---

### 5. **Tag Assignment** (Court only)
**Features**:
- Dropdown showing all available tags from library
- Max 3 tags enforced (UI disables dropdown when 3 assigned)
- Remove tag button (X icon on tag badge)
- Auto-creates activity entry when tag added/removed

---

### 6. **Evidence Upload** (Investigator only)
**Form fields**:
- Investigation dropdown (select case to add evidence to)
- Title input
- Description textarea
- File upload (drag-and-drop or browse)
- File preview (name, size, MIME type)
- Upload progress bar

**Workflow**:
1. User selects file
2. Form shows file preview
3. User clicks "Upload Evidence"
4. Frontend sends multipart/form-data to `/api/v1/blockchain/evidence/`
5. Backend uploads to IPFS (progress bar)
6. Backend writes hash to blockchain
7. Backend creates evidence record in PostgreSQL
8. Frontend shows success notification with IPFS CID and transaction hash

---

### 7. **Activity Indicators** (24-Hour Badges)
**UI Display**:
```jsx
<div className="relative">
  <InvestigationCard investigation={inv} />
  {hasRecentActivity && (
    <span className="absolute top-2 right-2 badge badge-recent">
      {recentActivityCount} new
    </span>
  )}
</div>
```

**Backend query**:
```javascript
const { data } = await activityAPI.list({
  investigation_id: investigationId,
  recent_only: true,
  unviewed_only: true,
});

const recentActivityCount = data.count;
```

---

### 8. **Evidence Verification**
**UI Display**:
```jsx
function EvidenceVerificationBadge({ evidenceId }) {
  const [verifying, setVerifying] = useState(false);
  const [status, setStatus] = useState(null);

  const handleVerify = async () => {
    setVerifying(true);
    try {
      const { data } = await evidenceAPI.verify(evidenceId);
      setStatus(data.status); // "verified" or "failed"
    } catch (error) {
      setStatus('error');
    } finally {
      setVerifying(false);
    }
  };

  return (
    <div>
      <button onClick={handleVerify} disabled={verifying}>
        {verifying ? 'Verifying...' : 'Verify Integrity'}
      </button>
      {status === 'verified' && (
        <span className="text-green-600">✓ Verified</span>
      )}
      {status === 'failed' && (
        <span className="text-red-600">✗ Tampered</span>
      )}
    </div>
  );
}
```

---

## WebSocket Integration (Real-Time Updates)

### `src/services/websocket.js`

```javascript
class WebSocketService {
  constructor() {
    this.ws = null;
    this.listeners = {};
  }

  connect(investigationId) {
    const wsUrl = `wss://192.168.148.154/ws/investigations/${investigationId}/`;
    this.ws = new WebSocket(wsUrl);

    this.ws.onopen = () => {
      console.log('WebSocket connected');
    };

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.emit(data.type, data.payload);
    };

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    this.ws.onclose = () => {
      console.log('WebSocket disconnected');
    };
  }

  on(event, callback) {
    if (!this.listeners[event]) {
      this.listeners[event] = [];
    }
    this.listeners[event].push(callback);
  }

  emit(event, data) {
    if (this.listeners[event]) {
      this.listeners[event].forEach(callback => callback(data));
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

export default new WebSocketService();
```

**Usage in Investigation Detail Page**:
```jsx
useEffect(() => {
  websocketService.connect(investigationId);

  websocketService.on('evidence_added', (data) => {
    // Refresh evidence list
    refetchEvidence();
    // Show notification
    toast.success(`New evidence added: ${data.file_name}`);
  });

  websocketService.on('note_added', (data) => {
    // Refresh notes
    refetchNotes();
  });

  return () => {
    websocketService.disconnect();
  };
}, [investigationId]);
```

---

## Summary

### Backend APIs Complete ✅
- All Django REST endpoints implemented
- RBAC permissions configured
- Django signals for automatic activity tracking
- Max 3 tags validation
- Certificate-based authentication ready

### Frontend Foundation Complete ✅
- Project structure created
- Dependencies configured (React, Vite, TailwindCSS, React Query)
- API client service with all endpoints
- Authentication context pattern
- Role-based routing structure

### Next Implementation Steps
1. **Run `npm install` in `frontend/` directory**
2. **Create remaining components** (following directory structure above)
3. **Test API integration** with mTLS certificates
4. **Add form validation** using React Hook Form
5. **Implement WebSocket** for real-time notifications
6. **Add charts** using Recharts (evidence upload frequency over time)
7. **Build export report** functionality (PDF/CSV generation)

### Development Workflow
```bash
# Terminal 1: Django backend
cd /opt/truefypjs/apps
python manage.py runserver 0.0.0.0:8080

# Terminal 2: React frontend
cd c:\Users\mosta\Desktop\FYP\JumpServer\truefypjs\frontend
npm run dev
```

Access:
- **Frontend Dev Server**: `http://localhost:3000` (auto-proxies API to backend)
- **Backend API**: `https://192.168.148.154/api/v1/blockchain/`

---

**END OF FRONTEND IMPLEMENTATION GUIDE**
