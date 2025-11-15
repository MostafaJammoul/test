import { Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { ToastProvider } from './contexts/ToastContext';
import Login from './pages/Login';
import MFASetup from './pages/MFASetup';
import MFAChallenge from './pages/MFAChallenge';
import AdminDashboard from './pages/admin/AdminDashboard';
import Dashboard from './pages/dashboard/Dashboard';
import InvestigationListPage from './pages/dashboard/InvestigationListPage';
import InvestigationDetailPage from './pages/dashboard/InvestigationDetailPage';
import NotFound from './pages/NotFound';

// Loading spinner component
const LoadingSpinner = () => (
  <div className="min-h-screen flex items-center justify-center bg-gray-50">
    <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
  </div>
);

// Protected route wrapper
const ProtectedRoute = ({ children, requireAdmin = false }) => {
  const { user, loading, mfaStatus, isAdmin } = useAuth();

  if (loading) return <LoadingSpinner />;

  // User not authenticated - redirect to login
  if (!user) return <Navigate to="/login" replace />;

  // Password auth - MFA not required, skip MFA checks
  if (mfaStatus?.auth_method === 'password') {
    // Check admin requirement
    if (requireAdmin && !isAdmin()) return <Navigate to="/dashboard" replace />;
    return children;
  }

  // Certificate auth - MFA required
  if (mfaStatus?.needs_setup) return <Navigate to="/setup-mfa" replace />;
  if (!mfaStatus?.mfa_verified) return <Navigate to="/mfa-challenge" replace />;

  // Admin-only route
  if (requireAdmin && !isAdmin()) return <Navigate to="/dashboard" replace />;

  return children;
};

function AppRoutes() {
  return (
    <Routes>
      {/* Login Page (password authentication) */}
      <Route path="/login" element={<Login />} />

      {/* MFA Setup Page (first-time enrollment) */}
      <Route path="/setup-mfa" element={<MFASetup />} />

      {/* MFA Challenge Page (login verification) */}
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

      {/* Investigation List Page */}
      <Route
        path="/investigations"
        element={
          <ProtectedRoute>
            <InvestigationListPage />
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
      <ToastProvider>
        <AppRoutes />
      </ToastProvider>
    </AuthProvider>
  );
}

export default App;
