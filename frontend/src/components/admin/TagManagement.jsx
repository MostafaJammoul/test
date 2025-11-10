import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { tagAPI } from '../../services/api';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import Modal from '../common/Modal';
import { TAG_CATEGORY_DISPLAY } from '../../utils/constants';

export default function TagManagement() {
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const queryClient = useQueryClient();

  const { data: tags, isLoading } = useQuery({
    queryKey: ['tags'],
    queryFn: async () => {
      const response = await tagAPI.list();
      return response.data.results;
    },
  });

  const createMutation = useMutation({
    mutationFn: tagAPI.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      setIsCreateModalOpen(false);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: tagAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
    },
  });

  if (isLoading) return <div>Loading...</div>;

  return (
    <Card
      title="Tag Library Management"
      actions={
        <Button onClick={() => setIsCreateModalOpen(true)}>Create Tag</Button>
      }
    >
      <div className="space-y-2">
        {tags?.map((tag) => (
          <div
            key={tag.id}
            className="flex items-center justify-between p-3 border border-gray-200 rounded-md"
          >
            <div className="flex items-center space-x-3">
              <div
                className="w-6 h-6 rounded-full"
                style={{ backgroundColor: tag.color }}
              ></div>
              <div>
                <div className="font-medium">{tag.name}</div>
                <div className="text-sm text-gray-500">
                  {TAG_CATEGORY_DISPLAY[tag.category]}
                </div>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <Badge>{tag.tagged_count} cases</Badge>
              <Button
                variant="danger"
                size="sm"
                onClick={() => {
                  if (confirm(`Delete tag "${tag.name}"?`)) {
                    deleteMutation.mutate(tag.id);
                  }
                }}
              >
                Delete
              </Button>
            </div>
          </div>
        ))}
      </div>

      {/* Create Tag Modal */}
      <Modal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        title="Create Tag"
        footer={
          <>
            <Button variant="secondary" onClick={() => setIsCreateModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" form="create-tag-form">
              Create
            </Button>
          </>
        }
      >
        <TagForm
          onSubmit={(data) => createMutation.mutate(data)}
          formId="create-tag-form"
        />
      </Modal>
    </Card>
  );
}

function TagForm({ onSubmit, formId }) {
  const [formData, setFormData] = useState({
    name: '',
    category: 'crime_type',
    color: '#3B82F6',
    description: '',
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form id={formId} onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">Tag Name</label>
        <input
          type="text"
          required
          value={formData.name}
          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Category</label>
        <select
          value={formData.category}
          onChange={(e) => setFormData({ ...formData, category: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        >
          <option value="crime_type">Crime Type</option>
          <option value="priority">Priority</option>
          <option value="status">Status</option>
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Color</label>
        <input
          type="color"
          value={formData.color}
          onChange={(e) => setFormData({ ...formData, color: e.target.value })}
          className="mt-1 block w-full h-10 rounded-md border-gray-300"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Description</label>
        <textarea
          value={formData.description}
          onChange={(e) => setFormData({ ...formData, description: e.target.value })}
          rows={3}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        />
      </div>
    </form>
  );
}
