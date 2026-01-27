import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { investigationAPI } from '../../services/api';

export default function ReopenInvestigationModal({ isOpen, onClose, investigation }) {
  const queryClient = useQueryClient();
  const [reason, setReason] = useState('');
  const [error, setError] = useState('');

  const reopenMutation = useMutation({
    mutationFn: async () => {
      const response = await investigationAPI.reopen(investigation.id, reason);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['investigation', investigation.id]);
      queryClient.invalidateQueries(['investigations']);
      onClose();
      resetForm();
    },
    onError: (error) => {
      setError(error.response?.data?.error || 'Failed to reopen investigation');
    },
  });

  const resetForm = () => {
    setReason('');
    setError('');
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!reason.trim()) {
      setError('Reopen reason is required');
      return;
    }

    reopenMutation.mutate();
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Reopen Investigation">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Warning Banner */}
        <div className="rounded-md bg-blue-50 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <h3 className="text-sm font-medium text-blue-800">
                Restore from Cold Chain
              </h3>
              <div className="mt-2 text-sm text-blue-700">
                <p>
                  Reopening will restore this investigation from the cold chain back to
                  the hot chain. This requires court authorization and will be logged to the blockchain.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Investigation Details */}
        <div className="bg-gray-50 rounded-md p-4">
          <dl className="space-y-2 text-sm">
            <div>
              <dt className="inline font-semibold text-gray-700">Case Number:</dt>
              <dd className="inline ml-2 text-gray-900">{investigation.case_number}</dd>
            </div>
            <div>
              <dt className="inline font-semibold text-gray-700">Title:</dt>
              <dd className="inline ml-2 text-gray-900">{investigation.title}</dd>
            </div>
            <div>
              <dt className="inline font-semibold text-gray-700">Status:</dt>
              <dd className="inline ml-2 text-gray-900 capitalize">{investigation.status}</dd>
            </div>
          </dl>
        </div>

        {/* Reopen Reason */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Court Order / Legal Reason *
          </label>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={4}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Court order number, new evidence discovered, appeal granted, legal justification..."
            required
          />
          <p className="mt-1 text-sm text-gray-500">
            This reason will be permanently logged to the blockchain.
          </p>
        </div>

        {/* Error Message */}
        {error && (
          <div className="rounded-md bg-red-50 p-4">
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex justify-end space-x-3 pt-4">
          <Button type="button" variant="secondary" onClick={handleClose}>
            Cancel
          </Button>
          <Button
            type="submit"
            variant="primary"
            disabled={reopenMutation.isPending}
          >
            {reopenMutation.isPending ? 'Reopening...' : 'Reopen Investigation'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
