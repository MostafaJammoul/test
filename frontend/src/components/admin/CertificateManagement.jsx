import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import Card from '../common/Card';
import Button from '../common/Button';
import Badge from '../common/Badge';
import apiClient from '../../services/api';
import { formatDate } from '../../utils/formatters';

export default function CertificateManagement() {
  const { data: certificates, isLoading } = useQuery({
    queryKey: ['certificates'],
    queryFn: async () => {
      const response = await apiClient.get('/pki/certificates/');
      return response.data.results;
    },
  });

  if (isLoading) return <div>Loading...</div>;

  return (
    <Card
      title="Certificate Management"
      actions={<Button>Issue Certificate</Button>}
    >
      {certificates?.length > 0 ? (
        <div className="space-y-2">
          {certificates.map((cert) => (
            <div
              key={cert.id}
              className="flex items-center justify-between p-3 border border-gray-200 rounded-md"
            >
              <div>
                <div className="font-medium">{cert.common_name}</div>
                <div className="text-sm text-gray-500">
                  Serial: {cert.serial_number}
                </div>
                <div className="text-xs text-gray-400">
                  Expires: {formatDate(cert.not_after)}
                </div>
              </div>
              <div className="flex items-center space-x-2">
                <Badge variant={cert.is_revoked ? 'danger' : 'success'}>
                  {cert.is_revoked ? 'Revoked' : 'Active'}
                </Badge>
                {!cert.is_revoked && (
                  <Button variant="danger" size="sm">
                    Revoke
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="text-center py-8">
          <p className="text-gray-600">No certificates issued yet</p>
          <Button className="mt-4">Issue First Certificate</Button>
        </div>
      )}
    </Card>
  );
}
