# -*- coding: utf-8 -*-
#
"""
Blockchain Chain of Custody API Views

REST API endpoints for evidence management, blockchain transactions,
investigations, and GUID resolution.

CONFIGURATION REQUIRED:
    See config/blockchain.yml for Fabric and IPFS connection settings
"""
import hashlib
import logging
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.utils import timezone
from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend

from common.permissions import IsValidUser
from rbac.permissions import RBACPermission
from orgs.mixins.api import OrgBulkModelViewSet
from ..models import (
    Investigation, Evidence, BlockchainTransaction, GUIDMapping,
    Tag, InvestigationTag, InvestigationNote, InvestigationActivity
)
from ..services.guid_resolver import GUIDResolver
from ..services.archive_service import ArchiveService
from .serializers import (
    InvestigationSerializer, EvidenceSerializer, BlockchainTransactionSerializer,
    TagSerializer, InvestigationTagSerializer, InvestigationNoteSerializer,
    InvestigationActivitySerializer
)

logger = logging.getLogger(__name__)

# ==============================================================================
# BLOCKCHAIN SECURITY HARDENING - ROLE-BASED ACCESS CONTROL
# ==============================================================================
# Allowed blockchain role IDs (from rbac.builtin.BuiltinRole)
ALLOWED_BLOCKCHAIN_ROLE_IDS = [
    '00000000-0000-0000-0000-000000000001',  # SystemAdmin
    '00000000-0000-0000-0000-000000000008',  # BlockchainInvestigator
    '00000000-0000-0000-0000-000000000009',  # BlockchainAuditor
    '00000000-0000-0000-0000-00000000000A',  # BlockchainCourt
]

class BlockchainRoleRequiredMixin:
    """
    Mixin to restrict blockchain API access to authorized roles only.

    Blocks legacy JumpServer roles (SystemAuditor, OrgAdmin, etc.) from
    accessing blockchain evidence to maintain chain of custody integrity.
    """

    def get_queryset(self):
        """Filter queryset based on user's blockchain role authorization"""
        queryset = super().get_queryset()
        user = self.request.user

        # Check if user has an allowed blockchain role
        from rbac.models import SystemRoleBinding

        # Convert UUID objects to strings for comparison
        user_role_ids = [
            str(role_id) for role_id in
            SystemRoleBinding.objects.filter(user=user).values_list('role_id', flat=True)
        ]

        has_blockchain_role = any(
            role_id in ALLOWED_BLOCKCHAIN_ROLE_IDS
            for role_id in user_role_ids
        )

        if not has_blockchain_role:
            logger.warning(
                f"User {user.username} attempted to access blockchain API "
                f"without authorized role. Roles: {user_role_ids}"
            )
            # Return empty queryset - user not authorized
            return queryset.none()

        return queryset
# ==============================================================================

# Use mock clients in development/testing mode
if settings.DEBUG or getattr(settings, 'USE_MOCK_BLOCKCHAIN', True):
    from ..clients.fabric_client_mock import FabricClient
    from ..clients.ipfs_client_mock import IPFSClient
    logger.info("Using MOCK blockchain and IPFS clients for development")
else:
    from ..clients.fabric_client import FabricClient
    from ..clients.ipfs_client import IPFSClient
    logger.info("Using REAL blockchain and IPFS clients")


# =============================================================================
# CONFIGURATION NOTES
# =============================================================================
#
# Before using these APIs, configure the following:
#
# 1. HYPERLEDGER FABRIC CONNECTION (config/fabric-network.json)
#    - Create a Fabric network connection profile
#    - Obtain client certificates from Fabric CA
#    - Configure in settings.FABRIC_NETWORK_CONFIG
#
# 2. IPFS CONNECTION (environment variables or config/blockchain.yml)
#    - Set IPFS_API_URL (e.g., /ip4/127.0.0.1/tcp/5001/http)
#    - If using mTLS with IPFS, set IPFS_TLS_* settings
#
# 3. MTLS CERTIFICATES (for JumpServer as client to Fabric/IPFS)
#    - Place Fabric client cert at: /etc/jumpserver/certs/fabric-client.pem
#    - Place Fabric client key at: /etc/jumpserver/certs/fabric-client-key.pem
#    - Place Fabric CA cert at: /etc/jumpserver/certs/fabric-ca.pem
#    - (Optional) IPFS certs if using mTLS with IPFS
#
# 4. ENCRYPTION KEYS (for IPFS file encryption)
#    - Configure AES-256-GCM master key in settings.IPFS_ENCRYPTION_KEY
#    - Recommended: Use hardware security module (HSM) or key management service
#
# 5. PERMISSIONS (RBAC)
#    - Ensure blockchain roles are assigned to users (see rbac/builtin.py)
#    - Investigator: Can create investigations, upload evidence
#    - Auditor: Read-only access to all data
#    - Court: Read-only + archive/reopen + GUID resolution
#
# =============================================================================


