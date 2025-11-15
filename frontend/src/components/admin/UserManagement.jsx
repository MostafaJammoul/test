import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import Modal from '../common/Modal';
import ConfirmDialog from '../common/ConfirmDialog';
import { useToast } from '../../contexts/ToastContext';
import { useAuth } from '../../contexts/AuthContext';
import { ROLE_NAMES, ROLES } from '../../utils/constants';
import apiClient from '../../services/api';

export default function UserManagement() {
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [isViewModalOpen, setIsViewModalOpen] = useState(false);
  const [confirmDialog, setConfirmDialog] = useState({ isOpen: false, title: '', message: '', onConfirm: null, variant: 'primary' });
  const queryClient = useQueryClient();
  const { showToast } = useToast();
  const { user: currentUser } = useAuth();

  const { data: users, isLoading } = useQuery({
    queryKey: ['users'],
    queryFn: async () => {
      const response = await apiClient.get('/users/users/');
      // API returns array directly, not paginated {results: [...]}
      console.log('Users loaded:', response.data);
      return response.data;
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
      showToast(`User "${response.data.username}" created successfully!`, 'success');
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
        errorMessage = fieldErrors.join(', ');
      }

      showToast(`Error creating user: ${errorMessage}`, 'error', 6000);
    },
  });

  const updateMutation = useMutation({
    mutationFn: async ({ userId, data }) => {
      console.log('Updating user:', userId, data);
      const response = await apiClient.patch(`/users/users/${userId}/`, data);
      console.log('User updated successfully:', response.data);
      return response;
    },
    onSuccess: (response) => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      setIsEditModalOpen(false);
      setSelectedUser(null);
      showToast(`User "${response.data.username}" updated successfully!`, 'success');
    },
    onError: (error) => {
      console.error('User update failed:', error);
      const errorData = error.response?.data || {};
      let errorMessage = errorData.error || errorData.detail || 'Failed to update user';

      const fieldErrors = [];
      for (const [field, errors] of Object.entries(errorData)) {
        if (Array.isArray(errors)) {
          fieldErrors.push(`${field}: ${errors.join(', ')}`);
        } else if (typeof errors === 'string' && !['error', 'detail'].includes(field)) {
          fieldErrors.push(`${field}: ${errors}`);
        }
      }

      if (fieldErrors.length > 0) {
        errorMessage = fieldErrors.join(', ');
      }

      showToast(`Error updating user: ${errorMessage}`, 'error', 6000);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (userId) => {
      console.log('Deleting user:', userId);
      await apiClient.delete(`/users/users/${userId}/`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] });
      showToast('User deleted successfully!', 'success');
    },
    onError: (error) => {
      console.error('User deletion failed:', error);
      const errorMessage = error.response?.data?.error ||
                          error.response?.data?.detail ||
                          'Failed to delete user';
      showToast(`Error deleting user: ${errorMessage}`, 'error', 6000);
    },
  });

  const handleViewUser = (user) => {
    setSelectedUser(user);
    setIsViewModalOpen(true);
  };

  const handleEditUser = (user) => {
    setSelectedUser(user);
    setIsEditModalOpen(true);
  };

  const handleDeleteUser = (user) => {
    // Prevent self-deletion
    if (currentUser && user.id === currentUser.id) {
      showToast('You cannot delete your own account! This would lock you out of the system.', 'error');
      return;
    }

    setConfirmDialog({
      isOpen: true,
      title: 'Delete User',
      message: `Are you sure you want to DELETE user "${user.username}"? This action cannot be undone!`,
      variant: 'danger',
      onConfirm: () => {
        deleteMutation.mutate(user.id);
        setConfirmDialog({ ...confirmDialog, isOpen: false });
      }
    });
  };

  const toggleUserStatus = (user) => {
    const newStatus = !user.is_active;
    const action = newStatus ? 'Activate' : 'Deactivate';

    // Prevent self-deactivation
    if (currentUser && user.id === currentUser.id && !newStatus) {
      showToast('You cannot deactivate your own account! This would lock you out of the system.', 'error');
      return;
    }

    setConfirmDialog({
      isOpen: true,
      title: `${action} User`,
      message: `${action} user "${user.username}"?`,
      variant: newStatus ? 'primary' : 'danger',
      confirmText: action,
      onConfirm: () => {
        updateMutation.mutate({
          userId: user.id,
          data: { is_active: newStatus }
        });
        setConfirmDialog({ ...confirmDialog, isOpen: false });
      }
    });
  };

  // Get role display names for a user
  const getUserRoleNames = (user) => {
    if (!user.system_roles || user.system_roles.length === 0) {
      return ['User'];
    }
    return user.system_roles.map(role => role.display_name || role.name || 'Unknown Role');
  };

  if (isLoading) {
    return (
      <Card title="User Management">
        <div className="flex items-center justify-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          <span className="ml-3 text-gray-600">Loading users...</span>
        </div>
      </Card>
    );
  }

  return (
    <Card
      title="User Management"
      actions={
        <Button onClick={() => setIsCreateModalOpen(true)}>Create User</Button>
      }
    >
      {!users || users.length === 0 ? (
        <div className="text-center py-8 text-gray-500">
          <p>No users found. Create your first user!</p>
        </div>
      ) : (
        <div className="space-y-3">
          {users.map((user) => (
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
                <div className="flex-1 min-w-0">
                  <div className="flex items-center space-x-2">
                    <span className="font-medium text-gray-900 truncate">
                      {user.name || user.username}
                    </span>
                    <Badge variant={user.is_active ? 'success' : 'danger'}>
                      {user.is_active ? 'Active' : 'Inactive'}
                    </Badge>
                    {user.is_superuser && (
                      <Badge variant="warning">Superuser</Badge>
                    )}
                  </div>
                  <div className="flex items-center space-x-4 mt-1 text-sm text-gray-500">
                    <span>@{user.username}</span>
                    <span>{user.email}</span>
                  </div>
                  <div className="flex items-center space-x-2 mt-1">
                    {getUserRoleNames(user).map((roleName, idx) => (
                      <Badge key={idx} variant="info">{roleName}</Badge>
                    ))}
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="flex items-center space-x-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleViewUser(user)}
                >
                  View
                </Button>

                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => handleEditUser(user)}
                >
                  Edit
                </Button>

                <Button
                  variant={user.is_active ? 'danger' : 'success'}
                  size="sm"
                  onClick={() => toggleUserStatus(user)}
                  disabled={currentUser && user.id === currentUser.id && user.is_active}
                  title={currentUser && user.id === currentUser.id && user.is_active ? 'Cannot deactivate your own account' : ''}
                >
                  {user.is_active ? 'Deactivate' : 'Activate'}
                </Button>

                {currentUser && user.id !== currentUser.id && (
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() => handleDeleteUser(user)}
                  >
                    Delete
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

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
              case 'Investigator':
                system_roles = [ROLES.BLOCKCHAIN_INVESTIGATOR];
                break;
              case 'Court':
                system_roles = [ROLES.BLOCKCHAIN_COURT];
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

      {/* View User Modal */}
      {selectedUser && (
        <Modal
          isOpen={isViewModalOpen}
          onClose={() => {
            setIsViewModalOpen(false);
            setSelectedUser(null);
          }}
          title={`User Details - ${selectedUser.username}`}
          footer={
            <Button onClick={() => setIsViewModalOpen(false)}>Close</Button>
          }
        >
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-700">Username</label>
                <p className="mt-1 text-gray-900">{selectedUser.username}</p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700">Full Name</label>
                <p className="mt-1 text-gray-900">{selectedUser.name || '-'}</p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700">Email</label>
                <p className="mt-1 text-gray-900">{selectedUser.email}</p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700">Status</label>
                <p className="mt-1">
                  <Badge variant={selectedUser.is_active ? 'success' : 'danger'}>
                    {selectedUser.is_active ? 'Active' : 'Inactive'}
                  </Badge>
                </p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700">Superuser</label>
                <p className="mt-1">
                  <Badge variant={selectedUser.is_superuser ? 'danger' : 'secondary'}>
                    {selectedUser.is_superuser ? 'Yes' : 'No'}
                  </Badge>
                </p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700">MFA Enabled</label>
                <p className="mt-1">
                  <Badge variant={selectedUser.mfa_enabled ? 'success' : 'secondary'}>
                    {selectedUser.mfa_enabled ? 'Yes' : 'No'}
                  </Badge>
                </p>
              </div>
              <div className="col-span-2">
                <label className="text-sm font-medium text-gray-700">Roles</label>
                <div className="mt-1 flex flex-wrap gap-2">
                  {getUserRoleNames(selectedUser).map((roleName, idx) => (
                    <Badge key={idx} variant="info">{roleName}</Badge>
                  ))}
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700">Date Joined</label>
                <p className="mt-1 text-gray-900 text-sm">
                  {selectedUser.date_joined ? new Date(selectedUser.date_joined).toLocaleDateString() : '-'}
                </p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700">Last Login</label>
                <p className="mt-1 text-gray-900 text-sm">
                  {selectedUser.last_login ? new Date(selectedUser.last_login).toLocaleString() : 'Never'}
                </p>
              </div>
            </div>
          </div>
        </Modal>
      )}

      {/* Edit User Modal */}
      {selectedUser && (
        <Modal
          isOpen={isEditModalOpen}
          onClose={() => {
            setIsEditModalOpen(false);
            setSelectedUser(null);
          }}
          title={`Edit User - ${selectedUser.username}`}
          footer={
            <>
              <Button
                variant="secondary"
                onClick={() => setIsEditModalOpen(false)}
                disabled={updateMutation.isPending}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                form="edit-user-form"
                loading={updateMutation.isPending}
              >
                Save Changes
              </Button>
            </>
          }
        >
          <UserEditForm
            user={selectedUser}
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
                case 'Investigator':
                  system_roles = [ROLES.BLOCKCHAIN_INVESTIGATOR];
                  break;
                case 'Court':
                  system_roles = [ROLES.BLOCKCHAIN_COURT];
                  break;
                case 'User':
                default:
                  system_roles = [];
                  break;
              }

              const updateData = {
                name: data.name,
                email: data.email,
                is_active: data.is_active,
                system_roles: system_roles,
              };

              // Only include password if provided
              if (data.password) {
                updateData.password = data.password;
                updateData.password_strategy = 'custom';
              }

              console.log('Updating user with data:', { ...updateData, password: data.password ? '[REDACTED]' : undefined });
              updateMutation.mutate({
                userId: selectedUser.id,
                data: updateData
              });
            }}
            formId="edit-user-form"
            isLoading={updateMutation.isPending}
          />
        </Modal>
      )}

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
          disabled={isLoading}
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
          disabled={isLoading}
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
          disabled={isLoading}
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
          disabled={isLoading}
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Role *</label>
        <select
          value={formData.role}
          onChange={(e) => setFormData({ ...formData, role: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          disabled={isLoading}
        >
          <option value="User">User (No blockchain access)</option>
          <option value="Admin">System Admin (Full access)</option>
          <option value="Auditor">Blockchain Auditor (Read-only)</option>
          <option value="Investigator">Blockchain Investigator (Upload evidence)</option>
          <option value="Court">Blockchain Court (Manage investigations)</option>
        </select>
        <p className="mt-1 text-xs text-gray-500">
          Choose a role to assign specific permissions for blockchain evidence management
        </p>
      </div>

      <div className="flex items-center">
        <input
          type="checkbox"
          checked={formData.is_active}
          onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
          className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
          disabled={isLoading}
        />
        <label className="ml-2 block text-sm text-gray-900">
          Active (User can log in)
        </label>
      </div>
    </form>
  );
}

function UserEditForm({ user, onSubmit, formId, isLoading }) {
  // Get current role from user's system_roles
  const getCurrentRole = () => {
    if (!user.system_roles || user.system_roles.length === 0) return 'User';
    const roleId = user.system_roles[0].id;
    if (roleId === ROLES.SYSTEM_ADMIN) return 'Admin';
    if (roleId === ROLES.BLOCKCHAIN_AUDITOR) return 'Auditor';
    if (roleId === ROLES.BLOCKCHAIN_INVESTIGATOR) return 'Investigator';
    if (roleId === ROLES.BLOCKCHAIN_COURT) return 'Court';
    return 'User';
  };

  const [formData, setFormData] = useState({
    name: user.name || '',
    email: user.email || '',
    password: '',
    role: getCurrentRole(),
    is_active: user.is_active,
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form id={formId} onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">Username</label>
        <input
          type="text"
          value={user.username}
          disabled
          className="mt-1 block w-full rounded-md border-gray-300 bg-gray-50 shadow-sm cursor-not-allowed"
        />
        <p className="mt-1 text-xs text-gray-500">Username cannot be changed</p>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Full Name *</label>
        <input
          type="text"
          required
          value={formData.name}
          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          disabled={isLoading}
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
          disabled={isLoading}
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">New Password</label>
        <input
          type="password"
          minLength={8}
          value={formData.password}
          onChange={(e) => setFormData({ ...formData, password: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          placeholder="Leave blank to keep current password"
          disabled={isLoading}
        />
        <p className="mt-1 text-xs text-gray-500">
          Only fill this if you want to change the password (min 8 characters)
        </p>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Role *</label>
        <select
          value={formData.role}
          onChange={(e) => setFormData({ ...formData, role: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          disabled={isLoading}
        >
          <option value="User">User (No blockchain access)</option>
          <option value="Admin">System Admin (Full access)</option>
          <option value="Auditor">Blockchain Auditor (Read-only)</option>
          <option value="Investigator">Blockchain Investigator (Upload evidence)</option>
          <option value="Court">Blockchain Court (Manage investigations)</option>
        </select>
      </div>

      <div className="flex items-center">
        <input
          type="checkbox"
          checked={formData.is_active}
          onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
          className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
          disabled={isLoading}
        />
        <label className="ml-2 block text-sm text-gray-900">
          Active (User can log in)
        </label>
      </div>
    </form>
  );
}
