import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { guidAPI } from '../../services/api';

export default function GUIDResolutionModal({ isOpen, onClose }) {
  const [formData, setFormData] = useState({
    guid: '',
    reason: '',
  });
  const [resolvedUser, setResolvedUser] = useState(null);
  const [error, setError] = useState('');

  const resolveMutation = useMutation({
    mutationFn: async (data) => {
      const response = await guidAPI.resolve(data.guid, data.reason);
      return response.data;
    },
    onSuccess: (data) => {
      setResolvedUser(data);
      setError('');
    },
    onError: (error) => {
      setError(error.response?.data?.error || 'Failed to resolve GUID');
      setResolvedUser(null);
    },
  });

  const resetForm = () => {
    setFormData({
      guid: '',
      reason: '',
    });
    setResolvedUser(null);
    setError('');
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!formData.guid.trim()) {
      setError('GUID is required');
      return;
    }

    if (!formData.reason.trim()) {
      setError('Legal reason is required');
      return;
    }

    resolveMutation.mutate(formData);
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Resolve Anonymous GUID">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Warning Banner */}
        <div className="rounded-md bg-yellow-50 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <h3 className="text-sm font-medium text-yellow-800">
                Sensitive Operation
              </h3>
              <div className="mt-2 text-sm text-yellow-700">
                <p>
                  GUID resolution unmasks anonymous investigators. This action is logged
                  to the blockchain and requires a valid legal reason.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* GUID Input */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Anonymous GUID *
          </label>
          <input
            type="text"
            value={formData.guid}
            onChange={(e) => setFormData({ ...formData, guid: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 font-mono text-sm"
            placeholder="e.g., 550e8400-e29b-41d4-a716-446655440000"
            required
          />
        </div>

        {/* Legal Reason */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Legal Reason for Resolution *
          </label>
          <textarea
            value={formData.reason}
            onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
            rows={3}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Court order number, case reference, legal justification..."
            required
          />
          <p className="mt-1 text-sm text-gray-500">
            This reason will be permanently logged to the blockchain audit trail.
          </p>
        </div>

        {/* Resolved User Display */}
        {resolvedUser && (
          <div className="rounded-md bg-green-50 p-4">
            <div className="flex">
              <div className="flex-shrink-0">
                <svg className="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h3 className="text-sm font-medium text-green-800">
                  GUID Resolved Successfully
                </h3>
                <div className="mt-2 text-sm text-green-700">
                  <dl className="space-y-1">
                    <div>
                      <dt className="inline font-semibold">User ID:</dt>
                      <dd className="inline ml-2">{resolvedUser.user_id}</dd>
                    </div>
                    <div>
                      <dt className="inline font-semibold">Username:</dt>
                      <dd className="inline ml-2">{resolvedUser.username}</dd>
                    </div>
                    <div>
                      <dt className="inline font-semibold">Name:</dt>
                      <dd className="inline ml-2">{resolvedUser.name || 'N/A'}</dd>
                    </div>
                    <div>
                      <dt className="inline font-semibold">Organization:</dt>
                      <dd className="inline ml-2">{resolvedUser.organization || 'N/A'}</dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Error Message */}
        {error && (
          <div className="rounded-md bg-red-50 p-4">
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex justify-end space-x-3 pt-4">
          <Button type="button" variant="secondary" onClick={handleClose}>
            {resolvedUser ? 'Close' : 'Cancel'}
          </Button>
          {!resolvedUser && (
            <Button
              type="submit"
              variant="primary"
              disabled={resolveMutation.isPending}
            >
              {resolveMutation.isPending ? 'Resolving...' : 'Resolve GUID'}
            </Button>
          )}
        </div>
      </form>
    </Modal>
  );
}
