import { useState } from 'react';
import { useParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import Layout from '../../components/layout/Layout';
import Card from '../../components/common/Card';
import Badge from '../../components/common/Badge';
import Button from '../../components/common/Button';
import { useAuth } from '../../contexts/AuthContext';
import { investigationAPI, evidenceAPI } from '../../services/api';
import { formatDate, formatFileSize } from '../../utils/formatters';
import { STATUS_COLORS } from '../../utils/constants';
import UploadEvidenceModal from '../../components/modals/UploadEvidenceModal';
import AddNoteModal from '../../components/modals/AddNoteModal';
import ArchiveInvestigationModal from '../../components/modals/ArchiveInvestigationModal';
import ReopenInvestigationModal from '../../components/modals/ReopenInvestigationModal';

export default function InvestigationDetailPage() {
  const { id } = useParams();
  const { isInvestigator, isCourt, isAuditor } = useAuth();
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState('overview');
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [showNoteModal, setShowNoteModal] = useState(false);
  const [showArchiveModal, setShowArchiveModal] = useState(false);
  const [showReopenModal, setShowReopenModal] = useState(false);

  const { data: investigation, isLoading } = useQuery({
    queryKey: ['investigation', id],
    queryFn: async () => {
      const response = await investigationAPI.get(id);
      return response.data;
    },
  });

  if (isLoading) return <div>Loading...</div>;
  if (!investigation) return <div>Investigation not found</div>;

  return (
    <Layout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">{investigation.title}</h1>
              <p className="mt-1 text-sm text-gray-600">{investigation.case_number}</p>
            </div>
            <div className="flex items-center space-x-3">
              <Badge className={STATUS_COLORS[investigation.status]}>
                {investigation.status}
              </Badge>
              {/* Court Actions */}
              {isCourt() && investigation.status === 'active' && (
                <Button variant="danger" size="sm" onClick={() => setShowArchiveModal(true)}>
                  Archive Case
                </Button>
              )}
              {isCourt() && investigation.status === 'archived' && (
                <Button variant="primary" size="sm" onClick={() => setShowReopenModal(true)}>
                  Reopen Case
                </Button>
              )}
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            {['overview', 'evidence', 'notes', 'blockchain', 'activity'].map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`${
                  activeTab === tab
                    ? 'border-primary-500 text-primary-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm capitalize`}
              >
                {tab}
              </button>
            ))}
          </nav>
        </div>

        {/* Tab Content */}
        <div>
          {activeTab === 'overview' && <OverviewTab investigation={investigation} />}
          {activeTab === 'evidence' && (
            <EvidenceTab
              investigation={investigation}
              canUpload={isInvestigator()}
              canDownload={isInvestigator() || isCourt()}
              onUploadClick={() => setShowUploadModal(true)}
            />
          )}
          {activeTab === 'notes' && (
            <NotesTab
              investigation={investigation}
              canAdd={isInvestigator() || isAuditor()}
              onAddClick={() => setShowNoteModal(true)}
            />
          )}
          {activeTab === 'blockchain' && <BlockchainTab investigation={investigation} />}
          {activeTab === 'activity' && <ActivityTab investigation={investigation} />}
        </div>

        {/* Modals */}
        <UploadEvidenceModal
          isOpen={showUploadModal}
          onClose={() => setShowUploadModal(false)}
          investigationId={id}
        />
        <AddNoteModal
          isOpen={showNoteModal}
          onClose={() => setShowNoteModal(false)}
          investigationId={id}
        />
        <ArchiveInvestigationModal
          isOpen={showArchiveModal}
          onClose={() => setShowArchiveModal(false)}
          investigation={investigation}
        />
        <ReopenInvestigationModal
          isOpen={showReopenModal}
          onClose={() => setShowReopenModal(false)}
          investigation={investigation}
        />
      </div>
    </Layout>
  );
}

function OverviewTab({ investigation }) {
  return (
    <Card title="Investigation Details">
      <dl className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <dt className="text-sm font-medium text-gray-500">Case Number</dt>
          <dd className="mt-1 text-sm text-gray-900">{investigation.case_number}</dd>
        </div>
        <div>
          <dt className="text-sm font-medium text-gray-500">Status</dt>
          <dd className="mt-1 text-sm text-gray-900">{investigation.status}</dd>
        </div>
        <div className="md:col-span-2">
          <dt className="text-sm font-medium text-gray-500">Description</dt>
          <dd className="mt-1 text-sm text-gray-900">{investigation.description}</dd>
        </div>
        <div>
          <dt className="text-sm font-medium text-gray-500">Created</dt>
          <dd className="mt-1 text-sm text-gray-900">{formatDate(investigation.created_at)}</dd>
        </div>
        <div>
          <dt className="text-sm font-medium text-gray-500">Evidence Count</dt>
          <dd className="mt-1 text-sm text-gray-900">{investigation.evidence_count || 0}</dd>
        </div>
      </dl>
    </Card>
  );
}

