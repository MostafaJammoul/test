// Blockchain role IDs (must match Django RBAC)
export const ROLES = {
  SYSTEM_ADMIN: '00000000-0000-0000-0000-000000000001',
  BLOCKCHAIN_INVESTIGATOR: '00000000-0000-0000-0000-000000000008',
  BLOCKCHAIN_AUDITOR: '00000000-0000-0000-0000-000000000009',
  BLOCKCHAIN_COURT: '00000000-0000-0000-0000-00000000000A',
};

// Role display names
export const ROLE_NAMES = {
  [ROLES.SYSTEM_ADMIN]: 'System Administrator',
  [ROLES.BLOCKCHAIN_INVESTIGATOR]: 'Investigator',
  [ROLES.BLOCKCHAIN_AUDITOR]: 'Auditor',
  [ROLES.BLOCKCHAIN_COURT]: 'Court',
};

// Role colors (matches tailwind.config.js)
export const ROLE_COLORS = {
  [ROLES.SYSTEM_ADMIN]: 'bg-red-100 text-red-800',
  [ROLES.BLOCKCHAIN_INVESTIGATOR]: 'bg-green-100 text-green-800',
  [ROLES.BLOCKCHAIN_AUDITOR]: 'bg-indigo-100 text-indigo-800',
  [ROLES.BLOCKCHAIN_COURT]: 'bg-purple-100 text-purple-800',
};

// Investigation statuses
export const INVESTIGATION_STATUS = {
  ACTIVE: 'active',
  ARCHIVED: 'archived',
};

// Status display
export const STATUS_DISPLAY = {
  [INVESTIGATION_STATUS.ACTIVE]: 'Active',
  [INVESTIGATION_STATUS.ARCHIVED]: 'Archived',
};

// Status colors
export const STATUS_COLORS = {
  [INVESTIGATION_STATUS.ACTIVE]: 'bg-green-100 text-green-800',
  [INVESTIGATION_STATUS.ARCHIVED]: 'bg-gray-100 text-gray-800',
};

// Activity types
export const ACTIVITY_TYPES = {
  EVIDENCE_ADDED: 'evidence_added',
  NOTE_ADDED: 'note_added',
  TAG_CHANGED: 'tag_changed',
  STATUS_CHANGED: 'status_changed',
  ASSIGNED: 'assigned',
};

// Activity type display
export const ACTIVITY_TYPE_DISPLAY = {
  [ACTIVITY_TYPES.EVIDENCE_ADDED]: 'Evidence Added',
  [ACTIVITY_TYPES.NOTE_ADDED]: 'Note Added',
  [ACTIVITY_TYPES.TAG_CHANGED]: 'Tag Changed',
  [ACTIVITY_TYPES.STATUS_CHANGED]: 'Status Changed',
  [ACTIVITY_TYPES.ASSIGNED]: 'Assigned',
};

// Tag categories
export const TAG_CATEGORIES = {
  CRIME_TYPE: 'crime_type',
  PRIORITY: 'priority',
  STATUS: 'status',
};

// Tag category display
export const TAG_CATEGORY_DISPLAY = {
  [TAG_CATEGORIES.CRIME_TYPE]: 'Crime Type',
  [TAG_CATEGORIES.PRIORITY]: 'Priority',
  [TAG_CATEGORIES.STATUS]: 'Status',
};

// Chain types
export const CHAIN_TYPES = {
  HOT: 'hot',
  COLD: 'cold',
};

// Chain type display
export const CHAIN_TYPE_DISPLAY = {
  [CHAIN_TYPES.HOT]: 'Hot Chain',
  [CHAIN_TYPES.COLD]: 'Cold Chain',
};

// Chain type colors
export const CHAIN_TYPE_COLORS = {
  [CHAIN_TYPES.HOT]: 'bg-amber-100 text-amber-800',
  [CHAIN_TYPES.COLD]: 'bg-blue-100 text-blue-800',
};

// Max tags per investigation
export const MAX_TAGS_PER_INVESTIGATION = 3;
