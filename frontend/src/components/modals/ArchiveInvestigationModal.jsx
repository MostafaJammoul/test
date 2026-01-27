import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { investigationAPI } from '../../services/api';

export default function ArchiveInvestigationModal({ isOpen, onClose, investigation }) {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [reason, setReason] = useState('');
  const [error, setError] = useState('');

  const archiveMutation = useMutation({
    mutationFn: async () => {
      const response = await investigationAPI.archive(investigation.id, reason);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['investigation', investigation.id]);
      queryClient.invalidateQueries(['investigations']);
      onClose();
      resetForm();
      // Navigate back to investigations list
      navigate('/investigations');
    },
    onError: (error) => {
      setError(error.response?.data?.error || 'Failed to archive investigation');
    },
  });

  const resetForm = () => {
    setReason('');
    setError('');
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!reason.trim()) {
      setError('Archive reason is required');
      return;
    }

    archiveMutation.mutate();
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Archive Investigation">
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
                Important: Archive to Cold Chain
              </h3>
              <div className="mt-2 text-sm text-yellow-700">
                <p>
                  Archiving will move this investigation and all evidence from the hot chain
                  to the cold chain blockchain. This action is permanent and requires court authorization.
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
              <dt className="inline font-semibold text-gray-700">Evidence Items:</dt>
              <dd className="inline ml-2 text-gray-900">{investigation.evidence_count || 0}</dd>
            </div>
          </dl>
        </div>

        {/* Archive Reason */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Court Order / Legal Reason *
          </label>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={4}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Court order number, case closure reason, legal justification for archival..."
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
            variant="danger"
            disabled={archiveMutation.isPending}
          >
            {archiveMutation.isPending ? 'Archiving...' : 'Archive Investigation'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
