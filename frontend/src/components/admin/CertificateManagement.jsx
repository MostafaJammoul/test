import { useState } from 'react';
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
  const [confirmDialog, setConfirmDialog] = useState({ isOpen: false, title: '', message: '', onConfirm: null });
  const [revocationReason, setRevocationReason] = useState('');
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

  // Issue certificate mutation
  const issueMutation = useMutation({
    mutationFn: async (userId) => {
      const response = await apiClient.post('/pki/certificates/issue/', { user_id: userId });
      return response.data;
    },
    onSuccess: (data, userId) => {
      queryClient.invalidateQueries({ queryKey: ['certificates'] });

      // Trigger download
      const downloadUrl = data.download_url;
      window.location.href = downloadUrl;

      const user = users.find(u => u.id === userId);
      showToast(`Certificate issued to ${user?.username}. Download started.`, 'success');
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
        reason: reason || 'unspecified'
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

  const handleIssue = (user) => {
    setConfirmDialog({
      isOpen: true,
      title: 'Issue Certificate',
      message: `Issue mTLS certificate to "${user.username}"? The certificate will be downloaded as a .p12 file.`,
      confirmText: 'Issue & Download',
      variant: 'primary',
      onConfirm: () => {
        issueMutation.mutate(user.id);
        setConfirmDialog({ ...confirmDialog, isOpen: false });
      }
    });
  };

  const handleRevoke = (user, cert) => {
    setRevocationReason(''); // Reset reason field
    setConfirmDialog({
      isOpen: true,
      title: 'Revoke Certificate',
      message: `Revoke certificate for "${user.username}"? User will no longer be able to authenticate with this certificate.`,
      confirmText: 'Revoke',
      variant: 'danger',
      requireReason: true, // Flag to show reason input
      onConfirm: () => {
        revokeMutation.mutate({ certId: cert.id, reason: revocationReason });
        setConfirmDialog({ ...confirmDialog, isOpen: false });
      }
    });
  };

  // Get certificate for a user (valid, not expired, not revoked)
  const getUserCertificate = (userId) => {
    if (!certificates) return null;
    return certificates.find(cert =>
      cert.user === userId &&
      !cert.revoked &&
      cert.is_valid &&
      new Date(cert.not_after) > new Date()
    );
  };

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
            {revokedCertificates.length > 0 && (
              <span className="ml-2 bg-gray-200 text-gray-700 py-0.5 px-2 rounded-full text-xs">
                {revokedCertificates.length}
              </span>
            )}
          </button>
        </nav>
      </div>

      {/* Active Certificates Tab */}
      {activeTab === 'active' && (
        <div className="space-y-3">
          {users?.map((user) => {
            const cert = getUserCertificate(user.id);
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
                      <span>{user.email}</span>
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
                        onClick={async () => {
                          try {
                            const response = await apiClient.get(`/pki/certificates/${cert.id}/download/`, {
                              responseType: 'blob'
                            });
                            const blob = new Blob([response.data], { type: 'application/x-pkcs12' });
                            const url = window.URL.createObjectURL(blob);
                            const link = document.createElement('a');
                            link.href = url;
                            link.download = `${user.username}.p12`;
                            document.body.appendChild(link);
                            link.click();
                            document.body.removeChild(link);
                            window.URL.revokeObjectURL(url);
                            showToast('Certificate downloaded successfully', 'success');
                          } catch (error) {
                            showToast('Failed to download certificate', 'error');
                          }
                        }}
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

      {/* Revoked Certificates Tab */}
      {activeTab === 'revoked' && (
        <div className="space-y-3">
          {revokedCertificates.length === 0 ? (
            <div className="text-center py-12 text-gray-500">
              <XCircleIcon className="mx-auto h-12 w-12 text-gray-400 mb-3" />
              <p className="text-lg font-medium">No Revoked Certificates</p>
              <p className="text-sm mt-1">All certificates are currently active</p>
            </div>
          ) : (
            revokedCertificates.map((cert) => {
              const user = users?.find(u => u.id === cert.user);

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
                      <div className="text-sm text-gray-600 mt-1">
                        <div>
                          <span className="font-medium">User:</span> @{user?.username || 'N/A'}
                        </div>
                        <div>
                          <span className="font-medium">Serial:</span> {cert.serial_number}
                        </div>
                        <div>
                          <span className="font-medium">Revoked:</span>{' '}
                          {new Date(cert.revocation_date).toLocaleString()}
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
                  <div className="text-xs text-gray-500">
                    <div>Issued: {new Date(cert.not_before).toLocaleDateString()}</div>
                    <div>Expired: {new Date(cert.not_after).toLocaleDateString()}</div>
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* Confirmation Dialog with Reason Input */}
      <ConfirmDialog
        isOpen={confirmDialog.isOpen}
        onClose={() => setConfirmDialog({ ...confirmDialog, isOpen: false })}
        onConfirm={confirmDialog.onConfirm}
        title={confirmDialog.title}
        message={confirmDialog.message}
        confirmText={confirmDialog.confirmText}
        confirmVariant={confirmDialog.variant}
      >
        {confirmDialog.requireReason && (
          <div className="mt-4">
            <label htmlFor="revocation-reason" className="block text-sm font-medium text-gray-700 mb-2">
              Revocation Reason
            </label>
            <select
              id="revocation-reason"
              value={revocationReason}
              onChange={(e) => setRevocationReason(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary-500 focus:border-primary-500"
            >
              <option value="unspecified">Unspecified</option>
              <option value="key_compromise">Key Compromise</option>
              <option value="ca_compromise">CA Compromise</option>
              <option value="affiliation_changed">Affiliation Changed</option>
              <option value="superseded">Superseded</option>
              <option value="cessation_of_operation">Cessation of Operation</option>
            </select>
          </div>
        )}
      </ConfirmDialog>
    </Card>
  );
}
