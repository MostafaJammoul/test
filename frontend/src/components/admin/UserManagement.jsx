import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import Modal from '../common/Modal';
import { ROLE_NAMES } from '../../utils/constants';
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
            <Button variant="secondary" onClick={() => setIsCreateModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" form="create-user-form">
              Create User
            </Button>
          </>
        }
      >
        <UserCreateForm
          onSubmit={(data) => {
            // TODO: Implement user creation API call
            console.log('Creating user:', data);
            alert('User creation will be implemented. For now, use Django Admin at http://192.168.148.154:8080/admin');
            setIsCreateModalOpen(false);
          }}
          formId="create-user-form"
        />
      </Modal>
    </Card>
  );
}

function UserCreateForm({ onSubmit, formId }) {
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
