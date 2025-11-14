import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {  CheckCircleIcon, XCircleIcon } from '@heroicons/react/24/outline';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import ConfirmDialog from '../common/ConfirmDialog';
import { useToast } from '../../contexts/ToastContext';
import apiClient from '../../services/api';

export default function CertificateManagement() {
  const [confirmDialog, setConfirmDialog] = useState({ isOpen: false, title: '', message: '', onConfirm: null });
  const queryClient = useQueryClient();
  const { showToast } = useToast();

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
    mutationFn: async (certId) => {
      const response = await apiClient.post(`/pki/certificates/${certId}/revoke/`, {
        reason: 'unspecified'
      });
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['certificates'] });
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
    setConfirmDialog({
      isOpen: true,
      title: 'Revoke Certificate',
      message: `Revoke certificate for "${user.username}"? User will no longer be able to authenticate with this certificate.`,
      confirmText: 'Revoke',
      variant: 'danger',
      onConfirm: () => {
        revokeMutation.mutate(cert.id);
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

  return (
    <Card title="Certificate Management (mTLS)">
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
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() => handleRevoke(user, cert)}
                    disabled={revokeMutation.isPending}
                  >
                    Revoke Certificate
                  </Button>
                ) : (
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={() => handleIssue(user)}
                    disabled={issueMutation.isPending}
                  >
                    Issue & Download Certificate
                  </Button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Confirmation Dialog */}
      <ConfirmDialog
        isOpen={confirmDialog.isOpen}
        onClose={() => setConfirmDialog({ ...confirmDialog, isOpen: false })}
        onConfirm={confirmDialog.onConfirm}
        title={confirmDialog.title}
        message={confirmDialog.message}
        confirmText={confirmDialog.confirmText}
        confirmVariant={confirmDialog.variant}
      />
    </Card>
  );
}
