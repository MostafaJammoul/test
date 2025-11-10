/**
 * API Client Service
 * Handles all HTTP requests to Django backend with mTLS authentication
 */
import axios from 'axios';

// Base API URL (proxied through Vite dev server or nginx in production)
const API_BASE_URL = '/api/v1';

// Create axios instance with default config
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // Include cookies for session authentication
});

// Request interceptor (add auth token if needed)
apiClient.interceptors.request.use(
  (config) => {
    // Session-based auth with mTLS, no need for Bearer token
    // Cookies automatically sent with withCredentials: true
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor (handle errors globally)
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      // Server responded with error status
      const { status, data } = error.response;

      if (status === 401) {
        // Unauthorized - redirect to login or MFA challenge
        console.error('Authentication required');
        // TODO: Redirect to MFA challenge page if mtls_mfa_required
      } else if (status === 403) {
        // Forbidden - insufficient permissions
        console.error('Insufficient permissions:', data.error);
      } else if (status === 404) {
        console.error('Resource not found:', data.error);
      } else if (status === 400) {
        console.error('Validation error:', data.error);
      }
    } else if (error.request) {
      // Request sent but no response
      console.error('Network error - no response from server');
    } else {
      console.error('Request setup error:', error.message);
    }

    return Promise.reject(error);
  }
);

// ============================================================================
// INVESTIGATION APIs
// ============================================================================

export const investigationAPI = {
  // List investigations
  list: (params = {}) => apiClient.get('/blockchain/investigations/', { params }),

  // Get single investigation
  get: (id) => apiClient.get(`/blockchain/investigations/${id}/`),

  // Create investigation (Court only)
  create: (data) => apiClient.post('/blockchain/investigations/', data),

  // Update investigation
  update: (id, data) => apiClient.put(`/blockchain/investigations/${id}/`, data),

  // Archive investigation (Court only)
  archive: (id, reason) => apiClient.post(`/blockchain/investigations/${id}/archive/`, { reason }),

  // Reopen investigation (Court only)
  reopen: (id, reason) => apiClient.post(`/blockchain/investigations/${id}/reopen/`, { reason }),
};

// ============================================================================
// EVIDENCE APIs
// ============================================================================

export const evidenceAPI = {
  // List evidence
  list: (params = {}) => apiClient.get('/blockchain/evidence/', { params }),

  // Get single evidence
  get: (id) => apiClient.get(`/blockchain/evidence/${id}/`),

  // Upload evidence (Investigator only)
  upload: (formData) => apiClient.post('/blockchain/evidence/', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),

  // Download evidence
  download: (id) => apiClient.get(`/blockchain/evidence/${id}/download/`, {
    responseType: 'blob',
  }),

  // Verify evidence integrity
  verify: (id) => apiClient.get(`/blockchain/evidence/${id}/verify/`),
};

// ============================================================================
// TAG APIs
// ============================================================================

export const tagAPI = {
  // List all tags
  list: (params = {}) => apiClient.get('/blockchain/tags/', { params }),

  // Create tag (Admin only)
  create: (data) => apiClient.post('/blockchain/tags/', data),

  // Update tag (Admin only)
  update: (id, data) => apiClient.put(`/blockchain/tags/${id}/`, data),

  // Delete tag (Admin only)
  delete: (id) => apiClient.delete(`/blockchain/tags/${id}/`),
};

// ============================================================================
// INVESTIGATION TAG APIs
// ============================================================================

export const investigationTagAPI = {
  // List tag assignments
  list: (params = {}) => apiClient.get('/blockchain/investigation-tags/', { params }),

  // Assign tag to investigation (Court only)
  assign: (investigationId, tagId) => apiClient.post('/blockchain/investigation-tags/', {
    investigation: investigationId,
    tag: tagId,
  }),

  // Remove tag from investigation (Court only)
  remove: (id) => apiClient.delete(`/blockchain/investigation-tags/${id}/`),
};

// ============================================================================
// NOTE APIs
// ============================================================================

export const noteAPI = {
  // List notes
  list: (params = {}) => apiClient.get('/blockchain/notes/', { params }),

  // Create note (Investigator only)
  create: (investigationId, content) => apiClient.post('/blockchain/notes/', {
    investigation: investigationId,
    content,
  }),
};

// ============================================================================
// ACTIVITY APIs
// ============================================================================

export const activityAPI = {
  // List activities
  list: (params = {}) => apiClient.get('/blockchain/activities/', { params }),

  // Mark activity as viewed
  markViewed: (id) => apiClient.post(`/blockchain/activities/${id}/mark_viewed/`),
};

// ============================================================================
// BLOCKCHAIN TRANSACTION APIs
// ============================================================================

export const transactionAPI = {
  // List transactions
  list: (params = {}) => apiClient.get('/blockchain/transactions/', { params }),

  // Get single transaction
  get: (id) => apiClient.get(`/blockchain/transactions/${id}/`),
};

// ============================================================================
// GUID RESOLUTION APIs
// ============================================================================

export const guidAPI = {
  // Resolve GUID to user identity (Court only)
  resolve: (guid, reason) => apiClient.post('/blockchain/guid/resolve/', { guid, reason }),
};

// ============================================================================
// USER/AUTH APIs
// ============================================================================

export const userAPI = {
  // Get current user profile
  me: () => apiClient.get('/users/me/'),

  // Check MFA status
  mfaStatus: () => apiClient.get('/authentication/mfa/status/'),

  // Verify MFA code
  mfaVerify: (code) => apiClient.post('/authentication/mfa/verify/', { code }),
};

export default apiClient;
