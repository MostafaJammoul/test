import { useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { ChevronDownIcon, ChevronUpIcon } from '@heroicons/react/24/outline';
import { tagAPI } from '../../services/api';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import Modal from '../common/Modal';
import ConfirmDialog from '../common/ConfirmDialog';
import { useToast } from '../../contexts/ToastContext';
import { TAG_CATEGORY_DISPLAY } from '../../utils/constants';

export default function TagManagement() {
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [expandedTagIds, setExpandedTagIds] = useState(new Set());
  const [confirmDialog, setConfirmDialog] = useState({ isOpen: false, title: '', message: '', onConfirm: null });
  const [tagSearch, setTagSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const queryClient = useQueryClient();
  const { showToast } = useToast();

  const toggleTagDescription = (tagId) => {
    setExpandedTagIds(prev => {
      const newSet = new Set(prev);
      if (newSet.has(tagId)) {
        newSet.delete(tagId);
      } else {
        newSet.add(tagId);
      }
      return newSet;
    });
  };

  const { data: tags, isLoading } = useQuery({
    queryKey: ['tags'],
    queryFn: async () => {
      const response = await tagAPI.list();
      // API returns array directly, not paginated {results: [...]}
      console.log('Tags loaded:', response.data);
      return Array.isArray(response.data) ? response.data : response.data.results || [];
    },
  });

  const createMutation = useMutation({
    mutationFn: tagAPI.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      setIsCreateModalOpen(false);
      showToast('Tag created successfully!', 'success');
    },
    onError: (error) => {
      console.error('Tag creation error:', error);
      const errorMsg = error.response?.data?.detail
        || error.response?.data?.error
        || JSON.stringify(error.response?.data)
        || error.message
        || 'Failed to create tag';
      showToast(`Error creating tag: ${errorMsg}`, 'error', 6000);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: tagAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      showToast('Tag deleted successfully!', 'success');
    },
    onError: (error) => {
      console.error('Tag deletion error:', error);
      const errorMsg = error.response?.data?.detail
        || error.response?.data?.error
        || 'Failed to delete tag';
      showToast(`Error deleting tag: ${errorMsg}`, 'error', 6000);
    },
  });

  const handleDeleteTag = (tag) => {
    setConfirmDialog({
      isOpen: true,
      title: 'Delete Tag',
      message: `Delete tag "${tag.name}"? This will remove it from all investigations using it.`,
      confirmText: 'Delete',
      variant: 'danger',
      onConfirm: () => {
        deleteMutation.mutate(tag.id);
        setConfirmDialog({ ...confirmDialog, isOpen: false });
      }
    });
  };

  if (isLoading) return <div>Loading...</div>;

  const filteredTags = useMemo(() => {
    if (!tags) return [];
    const normalized = tagSearch.trim().toLowerCase();
    return tags.filter((tag) => {
      const matchesSearch = !normalized || tag.name.toLowerCase().includes(normalized);
      const matchesCategory = categoryFilter === 'all' || tag.category === categoryFilter;
      return matchesSearch && matchesCategory;
    });
  }, [tags, tagSearch, categoryFilter]);

  return (
    <Card
      title="Tag Library Management"
      actions={
        <Button onClick={() => setIsCreateModalOpen(true)}>Create Tag</Button>
      }
    >
      <div className="grid gap-4 md:grid-cols-2 mb-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Search Tags</label>
          <input
            type="text"
            value={tagSearch}
            onChange={(e) => setTagSearch(e.target.value)}
            placeholder="Search by tag name"
            className="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          >
            <option value="all">All Categories</option>
            <option value="crime_type">Crime Type</option>
            <option value="priority">Priority</option>
            <option value="status">Status</option>
          </select>
        </div>
      </div>

      {filteredTags.length === 0 ? (
        <div className="border border-dashed border-gray-300 rounded-md py-8 text-center text-gray-500">
          <p>No tags match the current filters.</p>
          {(tagSearch || categoryFilter !== 'all') && (
            <button
              type="button"
              onClick={() => {
                setTagSearch('');
                setCategoryFilter('all');
              }}
              className="mt-2 text-sm text-primary-600 hover:underline"
            >
              Clear filters
            </button>
          )}
        </div>
      ) : (
        <div className="space-y-2">
          {filteredTags.map((tag) => (
            <div
              key={tag.id}
              className="border border-gray-200 rounded-md"
            >
              <div className="flex items-center justify-between p-3">
              <div className="flex items-center space-x-3 flex-1">
                <div
                  className="w-6 h-6 rounded-full flex-shrink-0"
                  style={{ backgroundColor: tag.color }}
                ></div>
                <div className="flex-1">
                  <div className="font-medium">{tag.name}</div>
                  <div className="text-sm text-gray-500">
                    {TAG_CATEGORY_DISPLAY[tag.category]}
                  </div>
                </div>
              </div>
              <div className="flex items-center space-x-2">
                <Badge>{tag.tagged_count || 0} cases</Badge>
                {tag.description && (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => toggleTagDescription(tag.id)}
                  >
                    {expandedTagIds.has(tag.id) ? (
                      <ChevronUpIcon className="h-4 w-4" />
                    ) : (
                      <ChevronDownIcon className="h-4 w-4" />
                    )}
                  </Button>
                )}
                <Button
                  variant="danger"
                  size="sm"
                  onClick={() => handleDeleteTag(tag)}
                >
                  Delete
                </Button>
              </div>
            </div>
            {tag.description && expandedTagIds.has(tag.id) && (
              <div className="px-3 pb-3 pt-0">
                <div className="bg-gray-50 rounded p-3 text-sm text-gray-700">
                  <span className="font-medium text-gray-900">Description: </span>
                  {tag.description}
                </div>
              </div>
            )}
              </div>
            ))}
        </div>
      )}

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
