import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import InvestigatorDashboard from './InvestigatorDashboard';
import AuditorDashboard from './AuditorDashboard';
import CourtDashboard from './CourtDashboard';

/**
 * Main Dashboard Router
 *
 * Automatically routes users to their role-specific dashboard:
 * - System Admin → Admin Dashboard (/admin-dashboard)
 * - Investigator → Investigator Dashboard (assigned cases, full R/W)
 * - Auditor → Auditor Dashboard (assigned cases, read + notes)
 * - Court → Court Dashboard (all cases, read-only)
 */
export default function Dashboard() {
  const { isAdmin, isInvestigator, isAuditor, isCourt, loading } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    // Redirect admins to admin dashboard
    if (!loading && isAdmin()) {
      navigate('/admin-dashboard', { replace: true });
    }
  }, [isAdmin, loading, navigate]);

  // Show loading state
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  // Route to role-specific dashboard
  if (isAdmin()) {
    // Will redirect to admin dashboard via useEffect
    return null;
  } else if (isInvestigator()) {
    return <InvestigatorDashboard />;
  } else if (isAuditor()) {
    return <AuditorDashboard />;
  } else if (isCourt()) {
    return <CourtDashboard />;
  }

  // Fallback for users without blockchain roles
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center">
        <h2 className="text-2xl font-bold text-gray-900">No Dashboard Available</h2>
        <p className="mt-2 text-gray-600">
          You don't have a blockchain role assigned. Please contact your administrator.
        </p>
      </div>
    </div>
  );
}
