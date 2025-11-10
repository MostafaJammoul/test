import { format, formatDistanceToNow } from 'date-fns';

/**
 * Format date to readable string
 */
export const formatDate = (dateString) => {
  if (!dateString) return 'N/A';
  try {
    return format(new Date(dateString), 'MMM dd, yyyy HH:mm');
  } catch (error) {
    return dateString;
  }
};

/**
 * Format date to relative time (e.g., "2 hours ago")
 */
export const formatRelativeTime = (dateString) => {
  if (!dateString) return 'N/A';
  try {
    return formatDistanceToNow(new Date(dateString), { addSuffix: true });
  } catch (error) {
    return dateString;
  }
};

/**
 * Format file size to human-readable string
 */
export const formatFileSize = (bytes) => {
  if (bytes === 0) return '0 Bytes';
  if (!bytes) return 'N/A';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
};

/**
 * Truncate hash to display format
 */
export const formatHash = (hash, length = 16) => {
  if (!hash) return 'N/A';
  if (hash.length <= length) return hash;
  return `${hash.substring(0, length)}...`;
};

/**
 * Format IPFS CID for display
 */
export const formatIPFSCID = (cid) => {
  if (!cid) return 'N/A';
  if (cid.length <= 20) return cid;
  return `${cid.substring(0, 10)}...${cid.substring(cid.length - 10)}`;
};

/**
 * Check if date is within last 24 hours
 */
export const isRecent = (dateString) => {
  if (!dateString) return false;
  try {
    const date = new Date(dateString);
    const now = new Date();
    const diff = (now - date) / 1000; // seconds
    return diff < 86400; // 24 hours
  } catch (error) {
    return false;
  }
};