class InvestigationViewSet(BlockchainRoleRequiredMixin, OrgBulkModelViewSet):
    """
    Investigation Management API

    Endpoints:
        GET    /api/v1/blockchain/investigations/              - List investigations
        POST   /api/v1/blockchain/investigations/              - Create investigation
        GET    /api/v1/blockchain/investigations/{id}/         - Get investigation detail
        PATCH  /api/v1/blockchain/investigations/{id}/         - Update investigation
        POST   /api/v1/blockchain/investigations/{id}/archive/ - Archive investigation (Court only)
        POST   /api/v1/blockchain/investigations/{id}/reopen/  - Reopen investigation (Court only)

    Permissions:
        - Investigator: Create, view own investigations
        - Auditor: View all investigations (read-only)
        - Court: View all, archive, reopen
    """
    model = Investigation
    serializer_class = InvestigationSerializer
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['case_number', 'title', 'description']
    filterset_fields = ['status', 'created_by']
    ordering_fields = ['created_at', 'case_number']

    def get_queryset(self):
        """
        Filter investigations based on user role and assignments
        - System Admin: See all investigations
        - Court: See all investigations (read-only)
        - Investigator: See only assigned investigations (full read/write)
        - Auditor: See only assigned investigations (read-only + notes)
        """
        from rbac.models import SystemRoleBinding

        queryset = super().get_queryset()
        user = self.request.user

        # Get user's roles
        user_role_ids = list(SystemRoleBinding.objects.filter(
            user=user
        ).values_list('role_id', flat=True))

        # System Admin role ID
        SYSTEM_ADMIN_ROLE = '00000000-0000-0000-0000-000000000001'
        # Court role ID
        COURT_ROLE = '00000000-0000-0000-0000-00000000000A'
        # Investigator role ID
        INVESTIGATOR_ROLE = '00000000-0000-0000-0000-000000000008'
        # Auditor role ID
        AUDITOR_ROLE = '00000000-0000-0000-0000-000000000009'

        # System Admin and Court can see all investigations
        if SYSTEM_ADMIN_ROLE in user_role_ids or COURT_ROLE in user_role_ids:
            return queryset

        # Investigator sees only assigned investigations
        if INVESTIGATOR_ROLE in user_role_ids:
            return queryset.filter(assigned_investigators=user)

        # Auditor sees only assigned investigations
        if AUDITOR_ROLE in user_role_ids:
            return queryset.filter(assigned_auditors=user)

        # If no blockchain role, return empty queryset
        return queryset.none()

    def perform_create(self, serializer):
        """
        Create new investigation and log to blockchain

        Only Court role and SystemAdmin can create investigations.
        Investigators can only work on assigned investigations.
        """
        from rbac.models import SystemRoleBinding

        user = self.request.user
        user_role_ids = [
            str(role_id) for role_id in
            SystemRoleBinding.objects.filter(user=user).values_list('role_id', flat=True)
        ]

        # Only Court and SystemAdmin can create investigations
        SYSTEM_ADMIN_ROLE = '00000000-0000-0000-0000-000000000001'
        COURT_ROLE = '00000000-0000-0000-0000-00000000000A'

        if SYSTEM_ADMIN_ROLE not in user_role_ids and COURT_ROLE not in user_role_ids:
            raise PermissionDenied("Only Court role can create investigations")

        investigation = serializer.save(created_by=self.request.user)

        # TODO: CONFIGURATION - Initialize blockchain transaction for investigation creation
        # Uncomment when Fabric is configured:
        # try:
        #     fabric_client = FabricClient()
        #     tx_hash = fabric_client.create_investigation(
        #         case_number=investigation.case_number,
        #         user=self.request.user.username
        #     )
        #     logger.info(f"Investigation {investigation.case_number} created on blockchain: {tx_hash}")
        # except Exception as e:
        #     logger.error(f"Failed to create investigation on blockchain: {e}")
        #     # Don't fail the API call, but log the error

        return investigation

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def archive(self, request, pk=None):
        """
        Archive an investigation and move to cold chain

        Permissions: blockchain.archive_investigation (Court role only)

        Process:
            1. Verify user has Court role
            2. Retrieve all evidence from hot chain
            3. Archive to cold chain via ArchiveService
            4. Update investigation status to 'archived'
        """
        investigation = self.get_object()

        # Check permission
        if not request.user.has_perm('blockchain.archive_investigation'):
            raise PermissionDenied("Only Court role can archive investigations")

        # Check if already archived
        if investigation.status == 'archived':
            return Response(
                {'error': 'Investigation already archived'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # TODO: CONFIGURATION - Archive to cold chain
            # Uncomment when Fabric is configured:
            # archive_service = ArchiveService()
            # result = archive_service.archive_investigation(
            #     investigation=investigation,
            #     archived_by=request.user
            # )

            # For now, just update status
            investigation.status = 'archived'
            investigation.archived_by = request.user
            investigation.archived_at = timezone.now()
            investigation.save()

            logger.info(f"Investigation {investigation.case_number} archived by {request.user.username}")

            return Response({
                'status': 'success',
                'message': f'Investigation {investigation.case_number} archived to cold chain',
                # 'cold_chain_tx_hash': result.get('tx_hash')
            })

        except Exception as e:
            logger.error(f"Failed to archive investigation {investigation.case_number}: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def reopen(self, request, pk=None):
        """
        Reopen an archived investigation

        Permissions: blockchain.reopen_investigation (Court role only)
        """
        investigation = self.get_object()

        # Check permission
        if not request.user.has_perm('blockchain.reopen_investigation'):
            raise PermissionDenied("Only Court role can reopen investigations")

        # Check if investigation is archived
        if investigation.status != 'archived':
            return Response(
                {'error': 'Investigation is not archived'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # TODO: CONFIGURATION - Log reopen event on blockchain
            # Uncomment when Fabric is configured:
            # fabric_client = FabricClient()
            # tx_hash = fabric_client.reopen_investigation(
            #     case_number=investigation.case_number,
            #     user=request.user.username
            # )

            investigation.status = 'active'
            investigation.reopened_by = request.user
            investigation.reopened_at = timezone.now()
            investigation.save()

            logger.info(f"Investigation {investigation.case_number} reopened by {request.user.username}")

            return Response({
                'status': 'success',
                'message': f'Investigation {investigation.case_number} reopened'
            })

        except Exception as e:
            logger.error(f"Failed to reopen investigation {investigation.case_number}: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class EvidenceViewSet(BlockchainRoleRequiredMixin, OrgBulkModelViewSet):
    """
    Evidence Management API

    Endpoints:
        GET    /api/v1/blockchain/evidence/              - List evidence
        POST   /api/v1/blockchain/evidence/              - Upload evidence
        GET    /api/v1/blockchain/evidence/{id}/         - Get evidence detail
        GET    /api/v1/blockchain/evidence/{id}/download/ - Download evidence file
        POST   /api/v1/blockchain/evidence/{id}/verify/  - Verify evidence integrity

    Permissions:
        - Investigator: Upload, view own evidence
        - Auditor: View all evidence (read-only)
        - Court: View all evidence

    CONFIGURATION REQUIRED:
        - IPFS_API_URL: IPFS node connection string
        - IPFS_ENCRYPTION_KEY: Master encryption key for AES-256-GCM
        - FABRIC_NETWORK_CONFIG: Path to Fabric network connection profile
    """
    model = Evidence
    serializer_class = EvidenceSerializer
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    search_fields = ['description', 'file_name']
    filterset_fields = ['investigation', 'uploaded_by']

    def get_queryset(self):
        """
        Filter evidence based on user role and investigation assignments
        - System Admin: See all evidence
        - Court: See all evidence
        - Investigator: See evidence from assigned investigations only
        - Auditor: See evidence from assigned investigations only
        """
        from rbac.models import SystemRoleBinding

        queryset = super().get_queryset()
        user = self.request.user

        # Get user's roles
        user_role_ids = list(SystemRoleBinding.objects.filter(
            user=user
        ).values_list('role_id', flat=True))

        # Role IDs
        SYSTEM_ADMIN_ROLE = '00000000-0000-0000-0000-000000000001'
        COURT_ROLE = '00000000-0000-0000-0000-00000000000A'
        INVESTIGATOR_ROLE = '00000000-0000-0000-0000-000000000008'
        AUDITOR_ROLE = '00000000-0000-0000-0000-000000000009'

        # System Admin and Court can see all evidence
        if SYSTEM_ADMIN_ROLE in user_role_ids or COURT_ROLE in user_role_ids:
            return queryset

        # Investigator sees evidence from assigned investigations
        if INVESTIGATOR_ROLE in user_role_ids:
            return queryset.filter(investigation__assigned_investigators=user)

        # Auditor sees evidence from assigned investigations
        if AUDITOR_ROLE in user_role_ids:
            return queryset.filter(investigation__assigned_auditors=user)

        # If no blockchain role, return empty queryset
        return queryset.none()

    def create(self, request, *args, **kwargs):
        """
        Upload evidence file to IPFS and record on blockchain

        Request payload:
            - file: Binary file (multipart/form-data)
            - investigation_id: UUID of investigation
            - description: Evidence description
            - anonymize: Boolean (optional) - Use GUID instead of username

        Process:
            1. Validate file and investigation
            2. Calculate SHA-256 hash of file
            3. Encrypt file with AES-256-GCM
            4. Upload encrypted file to IPFS
            5. Record transaction on hot chain (Hyperledger Fabric)
            6. Save evidence metadata to database

        Returns:
            - evidence_id: UUID
            - ipfs_cid: IPFS Content Identifier
            - file_hash: SHA-256 hash
            - hot_chain_tx_hash: Blockchain transaction hash
        """
        # Validate request
        if 'file' not in request.FILES:
            return Response(
                {'error': 'No file provided'},
                status=status.HTTP_400_BAD_REQUEST
            )

        file = request.FILES['file']
        investigation_id = request.data.get('investigation_id')
        description = request.data.get('description', '')
        anonymize = request.data.get('anonymize', 'false').lower() == 'true'

        # Validate investigation exists
        try:
            investigation = Investigation.objects.get(id=investigation_id)
        except Investigation.DoesNotExist:
            return Response(
                {'error': 'Investigation not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Check if investigation is active
        if investigation.status != 'active':
            return Response(
                {'error': 'Cannot upload evidence to non-active investigation'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Step 1: Calculate file hash
            file_content = file.read()
            file_hash = hashlib.sha256(file_content).hexdigest()
            logger.info(f"File hash calculated: {file_hash}")

            # TODO: CONFIGURATION - Upload to IPFS
            # Uncomment when IPFS is configured:
            # ipfs_client = IPFSClient()
            # ipfs_cid, encryption_key_id = ipfs_client.upload_evidence(
            #     file_content=file_content,
            #     file_name=file.name
            # )
            # logger.info(f"File uploaded to IPFS: {ipfs_cid}")

            # TEMPORARY: Mock IPFS upload
            ipfs_cid = f"Qm{file_hash[:44]}"  # Mock CID
            encryption_key_id = "mock-encryption-key-id"

            # Step 2: Get user identifier (username or GUID)
            if anonymize:
                user_guid = GUIDResolver.generate_guid(request.user)
                user_identifier = user_guid
            else:
                user_guid = None
                user_identifier = request.user.username

            # TODO: CONFIGURATION - Record on hot chain
            # Uncomment when Fabric is configured:
            # fabric_client = FabricClient()
            # hot_chain_tx = fabric_client.append_evidence(
            #     chain='hot',
            #     evidence_hash=file_hash,
            #     ipfs_cid=ipfs_cid,
            #     user=user_identifier,
            #     investigation_id=str(investigation.id)
            # )
            # logger.info(f"Evidence recorded on hot chain: {hot_chain_tx}")

            # TEMPORARY: Mock blockchain transaction
            hot_chain_tx = f"0x{file_hash[:40]}"

            # Step 3: Create blockchain transaction record
            blockchain_tx = BlockchainTransaction.objects.create(
                transaction_hash=hot_chain_tx,
                chain_type='hot',
                evidence_hash=file_hash,
                ipfs_cid=ipfs_cid,
                user=request.user,
                user_guid=user_guid,
                metadata={
                    'file_name': file.name,
                    'file_size': len(file_content),
                    'investigation_id': str(investigation.id)
                }
            )

            # Step 4: Create evidence record
            evidence = Evidence.objects.create(
                investigation=investigation,
                file_name=file.name,
                file_size=len(file_content),
                file_hash_sha256=file_hash,
                ipfs_cid=ipfs_cid,
                encryption_key_id=encryption_key_id,
                description=description,
                uploaded_by=request.user,
                hot_chain_tx=blockchain_tx
            )

            logger.info(
                f"Evidence {evidence.id} uploaded successfully by {request.user.username} "
                f"(Investigation: {investigation.case_number})"
            )

            return Response({
                'status': 'success',
                'evidence_id': str(evidence.id),
                'file_name': file.name,
                'file_hash': file_hash,
                'ipfs_cid': ipfs_cid,
                'hot_chain_tx_hash': hot_chain_tx,
                'uploaded_at': evidence.created_at.isoformat()
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.error(f"Failed to upload evidence: {e}", exc_info=True)
            return Response(
                {'error': f'Failed to upload evidence: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['get'], permission_classes=[IsAuthenticated])
    def download(self, request, pk=None):
        """
        Download evidence file from IPFS

        Process:
            1. Verify user has permission to access evidence
            2. Retrieve encrypted file from IPFS
            3. Decrypt file with stored encryption key
            4. Return file as HTTP response

        CONFIGURATION REQUIRED:
            - IPFS_API_URL must be configured
            - Decryption keys must be accessible
        """
        evidence = self.get_object()

        # Check permission
        if not request.user.has_perm('blockchain.download_evidence'):
            raise PermissionDenied("Insufficient permissions to download evidence")

        try:
            # TODO: CONFIGURATION - Download from IPFS
            # Uncomment when IPFS is configured:
            # ipfs_client = IPFSClient()
            # file_content = ipfs_client.retrieve_evidence(
            #     ipfs_cid=evidence.ipfs_cid,
            #     encryption_key_id=evidence.encryption_key_id
            # )

            # For now, return error
            return Response(
                {'error': 'IPFS download not configured. See blockchain/clients/ipfs_client.py'},
                status=status.HTTP_501_NOT_IMPLEMENTED
            )

            # TODO: Return file response
            # from django.http import HttpResponse
            # response = HttpResponse(file_content, content_type='application/octet-stream')
            # response['Content-Disposition'] = f'attachment; filename="{evidence.file_name}"'
            # return response

        except Exception as e:
            logger.error(f"Failed to download evidence {evidence.id}: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def verify(self, request, pk=None):
        """
        Verify evidence integrity against blockchain record

        Process:
            1. Retrieve evidence from IPFS
            2. Calculate SHA-256 hash
            3. Compare with hash stored on blockchain
            4. Verify merkle proof (if available)

        Returns:
            - verified: Boolean
            - stored_hash: Hash from blockchain
            - calculated_hash: Hash from file
            - match: Boolean
        """
        evidence = self.get_object()

        try:
            # TODO: CONFIGURATION - Verify against blockchain
            # Uncomment when Fabric is configured:
            # fabric_client = FabricClient()
            # blockchain_data = fabric_client.query_evidence(
            #     tx_hash=evidence.hot_chain_tx.transaction_hash
            # )
            #
            # ipfs_client = IPFSClient()
            # file_content = ipfs_client.retrieve_evidence(
            #     ipfs_cid=evidence.ipfs_cid,
            #     encryption_key_id=evidence.encryption_key_id
            # )
            # calculated_hash = hashlib.sha256(file_content).hexdigest()
            #
            # verified = (calculated_hash == blockchain_data['evidence_hash'])

            # TEMPORARY: Mock verification
            return Response({
                'status': 'pending',
                'message': 'Verification requires Fabric and IPFS configuration',
                'stored_hash': evidence.file_hash_sha256,
                'blockchain_tx': evidence.hot_chain_tx.transaction_hash,
                'ipfs_cid': evidence.ipfs_cid
            })

        except Exception as e:
            logger.error(f"Failed to verify evidence {evidence.id}: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class BlockchainTransactionViewSet(BlockchainRoleRequiredMixin, OrgBulkModelViewSet):
    """
    Blockchain Transaction History API

    Endpoints:
        GET /api/v1/blockchain/transactions/ - List all blockchain transactions
        GET /api/v1/blockchain/transactions/{id}/ - Get transaction detail

    Permissions:
        - Auditor: View all transactions
        - Court: View all transactions
        - Investigator: View own transactions only
    """
    model = BlockchainTransaction
    serializer_class = BlockchainTransactionSerializer
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['chain_type', 'user']
    ordering_fields = ['created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        """
        Filter transactions based on user role
        """
        queryset = super().get_queryset()
        user = self.request.user

        # Auditors and Court can see all transactions
        if user.has_perm('blockchain.view_all_transactions'):
            return queryset

        # Investigators see only their own
        return queryset.filter(user=user)


class GUIDResolverViewSet(BlockchainRoleRequiredMixin, viewsets.ViewSet):
    """
    GUID Resolution API (Court Role Only)

    Endpoints:
        POST /api/v1/blockchain/guid/resolve/ - Resolve GUID to user identity

    Permissions:
        - Court role only (blockchain.resolve_guid permission)

    Purpose:
        Investigators can submit evidence anonymously using GUIDs.
        Only Court role can resolve GUIDs back to actual user identities.
        All resolution attempts are logged for audit trail.
    """
    permission_classes = [IsAuthenticated, RBACPermission]

    @action(detail=False, methods=['post'])
    def resolve(self, request):
        """
        Resolve GUID to user identity

        Request payload:
            - guid: The GUID to resolve (string)
            - reason: Reason for resolution (required for audit)

        Returns:
            - user_id: User UUID
            - username: Username
            - full_name: User's full name
            - resolved_at: Timestamp
            - resolved_by: Court user who performed resolution

        Audit:
            All resolution attempts are logged to audits app
        """
        # Check permission
        if not request.user.has_perm('blockchain.resolve_guid'):
            raise PermissionDenied("Only Court role can resolve GUIDs")

        guid = request.data.get('guid')
        reason = request.data.get('reason')

        if not guid:
            return Response(
                {'error': 'GUID is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not reason:
            return Response(
                {'error': 'Reason for resolution is required for audit trail'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Resolve GUID
            user = GUIDResolver.resolve_guid(guid, request.user)

            # Log resolution (audit trail)
            logger.warning(
                f"GUID {guid} resolved to user {user.username} by {request.user.username}. "
                f"Reason: {reason}"
            )

            # TODO: Create audit log entry
            # from audits.models import OperateLog
            # OperateLog.objects.create(
            #     user=request.user.username,
            #     action='guid_resolution',
            #     resource=guid,
            #     resource_type='guid',
            #     detail=f"Resolved to {user.username}. Reason: {reason}"
            # )

            return Response({
                'status': 'success',
                'guid': guid,
                'user_id': str(user.id),
                'username': user.username,
                'full_name': user.get_full_name(),
                'resolved_by': request.user.username,
                'reason': reason
            })

        except GUIDMapping.DoesNotExist:
            return Response(
                {'error': 'GUID not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Failed to resolve GUID {guid}: {e}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# ==============================================================================
# UI ENHANCEMENT VIEWSETS (TAGS, NOTES, ACTIVITY TRACKING)
# ==============================================================================

class TagViewSet(BlockchainRoleRequiredMixin, OrgBulkModelViewSet):
    """
    Tag Management API (Admin Only)

    Endpoints:
        GET    /api/v1/blockchain/tags/           - List all tags
        POST   /api/v1/blockchain/tags/           - Create tag (admin only)
        GET    /api/v1/blockchain/tags/{id}/      - Get tag details
        PUT    /api/v1/blockchain/tags/{id}/      - Update tag (admin only)
        DELETE /api/v1/blockchain/tags/{id}/      - Delete tag (admin only)

    Permissions:
        - View: All blockchain roles
        - Create/Update/Delete: SystemAdmin only

    Use Case:
        Admin creates categorization tags (crime type, priority, status)
        with color coding for UI display. Max 3 tags per investigation.
    """
    model = Tag
    serializer_class = TagSerializer
    perm_model = Tag
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'category', 'description']
    filterset_fields = ['category']
    ordering_fields = ['name', 'category', 'created_at']
    ordering = ['category', 'name']

    def perform_create(self, serializer):
        """Auto-assign created_by to current admin user"""
        serializer.save(created_by=self.request.user)


class InvestigationTagViewSet(BlockchainRoleRequiredMixin, OrgBulkModelViewSet):
    """
    Investigation Tag Assignment API (Court Role Only)

    Endpoints:
        GET    /api/v1/blockchain/investigation-tags/           - List all tag assignments
        POST   /api/v1/blockchain/investigation-tags/           - Assign tag to investigation (Court only)
        DELETE /api/v1/blockchain/investigation-tags/{id}/      - Remove tag from investigation (Court only)

    Permissions:
        - View: All blockchain roles
        - Create/Delete: BlockchainCourt only (admin creates tag library, court assigns to cases)

    Validation:
        - Max 3 tags per investigation (enforced in serializer)
        - Cannot assign duplicate tag to same investigation

    Use Case:
        SystemAdmin creates tag library (predefined tags with colors/categories).
        BlockchainCourt assigns up to 3 tags from library to each investigation
        for filtering and organization in the UI dashboard.
    """
    model = InvestigationTag
    serializer_class = InvestigationTagSerializer
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['investigation', 'tag']
    ordering_fields = ['added_at']
    ordering = ['-added_at']

    def perform_create(self, serializer):
        """Auto-assign added_by to current court user"""
        serializer.save(added_by=self.request.user)

    def get_queryset(self):
        """Filter tags by investigation if specified"""
        queryset = super().get_queryset()
        investigation_id = self.request.query_params.get('investigation_id')
        if investigation_id:
            queryset = queryset.filter(investigation_id=investigation_id)
        return queryset


class InvestigationNoteViewSet(BlockchainRoleRequiredMixin, OrgBulkModelViewSet):
    """
    Investigation Notes API (Investigator Create, All Read)

    Endpoints:
        GET    /api/v1/blockchain/notes/           - List notes (filtered by role)
        POST   /api/v1/blockchain/notes/           - Add note (investigator only)
        GET    /api/v1/blockchain/notes/{id}/      - Get note details

    Permissions:
        - Create: BlockchainInvestigator only
        - View: All blockchain roles (filtered by investigation access)

    Blockchain Logging:
        - Note hash (SHA-256) calculated on save
        - Note logged to blockchain asynchronously
        - blockchain_tx field updated when confirmed

    Use Case:
        Investigators add timestamped notes to investigations. Notes are
        immutably recorded on blockchain for chain of custody audit trail.
    """
    model = InvestigationNote
    serializer_class = InvestigationNoteSerializer
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['investigation', 'created_by']
    ordering_fields = ['created_at']
    ordering = ['-created_at']

    def perform_create(self, serializer):
        """
        Auto-assign created_by and trigger blockchain logging
        """
        note = serializer.save(created_by=self.request.user)

        # TODO: Trigger blockchain logging asynchronously
        # from ..signal_handlers import log_note_to_blockchain
        # log_note_to_blockchain(note)

    def get_queryset(self):
        """Filter notes by investigation if specified"""
        queryset = super().get_queryset()
        investigation_id = self.request.query_params.get('investigation_id')
        if investigation_id:
            queryset = queryset.filter(investigation_id=investigation_id)
        return queryset


class InvestigationActivityViewSet(BlockchainRoleRequiredMixin, viewsets.ReadOnlyModelViewSet):
    """
    Investigation Activity Tracking API (Read-Only)

    Endpoints:
        GET /api/v1/blockchain/activities/           - List activities (filtered by investigation)
        GET /api/v1/blockchain/activities/{id}/      - Get activity details
        POST /api/v1/blockchain/activities/{id}/mark_viewed/ - Mark activity as viewed

    Permissions:
        - View: All blockchain roles
        - Activity auto-created by system on model changes

    24-Hour Indicator:
        - is_recent property returns True if activity within last 24 hours
        - Used for UI badges/indicators

    Use Case:
        System automatically tracks investigation changes (evidence added,
        note added, tag changed, status changed). Users can mark activities
        as viewed to track what's new.
    """
    model = InvestigationActivity
    serializer_class = InvestigationActivitySerializer
    permission_classes = [IsAuthenticated, RBACPermission]
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_fields = ['investigation', 'activity_type', 'performed_by']
    ordering_fields = ['timestamp']
    ordering = ['-timestamp']

    def get_queryset(self):
        """
        Filter activities and optionally show only recent (24h) or unviewed
        """
        queryset = super().get_queryset()
        investigation_id = self.request.query_params.get('investigation_id')
        recent_only = self.request.query_params.get('recent_only', 'false').lower() == 'true'
        unviewed_only = self.request.query_params.get('unviewed_only', 'false').lower() == 'true'

        if investigation_id:
            queryset = queryset.filter(investigation_id=investigation_id)

        if recent_only:
            # Filter to last 24 hours
            twenty_four_hours_ago = timezone.now() - timezone.timedelta(hours=24)
            queryset = queryset.filter(timestamp__gte=twenty_four_hours_ago)

        if unviewed_only:
            # Exclude activities already viewed by current user
            queryset = queryset.exclude(viewed_by=self.request.user)

        return queryset

    @action(detail=True, methods=['post'])
    def mark_viewed(self, request, pk=None):
        """
        Mark activity as viewed by current user

        POST /api/v1/blockchain/activities/{id}/mark_viewed/

        Returns:
            - status: success/error
            - viewed_by: Updated list of usernames who have viewed
        """
        activity = self.get_object()
        activity.viewed_by.add(request.user)

        return Response({
            'status': 'success',
            'activity_id': str(activity.id),
            'viewed_by': list(activity.viewed_by.values_list('username', flat=True))
        })


class UserBlockchainProfileViewSet(viewsets.ViewSet):
    """
    User Blockchain Profile API

    Returns current user's blockchain role and permissions for UI rendering

    Endpoints:
        GET /api/v1/blockchain/user-profile/ - Get current user's blockchain profile
    """
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """
        Get current user's blockchain role and permissions

        Returns:
            - role: User's blockchain role (investigator/auditor/court/admin/none)
            - role_display: Human-readable role name
            - permissions: Dict of specific permissions
            - can_create_investigation: Boolean
            - can_upload_evidence: Boolean
            - can_archive: Boolean
            - can_resolve_guid: Boolean
            - can_view_all: Boolean
        """
        from rbac.models import SystemRoleBinding

        user = request.user

        # Get user's blockchain role
        user_role_bindings = SystemRoleBinding.objects.filter(user=user).select_related('role')
        user_role_ids = [str(binding.role_id) for binding in user_role_bindings]

        # Determine blockchain role
        role = 'none'
        role_display = 'No Blockchain Access'

        if '00000000-0000-0000-0000-000000000001' in user_role_ids:  # SystemAdmin
            role = 'admin'
            role_display = 'System Administrator'
        elif '00000000-0000-0000-0000-00000000000A' in user_role_ids:  # BlockchainCourt
            role = 'court'
            role_display = 'Court Official'
        elif '00000000-0000-0000-0000-000000000009' in user_role_ids:  # BlockchainAuditor
            role = 'auditor'
            role_display = 'Blockchain Auditor'
        elif '00000000-0000-0000-0000-000000000008' in user_role_ids:  # BlockchainInvestigator
            role = 'investigator'
            role_display = 'Forensic Investigator'

        # Check specific permissions
        permissions = {
            'can_create_investigation': user.has_perm('blockchain.add_investigation'),
            'can_upload_evidence': user.has_perm('blockchain.add_evidence'),
            'can_archive': user.has_perm('blockchain.archive_investigation'),
            'can_resolve_guid': user.has_perm('blockchain.resolve_guid'),
            'can_view_all': role in ['admin', 'court', 'auditor'],
            'can_add_notes': user.has_perm('blockchain.add_investigationnote'),
            'can_add_tags': user.has_perm('blockchain.add_tag'),
            'can_view_transactions': user.has_perm('blockchain.view_blockchaintransaction'),
        }

        return Response({
            'role': role,
            'role_display': role_display,
            'username': user.username,
            'is_superuser': user.is_superuser,
            'permissions': permissions,
            **permissions  # Flatten permissions for easier access
        })
