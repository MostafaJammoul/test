import { Link } from 'react-router-dom';
import Badge from '../common/Badge';
import { formatDate, isRecent } from '../../utils/formatters';
import { STATUS_COLORS } from '../../utils/constants';

export default function InvestigationCard({ investigation }) {
  const hasRecentActivity = investigation.activities?.some((a) => isRecent(a.timestamp));

  return (
    <Link to={`/investigations/${investigation.id}`}>
      <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow relative">
        {/* Recent Activity Badge */}
        {hasRecentActivity && (
          <Badge variant="recent" className="absolute top-2 right-2">
            New Activity
          </Badge>
        )}

        {/* Case Number */}
        <div className="text-sm font-medium text-primary-600 mb-2">
          {investigation.case_number}
        </div>

        {/* Title */}
        <h3 className="text-lg font-semibold text-gray-900 mb-2">{investigation.title}</h3>

        {/* Description */}
        <p className="text-sm text-gray-600 line-clamp-2 mb-4">{investigation.description}</p>

        {/* Status & Evidence Count */}
        <div className="flex items-center justify-between">
          <Badge className={STATUS_COLORS[investigation.status]}>
            {investigation.status}
          </Badge>
          <span className="text-sm text-gray-600">
            {investigation.evidence_count} evidence files
          </span>
        </div>

        {/* Created At */}
        <div className="mt-4 text-xs text-gray-500">
          Created {formatDate(investigation.created_at)}
        </div>
      </div>
    </Link>
  );
}
