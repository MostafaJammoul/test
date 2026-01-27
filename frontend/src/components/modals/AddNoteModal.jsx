import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { noteAPI } from '../../services/api';

export default function AddNoteModal({ isOpen, onClose, investigationId }) {
  const queryClient = useQueryClient();
  const [content, setContent] = useState('');
  const [error, setError] = useState('');

  const addNoteMutation = useMutation({
    mutationFn: async (noteContent) => {
      const response = await noteAPI.create(investigationId, noteContent);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['investigation', investigationId]);
      queryClient.invalidateQueries(['notes']);
      onClose();
      resetForm();
    },
    onError: (error) => {
      setError(error.response?.data?.error || 'Failed to add note');
    },
  });

  const resetForm = () => {
    setContent('');
    setError('');
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!content.trim()) {
      setError('Note content cannot be empty');
      return;
    }

    addNoteMutation.mutate(content);
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Add Investigation Note">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Note Content */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Note Content *
          </label>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={6}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Add your investigative notes, observations, or updates..."
            required
          />
          <p className="mt-1 text-sm text-gray-500">
            Notes are logged to the blockchain and cannot be edited or deleted.
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
            disabled={addNoteMutation.isPending}
          >
            {addNoteMutation.isPending ? 'Adding...' : 'Add Note'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
