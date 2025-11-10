import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { investigationAPI } from '../services/api';

/**
 * Hook for fetching investigations list
 */
export const useInvestigations = (params = {}) => {
  return useQuery({
    queryKey: ['investigations', params],
    queryFn: async () => {
      const response = await investigationAPI.list(params);
      return response.data;
    },
  });
};

/**
 * Hook for fetching single investigation
 */
export const useInvestigation = (id) => {
  return useQuery({
    queryKey: ['investigation', id],
    queryFn: async () => {
      const response = await investigationAPI.get(id);
      return response.data;
    },
    enabled: !!id,
  });
};

/**
 * Hook for creating investigation (Court only)
 */
export const useCreateInvestigation = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (data) => {
      const response = await investigationAPI.create(data);
      return response.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['investigations'] });
    },
  });
};

/**
 * Hook for archiving investigation (Court only)
 */
export const useArchiveInvestigation = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, reason }) => {
      const response = await investigationAPI.archive(id, reason);
      return response.data;
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['investigations'] });
      queryClient.invalidateQueries({ queryKey: ['investigation', variables.id] });
    },
  });
};

/**
 * Hook for reopening investigation (Court only)
 */
export const useReopenInvestigation = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, reason }) => {
      const response = await investigationAPI.reopen(id, reason);
      return response.data;
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['investigations'] });
      queryClient.invalidateQueries({ queryKey: ['investigation', variables.id] });
    },
  });
};
