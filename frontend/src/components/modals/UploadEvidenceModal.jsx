import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import Modal from '../common/Modal';
import Button from '../common/Button';
import { evidenceAPI } from '../../services/api';

export default function UploadEvidenceModal({ isOpen, onClose, investigationId }) {
  const queryClient = useQueryClient();
  const [formData, setFormData] = useState({
    file: null,
    description: '',
    evidence_type: 'digital',
    location: '',
    collected_date: new Date().toISOString().split('T')[0],
  });
  const [error, setError] = useState('');

  const uploadMutation = useMutation({
    mutationFn: async (data) => {
      const formDataObj = new FormData();
      formDataObj.append('file', data.file);
      formDataObj.append('investigation', investigationId);
      formDataObj.append('description', data.description);
      formDataObj.append('evidence_type', data.evidence_type);
      formDataObj.append('location', data.location);
      formDataObj.append('collected_date', data.collected_date);

      const response = await evidenceAPI.upload(formDataObj);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries(['investigation', investigationId]);
      queryClient.invalidateQueries(['evidence']);
      onClose();
      resetForm();
    },
    onError: (error) => {
      setError(error.response?.data?.error || 'Failed to upload evidence');
    },
  });

  const resetForm = () => {
    setFormData({
      file: null,
      description: '',
      evidence_type: 'digital',
      location: '',
      collected_date: new Date().toISOString().split('T')[0],
    });
    setError('');
  };

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      // Check file size (max 100MB)
      if (file.size > 100 * 1024 * 1024) {
        setError('File size must be less than 100MB');
        return;
      }
      setFormData({ ...formData, file });
      setError('');
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!formData.file) {
      setError('Please select a file to upload');
      return;
    }

    if (!formData.description.trim()) {
      setError('Please provide a description');
      return;
    }

    uploadMutation.mutate(formData);
  };

  const handleClose = () => {
    resetForm();
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={handleClose} title="Upload Evidence">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* File Input */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Evidence File *
          </label>
          <input
            type="file"
            onChange={handleFileChange}
            className="mt-1 block w-full text-sm text-gray-900 border border-gray-300 rounded-md cursor-pointer focus:outline-none focus:ring-2 focus:ring-primary-500"
            required
          />
          {formData.file && (
            <p className="mt-1 text-sm text-gray-500">
              Selected: {formData.file.name} ({(formData.file.size / 1024 / 1024).toFixed(2)} MB)
            </p>
          )}
        </div>

        {/* Description */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Description *
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            rows={3}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Describe the evidence and its significance..."
            required
          />
        </div>

        {/* Evidence Type */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Evidence Type *
          </label>
          <select
            value={formData.evidence_type}
            onChange={(e) => setFormData({ ...formData, evidence_type: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
          >
            <option value="digital">Digital</option>
            <option value="physical">Physical</option>
            <option value="document">Document</option>
            <option value="photo">Photo</option>
            <option value="video">Video</option>
            <option value="audio">Audio</option>
            <option value="other">Other</option>
          </select>
        </div>

        {/* Location */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Collection Location
          </label>
          <input
            type="text"
            value={formData.location}
            onChange={(e) => setFormData({ ...formData, location: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            placeholder="Where was this evidence collected?"
          />
        </div>

        {/* Collection Date */}
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Collection Date *
          </label>
          <input
            type="date"
            value={formData.collected_date}
            onChange={(e) => setFormData({ ...formData, collected_date: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            required
          />
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
            disabled={uploadMutation.isPending}
          >
            {uploadMutation.isPending ? 'Uploading...' : 'Upload Evidence'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
