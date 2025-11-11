# Role-Based Dashboard Implementation Plan

## Overview
This document outlines the implementation of role-specific dashboards with investigation assignment-based access control.

## Database Changes

### 1. Investigation Model Updates
**File**: `apps/blockchain/models.py`

Added fields:
```python
assigned_investigators = models.ManyToManyField(User, ...)
assigned_auditors = models.ManyToManyField(User, ...)
```

**Migration**: `apps/blockchain/migrations/0002_add_investigation_assignments.py`

## Backend API Changes

### 2. Investigation ViewSet Filtering
**File**: `apps/blockchain/api/views.py`

Updated `get_queryset()` logic:
- **System Admin**: See all investigations
- **Court**: See all investigations (read-only)
- **Investigator**: See only assigned investigations (full read/write)
- **Auditor**: See only assigned investigations (read-only, can add notes)

### 3. Evidence ViewSet Filtering
Same assignment-based filtering applied to evidence access.

## Frontend Components

### 4. Role-Specific Dashboard Components

#### A. Investigator Dashboard (`frontend/src/pages/dashboard/InvestigatorDashboard.jsx`)
**Features**:
- View assigned investigations only
- Create/update evidence on assigned cases
- Upload files
- Add notes to investigations
- Tag investigations (max 3 tags)
- View blockchain transactions

**Restrictions**:
- Cannot archive/reopen cases
- Cannot access unassigned cases
- Cannot resolve GUIDs

#### B. Auditor Dashboard (`frontend/src/pages/dashboard/AuditorDashboard.jsx`)
**Features**:
- View assigned investigations only
- View all evidence details
- Add notes to investigations
- View blockchain transactions
- View activity logs

**Restrictions**:
- Cannot download evidence files
- Cannot upload evidence
- Cannot modify case details
- Cannot create investigations

#### C. Court Dashboard (`frontend/src/pages/dashboard/CourtDashboard.jsx`)
**Features**:
- View ALL investigations (read-only)
- View all evidence and blockchain records
- Download evidence
- Resolve GUIDs (unmask anonymous investigators)
- View audit trails

**Restrictions**:
- Cannot modify investigations
- Cannot upload evidence
- Cannot add notes
- Read-only access

### 5. Investigation Detail Page Enhancement
**File**: `frontend/src/pages/dashboard/InvestigationDetailPage.jsx`

Added tabs:
1. **Overview** - Case details, tags
2. **Evidence** - Evidence list with blockchain verification
3. **Notes** - Investigation notes with user attribution
4. **Blockchain** - Transaction history
5. **Activity** - Recent activities

Notes tab features:
- Display all notes chronologically
- Show author and timestamp
- Add new note (if permitted by role)
- Notes are hashed and logged to blockchain

## API Endpoints

### Investigation Notes
- `GET /api/v1/blockchain/investigations/{id}/notes/` - List notes
- `POST /api/v1/blockchain/investigations/{id}/notes/` - Add note
- Notes automatically logged to blockchain with SHA-256 hash

### Role-Based Filtering
All endpoints automatically filter based on:
1. User's role (Admin, Investigator, Auditor, Court)
2. Investigation assignments
3. Permissions from RBAC system

## Permissions Matrix

| Action | System Admin | Investigator | Auditor | Court |
|--------|-------------|-------------|---------|-------|
| View all investigations | ✅ | ❌ | ❌ | ✅ |
| View assigned investigations | ✅ | ✅ | ✅ | ✅ |
| Create investigation | ✅ | ✅ | ❌ | ❌ |
| Update investigation | ✅ | ✅ (assigned) | ❌ | ❌ |
| Archive investigation | ✅ | ❌ | ❌ | ❌ |
| Reopen investigation | ✅ | ❌ | ❌ | ❌ |
| Upload evidence | ✅ | ✅ (assigned) | ❌ | ❌ |
| Download evidence | ✅ | ✅ (assigned) | ❌ | ✅ |
| Add notes | ✅ | ✅ (assigned) | ✅ (assigned) | ❌ |
| View notes | ✅ | ✅ (assigned) | ✅ (assigned) | ✅ |
| Resolve GUID | ✅ | ❌ | ❌ | ✅ |
| Assign investigators/auditors | ✅ | ❌ | ❌ | ❌ |

## Testing Workflow

### Password Login (Already Working)
1. Access http://192.168.148.154:3000
2. Login with username/password
3. Complete MFA setup (first login)
4. Redirected to role-specific dashboard
5. Test features based on role

### Certificate Login (Requires nginx configuration)
1. Import certificate (.p12 file) into browser
2. Access https://192.168.148.154 (via nginx)
3. Browser presents certificate
4. mTLS middleware authenticates user
5. Complete MFA setup (first login)
6. Redirected to role-specific dashboard
7. Test features based on role

## Implementation Status

✅ Migration created
✅ Model updated
⏳ API views updating
⏳ Frontend components creating
⏳ Testing workflows

## Files Modified/Created

### Backend
- `apps/blockchain/models.py` - Added assignment fields
- `apps/blockchain/migrations/0002_add_investigation_assignments.py` - New migration
- `apps/blockchain/api/views.py` - Updated filtering logic
- `apps/blockchain/api/serializers.py` - Added assignment fields to serializers

### Frontend
- `frontend/src/pages/dashboard/InvestigatorDashboard.jsx` - New
- `frontend/src/pages/dashboard/AuditorDashboard.jsx` - New
- `frontend/src/pages/dashboard/CourtDashboard.jsx` - New
- `frontend/src/pages/dashboard/InvestigationDetailPage.jsx` - Enhanced with notes tab
- `frontend/src/pages/dashboard/Dashboard.jsx` - Updated to route based on role
- `frontend/src/components/investigation/NotesTab.jsx` - New notes component

