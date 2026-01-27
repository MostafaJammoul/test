import { useState } from 'react';
import { useMutation, useQueryClient, useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { investigationAPI } from '../../services/api';
import apiClient from '../../services/api';

export default function CreateInvestigationModal({ isOpen, onClose }) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [formData, setFormData] = useState({
    case_number: '',
    title: '',
    description: '',
    assigned_investigators: [],
    assigned_auditors: [],
  });
  const [error, setError] = useState('');

  // Fetch users with blockchain roles for assignment
  const { data: users } = useQuery({
    queryKey: ['blockchain-users'],
    queryFn: async () => {
      const response = await apiClient.get('/users/users/', {
        params: {
          has_blockchain_role: true,
          page_size: 100,
        }
      });
      return response.data.results || response.data;
    },
    enabled: isOpen,
  });

  const createMutation = useMutation({
    mutationFn: async (data) => {
      const response = await investigationAPI.create(data);
      return response.data;
    },
    onSuccess: (data) => {
      queryClient.invalidateQueries(['investigations']);
      onClose();
      resetForm();
      // Navigate to the newly created investigation
      navigate(`/investigations/${data.id}`);
    },
    onError: (error) => {
      setError(error.response?.data?.error || 'Failed to create investigation');
    },
  });

  const resetForm = () => {
    setFormData({
      case_number: '',
      title: '',
      description: '',
      assigned_investigators: [],
      assigned_auditors: [],
    });
    setError('');
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!formData.case_number.trim()) {
      setError('Case number is required');
      return;
    }

    if (!formData.title.trim()) {
      setError('Title is required');
      return;
    }

    createMutation.mutate(formData);
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  const handleUserSelection = (userId, role) => {
    const field = role === 'investigator' ? 'assigned_investigators' : 'assigned_auditors';
    const currentSelections = formData[field];

    if (currentSelections.includes(userId)) {
      // Remove user
      setFormData({
        ...formData,
        [field]: currentSelections.filter(id => id !== userId),
      });
    } else {
      // Add user
      setFormData({
        ...formData,
        [field]: [...currentSelections, userId],
      });
    }
  };

  // Filter users by role (case-insensitive UUID comparison)
  const investigators = users?.filter(u =>
    u.system_roles?.some(r => r.id?.toLowerCase() === '00000000-0000-0000-0000-000000000008')
  ) || [];

  const auditors = users?.filter(u =>
    u.system_roles?.some(r => r.id?.toLowerCase() === '00000000-0000-0000-0000-000000000009')
  ) || [];

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Create New Investigation">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Case Number */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Case Number *
          </label>
          <input
            type="text"
            value={formData.case_number}
            onChange={(e) => setFormData({ ...formData, case_number: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="e.g., CASE-2024-001"
            required
          />
        </div>

        {/* Title */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Title *
          </label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Brief title of the investigation"
            required
          />
        </div>

        {/* Description */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Description
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            rows={4}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Detailed description of the investigation..."
          />
        </div>

        {/* Assign Investigators */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Assign Investigators
          </label>
          <div className="max-h-40 overflow-y-auto border border-gray-300 rounded-md p-2 space-y-1">
            {investigators.length > 0 ? (
              investigators.map((user) => (
                <label key={user.id} className="flex items-center space-x-2 p-2 hover:bg-gray-50 rounded cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.assigned_investigators.includes(user.id)}
                    onChange={() => handleUserSelection(user.id, 'investigator')}
                    className="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
                  />
                  <span className="text-sm">{user.name || user.username}</span>
                </label>
              ))
            ) : (
              <p className="text-sm text-gray-500 p-2">No investigators available</p>
            )}
          </div>
        </div>

        {/* Assign Auditors */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Assign Auditors
          </label>
          <div className="max-h-40 overflow-y-auto border border-gray-300 rounded-md p-2 space-y-1">
            {auditors.length > 0 ? (
              auditors.map((user) => (
                <label key={user.id} className="flex items-center space-x-2 p-2 hover:bg-gray-50 rounded cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.assigned_auditors.includes(user.id)}
                    onChange={() => handleUserSelection(user.id, 'auditor')}
                    className="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
                  />
                  <span className="text-sm">{user.name || user.username}</span>
                </label>
              ))
            ) : (
              <p className="text-sm text-gray-500 p-2">No auditors available</p>
            )}
          </div>
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
            disabled={createMutation.isPending}
          >
            {createMutation.isPending ? 'Creating...' : 'Create Investigation'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
