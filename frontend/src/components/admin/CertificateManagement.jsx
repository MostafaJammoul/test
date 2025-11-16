import { useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {  CheckCircleIcon, XCircleIcon } from '@heroicons/react/24/outline';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import ConfirmDialog from '../common/ConfirmDialog';
import { useToast } from '../../contexts/ToastContext';
import { useAuth } from '../../contexts/AuthContext';
import apiClient from '../../services/api';

export default function CertificateManagement() {
  const [confirmDialog, setConfirmDialog] = useState({
    isOpen: false,
    title: '',
    message: '',
    confirmText: '',
    confirmVariant: 'primary',
    type: null,
    requireReason: false,
    payload: null,
  });
  const [revocationReason, setRevocationReason] = useState('');
  const [activeSearch, setActiveSearch] = useState('');
  const [revokedSearch, setRevokedSearch] = useState('');
  const [activeTab, setActiveTab] = useState('active'); // 'active' or 'revoked'
  const queryClient = useQueryClient();
  const { showToast } = useToast();
  const { user: currentUser } = useAuth();

  // Fetch all users
  const { data: users, isLoading: usersLoading } = useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const response = await apiClient.get('/users/users/');
      return response.data;
    },
  });

  // Fetch all certificates
  const { data: certificates, isLoading: certsLoading } = useQuery({
    queryKey: ['certificates'],
    queryFn: async () => {
      const response = await apiClient.get('/pki/certificates/');
      return Array.isArray(response.data) ? response.data : response.data.results || [];
    },
  });

  const userMap = useMemo(() => {
    const map = new Map();
    if (users) {
      users.forEach((user) => map.set(user.id, user));
    }
    return map;
  }, [users]);

  const certificateMap = useMemo(() => {
    const map = new Map();
    if (certificates) {
      certificates.forEach((cert) => {
        const expiry = cert.not_after ? new Date(cert.not_after) : null;
        const isExpired = expiry ? expiry <= new Date() : false;
        if (!cert.revoked && cert.is_valid && !isExpired) {
          map.set(cert.user, cert);
        }
      });
    }
    return map;
  }, [certificates]);

  // Helper function to download certificate
  const downloadCertificate = async (certId, username) => {
    try {
      const response = await apiClient.get(`/pki/certificates/${certId}/download/`, {
        responseType: 'blob'
      });
      const blob = new Blob([response.data], { type: 'application/x-pkcs12' });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${username}.p12`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
      showToast(`Certificate downloaded successfully. Import password: (leave blank)`, 'success', 5000);
    } catch (error) {
      showToast('Failed to download certificate', 'error');
      throw error;
    }
  };

  // Issue certificate mutation
  const issueMutation = useMutation({
    mutationFn: async (userId) => {
      const response = await apiClient.post('/pki/certificates/issue/', { user_id: userId });
      return response.data;
    },
    onSuccess: async (data, userId) => {
      queryClient.invalidateQueries({ queryKey: ['certificates'] });

      const user = users?.find(u => u.id === userId);

      // Trigger download with proper authentication
      if (user) {
        try {
          await downloadCertificate(data.certificate_id, user.username);
        } catch (error) {
          showToast(`Certificate issued but download failed. Use "Download .p12" button.`, 'warning', 6000);
        }
      } else {
        showToast('Certificate issued. Unable to auto-download because user context is missing.', 'warning', 6000);
      }
    },
    onError: (error) => {
      const errorMsg = error.response?.data?.error || 'Failed to issue certificate';
      showToast(`Error: ${errorMsg}`, 'error', 6000);
    },
  });

  // Revoke certificate mutation
  const revokeMutation = useMutation({
    mutationFn: async ({ certId, reason }) => {
      const response = await apiClient.post(`/pki/certificates/${certId}/revoke/`, {
        reason
      });
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['certificates'] });
      setRevocationReason(''); // Clear the reason field
      showToast('Certificate revoked successfully!', 'success');
    },
    onError: (error) => {
      const errorMsg = error.response?.data?.error || 'Failed to revoke certificate';
      showToast(`Error: ${errorMsg}`, 'error', 6000);
    },
  });

  const closeConfirmDialog = () => {
    setConfirmDialog((prev) => ({ ...prev, isOpen: false }));
    setRevocationReason('');
  };

  const handleConfirmDialog = () => {
    if (!confirmDialog.isOpen) {
      return;
    }

    if (confirmDialog.type === 'issue' && confirmDialog.payload?.userId) {
      issueMutation.mutate(confirmDialog.payload.userId);
      closeConfirmDialog();
      return;
    }

    if (confirmDialog.type === 'revoke' && confirmDialog.payload?.certId) {
      const trimmedReason = revocationReason.trim();
      if (!trimmedReason) {
        showToast('Please enter a revocation reason before revoking.', 'warning');
        return;
      }
      revokeMutation.mutate({ certId: confirmDialog.payload.certId, reason: trimmedReason });
      closeConfirmDialog();
      return;
    }

    closeConfirmDialog();
  };

  const handleIssue = (user) => {
    setConfirmDialog({
      isOpen: true,
      title: 'Issue Certificate',
      message: `Issue mTLS certificate to "${user.username}"? The certificate will be downloaded as a .p12 file. When importing, leave the password field BLANK (just press Enter).`,
      confirmText: 'Issue & Download',
      confirmVariant: 'primary',
      type: 'issue',
      requireReason: false,
      payload: { userId: user.id },
    });
  };

  const handleRevoke = (user, cert) => {
    setRevocationReason(''); // Reset reason field
    setConfirmDialog({
      isOpen: true,
      title: 'Revoke Certificate',
      message: `Revoke certificate for "${user.username}"? User will no longer be able to authenticate with this certificate.`,
      confirmText: 'Revoke',
      confirmVariant: 'danger',
      requireReason: true, // Flag to show reason input
      type: 'revoke',
      payload: { certId: cert.id },
    });
  };

  const getUserCertificate = (userId) => certificateMap.get(userId);

  const filteredActiveUsers = useMemo(() => {
    if (!users) return [];
    const normalized = activeSearch.trim().toLowerCase();
    if (!normalized) return users;
    return users.filter((user) =>
      [user.username, user.name, user.email]
        .filter(Boolean)
        .some((field) => field.toString().toLowerCase().includes(normalized))
    );
  }, [users, activeSearch]);

  const sortedActiveUsers = useMemo(() => {
    const parseDate = (value) => (value ? new Date(value) : null);
    return filteredActiveUsers
      .map((user) => ({
        user,
        cert: certificateMap.get(user.id) || null,
      }))
      .sort((a, b) => {
        const hasCertA = !!a.cert;
        const hasCertB = !!b.cert;
        if (hasCertA && hasCertB) {
          const expiryDiff = new Date(a.cert.not_after) - new Date(b.cert.not_after);
          if (expiryDiff !== 0) return expiryDiff;
          return new Date(b.cert.not_before) - new Date(a.cert.not_before);
        }
        if (hasCertA) return -1;
        if (hasCertB) return 1;
        const createdA = parseDate(a.user.date_joined || a.user.created_at);
        const createdB = parseDate(b.user.date_joined || b.user.created_at);
        if (createdA && createdB) {
          return createdB - createdA;
        }
        return 0;
      });
  }, [filteredActiveUsers, certificateMap]);

  const revokedCertificatesView = useMemo(() => {
    if (!certificates) return [];
    const normalized = revokedSearch.trim().toLowerCase();
    const sorted = certificates
      .filter((cert) => cert.revoked)
      .sort((a, b) => {
        const dateA = new Date(a.revocation_date || a.updated_at || a.not_after || 0);
        const dateB = new Date(b.revocation_date || b.updated_at || b.not_after || 0);
        return dateB - dateA;
      });

    if (!normalized) {
      return sorted;
    }

    return sorted.filter((cert) => {
      const user = userMap.get(cert.user);
      const haystack = [
        cert.serial_number,
        cert.revocation_reason,
        user?.username,
        user?.name,
        user?.email,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return haystack.includes(normalized);
    });
  }, [certificates, userMap, revokedSearch]);

  if (usersLoading || certsLoading) {
    return (
      <Card title="Certificate Management">
        <div className="flex items-center justify-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          <span className="ml-3 text-gray-600">Loading...</span>
        </div>
      </Card>
    );
  }

  // Get revoked certificates
  const revokedCertificates = certificates?.filter(cert => cert.revoked) || [];

  return (
    <Card title="Certificate Management (mTLS)">
      {/* Sub-tabs */}
      <div className="border-b border-gray-200 mb-4">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('active')}
            className={`
              whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm transition-colors
              ${
                activeTab === 'active'
                  ? 'border-primary-500 text-primary-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }
            `}
          >
            Active Certificates
          </button>
          <button
            onClick={() => setActiveTab('revoked')}
            className={`
              whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm transition-colors
              ${
                activeTab === 'revoked'
                  ? 'border-primary-500 text-primary-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }
            `}
          >
            Revoked Certificates
          </button>
        </nav>
      </div>

      {/* Active Certificates Tab */}
      {activeTab === 'active' && (
        <>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-1">Search Certificates</label>
            <input
              type="text"
              value={activeSearch}
              onChange={(e) => setActiveSearch(e.target.value)}
              placeholder="Search by username, full name, or email"
              className="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            />
          </div>
          {sortedActiveUsers.length === 0 ? (
            <div className="text-center py-8 text-gray-500 border border-dashed border-gray-300 rounded-md">
              <p>No users match the current search.</p>
            </div>
          ) : (
            <div className="space-y-3">
              {sortedActiveUsers.map(({ user, cert }) => {
                const hasCert = !!cert;

                return (
                  <div
                    key={user.id}
                    className="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:border-primary-300 transition-colors"
                  >
                    {/* User Info */}
                    <div className="flex items-center space-x-4 flex-1">
                      <div className="flex-shrink-0">
                        <div className="h-10 w-10 rounded-full bg-primary-100 flex items-center justify-center">
                          <span className="text-primary-700 font-semibold text-lg">
                            {(user.name || user.username).charAt(0).toUpperCase()}
                          </span>
                        </div>
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center space-x-2">
                          <span className="font-medium text-gray-900">
                            {user.name || user.username}
                          </span>
                          {hasCert ? (
                            <CheckCircleIcon className="h-5 w-5 text-green-500" title="Has valid certificate" />
                          ) : (
                            <XCircleIcon className="h-5 w-5 text-gray-400" title="No certificate" />
                          )}
                        </div>
                        <div className="text-sm text-gray-500">
                          <span>@{user.username}</span>
                          <span className="mx-2">•</span>
                          <span>{user.email || 'No email'}</span>
                        </div>
                        {hasCert && (
                          <div className="text-xs text-gray-400 mt-1">
                            Expires: {new Date(cert.not_after).toLocaleDateString()}
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center space-x-2">
                      <Badge variant={hasCert ? 'success' : 'secondary'}>
                        {hasCert ? 'Certificate Issued' : 'No Certificate'}
                      </Badge>

                      {hasCert ? (
                        <>
                          <Button
                            variant="secondary"
                            size="sm"
                            onClick={() => downloadCertificate(cert.id, user.username)}
                          >
                            Download .p12
                          </Button>
                          {currentUser && user.id !== currentUser.id && (
                            <Button
                              variant="danger"
                              size="sm"
                              onClick={() => handleRevoke(user, cert)}
                              disabled={revokeMutation.isPending}
                            >
                              Revoke
                            </Button>
                          )}
                          {currentUser && user.id === currentUser.id && (
                            <span className="text-xs text-gray-500 italic px-2">
                              (Cannot revoke own certificate)
                            </span>
                          )}
                        </>
                      ) : (
                        <Button
                          variant="primary"
                          size="sm"
                          onClick={() => handleIssue(user)}
                          disabled={issueMutation.isPending}
                        >
                          Issue & Download
                        </Button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}

      {/* Revoked Certificates Tab */}
      {activeTab === 'revoked' && (
        <>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-1">Search Revoked Certificates</label>
            <input
              type="text"
              value={revokedSearch}
              onChange={(e) => setRevokedSearch(e.target.value)}
              placeholder="Search by username, email, serial, or reason"
              className="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            />
          </div>
          {revokedCertificatesView.length === 0 ? (
            <div className="text-center py-12 text-gray-500">
              <XCircleIcon className="mx-auto h-12 w-12 text-gray-400 mb-3" />
              <p className="text-lg font-medium">No Revoked Certificates</p>
              <p className="text-sm mt-1">All certificates are currently active</p>
            </div>
          ) : (
            revokedCertificatesView.map((cert) => {
              const user = userMap.get(cert.user);

              return (
                <div
                  key={cert.id}
                  className="flex items-center justify-between p-4 border border-red-200 bg-red-50 rounded-lg"
                >
                  <div className="flex items-center space-x-4 flex-1">
                    <div className="flex-shrink-0">
                      <div className="h-10 w-10 rounded-full bg-red-100 flex items-center justify-center">
                        <XCircleIcon className="h-6 w-6 text-red-600" />
                      </div>
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center space-x-2">
                        <span className="font-medium text-gray-900">
                          {user?.name || user?.username || 'Unknown User'}
                        </span>
                        <Badge variant="danger">Revoked</Badge>
                      </div>
                      <div className="text-sm text-gray-600 mt-1 space-y-1">
                        <div>
                          <span className="font-medium">User:</span> @{user?.username || 'N/A'}
                        </div>
                        <div>
                          <span className="font-medium">Email:</span> {user?.email || 'N/A'}
                        </div>
                        <div>
                          <span className="font-medium">Serial:</span> {cert.serial_number}
                        </div>
                        <div>
                          <span className="font-medium">Revoked:</span>{' '}
                          {cert.revocation_date ? new Date(cert.revocation_date).toLocaleString() : 'Unknown'}
                        </div>
                        {cert.revocation_reason && (
                          <div>
                            <span className="font-medium">Reason:</span>{' '}
                            <span className="text-red-700">{cert.revocation_reason}</span>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="text-xs text-gray-500 text-right">
                    <div>Issued: {new Date(cert.not_before).toLocaleDateString()}</div>
                    <div>Expired: {new Date(cert.not_after).toLocaleDateString()}</div>
                  </div>
                </div>
              );
            })
          )}
        </>
      )}

      {/* Confirmation Dialog with Reason Input */}
      <ConfirmDialog
        isOpen={confirmDialog.isOpen}
        onClose={closeConfirmDialog}
        onConfirm={handleConfirmDialog}
        title={confirmDialog.title}
        message={confirmDialog.message}
        confirmText={confirmDialog.confirmText}
        confirmVariant={confirmDialog.confirmVariant}
      >
        {confirmDialog.requireReason && (
          <div className="mt-4">
            <label htmlFor="revocation-reason" className="block text-sm font-medium text-gray-700 mb-2">
              Revocation Reason
            </label>
            <textarea
              id="revocation-reason"
              value={revocationReason}
              onChange={(e) => setRevocationReason(e.target.value)}
              rows={3}
              placeholder="Describe why this certificate is being revoked..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary-500 focus:border-primary-500"
            />
            <p className="mt-1 text-xs text-gray-500">
              This reason is stored on the certificate and displayed under the Revoked Certificates tab.
            </p>
          </div>
        )}
      </ConfirmDialog>
    </Card>
  );
}
