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
      >
        <p className="text-gray-600">
          User creation form will be implemented here. For now, use Django admin panel.
        </p>
        <div className="mt-4">
          <Button variant="secondary" onClick={() => setIsCreateModalOpen(false)}>
            Close
          </Button>
        </div>
      </Modal>
    </Card>
  );
}
