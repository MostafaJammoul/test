import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import Modal from '../common/Modal';
import { ROLE_NAMES, ROLES } from '../../utils/constants';
import apiClient from '../../services/api';

export default function UserManagement() {
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const queryClient = useQueryClient();

  const { data: users, isLoading } = useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const response = await apiClient.get('/users/users/');
      return response.data.results;
    },
  });

  const createMutation = useMutation({
    mutationFn: async (userData) => {
      console.log('Submitting user creation request...');
      const response = await apiClient.post('/users/users/', userData);
      console.log('User created successfully:', response.data);
      return response;
    },
    onSuccess: (response) => {
      console.log('User creation mutation successful');
      queryClient.invalidateQueries({ queryKey: ['users'] });
      setIsCreateModalOpen(false);
      alert(`User "${response.data.username}" created successfully!`);
    },
    onError: (error) => {
      console.error('User creation failed:', error);
      console.error('Error response:', error.response?.data);

      // Extract all validation errors
      const errorData = error.response?.data || {};
      let errorMessage = errorData.error || errorData.detail || 'Failed to create user';

      // Check for field-specific validation errors
      const fieldErrors = [];
      for (const [field, errors] of Object.entries(errorData)) {
        if (Array.isArray(errors)) {
          fieldErrors.push(`${field}: ${errors.join(', ')}`);
        } else if (typeof errors === 'string' && !['error', 'detail'].includes(field)) {
          fieldErrors.push(`${field}: ${errors}`);
        }
      }

      if (fieldErrors.length > 0) {
        errorMessage = fieldErrors.join('\n');
      }

      alert(`Error creating user:\n\n${errorMessage}`);
    },
  });

  const deactivateMutation = useMutation({
    mutationFn: async (userId) => {
      return apiClient.patch(`/users/users/${userId}/`, { is_active: false });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });

  if (isLoading) return <div>Loading...</div>;

  return (
    <Card
      title="User Management"
      actions={
        <Button onClick={() => setIsCreateModalOpen(true)}>Create User</Button>
      }
    >
      <div className="space-y-2">
        {users?.map((user) => (
          <div
            key={user.id}
            className="flex items-center justify-between p-3 border border-gray-200 rounded-md"
          >
            <div className="flex items-center space-x-3">
              <div>
                <div className="font-medium">{user.name || user.username}</div>
                <div className="text-sm text-gray-500">{user.email}</div>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <Badge variant={user.is_active ? 'success' : 'danger'}>
                {user.is_active ? 'Active' : 'Inactive'}
              </Badge>
              {user.is_active && (
                <Button
                  variant="danger"
                  size="sm"
                  onClick={() => {
                    if (confirm(`Deactivate user "${user.username}"?`)) {
                      deactivateMutation.mutate(user.id);
                    }
                  }}
                >
                  Deactivate
                </Button>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Create User Modal */}
      <Modal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        title="Create User"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setIsCreateModalOpen(false)}
              disabled={createMutation.isPending}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              form="create-user-form"
              loading={createMutation.isPending}
            >
              Create User
            </Button>
          </>
        }
      >
        <UserCreateForm
          onSubmit={(data) => {
            // Map frontend role to system_roles UUIDs
            let system_roles = [];
            switch (data.role) {
              case 'Admin':
                system_roles = [ROLES.SYSTEM_ADMIN];
                break;
              case 'Auditor':
                system_roles = [ROLES.BLOCKCHAIN_AUDITOR];
                break;
              case 'User':
              default:
                // Regular user, no special roles
                system_roles = [];
                break;
            }

            // Prepare user data for API
            const userData = {
              username: data.username,
              name: data.name,
              email: data.email,
              password: data.password,
              password_strategy: 'custom',  // ✓ CRITICAL: Tell Django to use the password we provide
              is_active: data.is_active,
              system_roles: system_roles,
            };

            console.log('Creating user with data:', { ...userData, password: '[REDACTED]' });
            createMutation.mutate(userData);
          }}
          formId="create-user-form"
          isLoading={createMutation.isPending}
        />
      </Modal>
    </Card>
  );
}

function UserCreateForm({ onSubmit, formId, isLoading }) {
  const [formData, setFormData] = useState({
    username: '',
    name: '',
    email: '',
    password: '',
    role: 'User',
    is_active: true,
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form id={formId} onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">Username *</label>
        <input
          type="text"
          required
          value={formData.username}
          onChange={(e) => setFormData({ ...formData, username: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          placeholder="john.doe"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Full Name *</label>
        <input
          type="text"
          required
          value={formData.name}
          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          placeholder="John Doe"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Email *</label>
        <input
          type="email"
          required
          value={formData.email}
          onChange={(e) => setFormData({ ...formData, email: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          placeholder="john.doe@example.com"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Password *</label>
        <input
          type="password"
          required
          minLength={8}
          value={formData.password}
          onChange={(e) => setFormData({ ...formData, password: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          placeholder="Minimum 8 characters"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Role *</label>
        <select
          value={formData.role}
          onChange={(e) => setFormData({ ...formData, role: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        >
          <option value="User">User (No blockchain access)</option>
          <option value="Admin">System Admin (Full access)</option>
          <option value="Auditor">Auditor (Read-only blockchain)</option>
        </select>
        <p className="mt-1 text-xs text-gray-500">
          Note: Investigator and Court roles must be assigned via Django Admin after user creation
        </p>
      </div>

      <div className="flex items-center">
        <input
          type="checkbox"
          checked={formData.is_active}
          onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
          className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
        />
        <label className="ml-2 block text-sm text-gray-900">
          Active (User can log in)
        </label>
      </div>
    </form>
  );
}
