import { createContext, useContext, useState, useEffect } from 'react';
import apiClient from '../services/api';
import { ROLES } from '../utils/constants';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [mfaStatus, setMfaStatus] = useState(null);

  // Check authentication and MFA status on mount
  useEffect(() => {
    const checkAuth = async () => {
      try {
        // Try to get current user (will fail if not authenticated)
        const userResponse = await apiClient.get('/users/me/');

        // User is authenticated, check MFA status
        const statusResponse = await apiClient.get('/authentication/mfa/status/');
        const status = statusResponse.data;
        setMfaStatus(status);

        // If password auth, MFA is optional - skip MFA checks
        if (status.auth_method === 'password') {
          setUser(userResponse.data);
          setLoading(false);
          return;
        }

        // Certificate auth requires MFA
        if (status.needs_setup) {
          setLoading(false);
          if (
            window.location.pathname !== '/setup-mfa' &&
            !window.location.pathname.startsWith('/admin')
          ) {
            window.location.href = '/setup-mfa';
          }
          return;
        }

        if (!status.mfa_verified) {
          setLoading(false);
          if (
            window.location.pathname !== '/mfa-challenge' &&
            !window.location.pathname.startsWith('/admin')
          ) {
            window.location.href = '/mfa-challenge';
          }
          return;
        }

        // MFA verified or not required, set user
        setUser(userResponse.data);
      } catch (error) {
        // Not authenticated - redirect to login page
        console.log('Not authenticated, showing login page');
        setUser(null);
        setMfaStatus(null);

        // Don't redirect if already on allowed pages
        const publicPages = ['/admin', '/setup-mfa', '/mfa-challenge'];
        const adminOnlyRoutes = ['/admin', '/admin-dashboard'];
        const currentPath = window.location.pathname;
        const isAdminArea = adminOnlyRoutes.some((path) =>
          currentPath.startsWith(path)
        );
        if (isAdminArea && currentPath !== '/admin') {
          window.location.href = '/admin';
        } else if (publicPages.includes(currentPath)) {
          // stay on the current page
        }
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  // Verify MFA TOTP code
  const verifyMFA = async (code) => {
    try {
      // Verify MFA code - backend returns token + user data
      const response = await apiClient.post('/authentication/mfa/verify-totp/', { code });

      // Extract and store the authentication token
      const { token, user: userData } = response.data;
      if (token) {
        localStorage.setItem('auth_token', token);
      }

      // Set user data from response (no need to fetch again)
      setUser(userData);
      setMfaStatus({ ...mfaStatus, mfa_verified: true });

      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error.response?.data?.error || 'Invalid MFA code'
      };
    }
  };

  // Get user roles (array of role IDs)
  const getUserRoles = () => {
    if (!user?.system_roles) return [];
    return user.system_roles.map(r => r.id);
  };

  // Check if user has specific role
  const hasRole = (roleId) => getUserRoles().includes(roleId);

  // Check if user has admin role
  const isAdmin = () => hasRole(ROLES.SYSTEM_ADMIN);

  // Check if user is investigator
  const isInvestigator = () => hasRole(ROLES.BLOCKCHAIN_INVESTIGATOR);

  // Check if user is auditor
  const isAuditor = () => hasRole(ROLES.BLOCKCHAIN_AUDITOR);

  // Check if user is court
  const isCourt = () => hasRole(ROLES.BLOCKCHAIN_COURT);

  // Logout function
  const logout = async () => {
    const wasAdmin = isAdmin();
    try {
      await apiClient.post('/authentication/logout/');
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      // Clear authentication token
      localStorage.removeItem('auth_token');
      setUser(null);
      setMfaStatus(null);
      window.location.href = wasAdmin ? '/admin' : '/';
    }
  };

  const value = {
    user,
    loading,
    mfaStatus,
    verifyMFA,
    logout,
    getUserRoles,
    hasRole,
    isAdmin,
    isInvestigator,
    isAuditor,
    isCourt,
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