function EvidenceTab({ investigation, canUpload, canDownload, onUploadClick }) {
  const queryClient = useQueryClient();
  const [verifying, setVerifying] = useState({});

  const handleDownload = async (evidenceId, fileName) => {
    try {
      const response = await evidenceAPI.download(evidenceId);
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', fileName);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Download failed:', error);
      alert('Failed to download evidence file');
    }
  };

  const handleVerify = async (evidenceId) => {
    setVerifying({ ...verifying, [evidenceId]: true });
    try {
      const response = await evidenceAPI.verify(evidenceId);
      if (response.data.valid) {
        alert('✓ Evidence integrity verified! Hash matches blockchain record.');
      } else {
        alert('✗ WARNING: Evidence integrity check failed! File may have been tampered with.');
      }
    } catch (error) {
      console.error('Verification failed:', error);
      alert('Failed to verify evidence integrity');
    } finally {
      setVerifying({ ...verifying, [evidenceId]: false });
    }
  };

  return (
    <Card
      title="Evidence Files"
      actions={canUpload && <Button onClick={onUploadClick}>Upload Evidence</Button>}
    >
      {investigation.evidence?.length > 0 ? (
        <div className="space-y-2">
          {investigation.evidence.map((evidence) => (
            <div key={evidence.id} className="flex items-center justify-between p-3 border border-gray-200 rounded-md">
              <div className="flex-1">
                <div className="font-medium">{evidence.file_name}</div>
                <div className="text-sm text-gray-500">
                  {formatFileSize(evidence.file_size)} • {formatDate(evidence.created_at)}
                </div>
                {evidence.description && (
                  <div className="text-sm text-gray-600 mt-1">{evidence.description}</div>
                )}
              </div>
              <div className="flex items-center space-x-2">
                <Button
                  size="sm"
                  variant="secondary"
                  onClick={() => handleVerify(evidence.id)}
                  disabled={verifying[evidence.id]}
                >
                  {verifying[evidence.id] ? 'Verifying...' : 'Verify'}
                </Button>
                {canDownload && (
                  <Button
                    size="sm"
                    variant="primary"
                    onClick={() => handleDownload(evidence.id, evidence.file_name)}
                  >
                    Download
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-gray-600">No evidence files uploaded yet</p>
      )}
    </Card>
  );
}

function NotesTab({ investigation, canAdd, onAddClick }) {
  return (
    <Card title="Investigation Notes" actions={canAdd && <Button onClick={onAddClick}>Add Note</Button>}>
      {investigation.notes?.length > 0 ? (
        <div className="space-y-4">
          {investigation.notes.map((note) => (
            <div key={note.id} className="border-l-4 border-primary-500 pl-4">
              <div className="text-sm text-gray-600">
                {formatDate(note.created_at)} • {note.created_by?.name || note.created_by?.username}
              </div>
              <p className="mt-1">{note.content}</p>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-gray-600">No notes added yet</p>
      )}
    </Card>
  );
}

function BlockchainTab({ investigation }) {
  return (
    <Card title="Blockchain Transactions">
      {investigation.blockchain_transactions?.length > 0 ? (
        <div className="space-y-2">
          {investigation.blockchain_transactions.map((tx) => (
            <div key={tx.id} className="p-3 border border-gray-200 rounded-md">
              <div className="font-mono text-sm">{tx.transaction_hash}</div>
              <div className="text-sm text-gray-500">{formatDate(tx.timestamp)}</div>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-gray-600">No blockchain transactions yet</p>
      )}
    </Card>
  );
}

function ActivityTab({ investigation }) {
  return (
    <Card title="Activity Log">
      {investigation.activities?.length > 0 ? (
        <div className="space-y-4">
          {investigation.activities.map((activity) => (
            <div key={activity.id} className="flex items-start space-x-3">
              <div className="flex-shrink-0 w-2 h-2 mt-2 rounded-full bg-primary-500"></div>
              <div className="flex-1">
                <div className="text-sm text-gray-900">{activity.action}</div>
                <div className="text-xs text-gray-500">{formatDate(activity.timestamp)}</div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-gray-600">No activity recorded yet</p>
      )}
    </Card>
  );
}
