/**
 * Role-Based Access Control (RBAC) Middleware
 *
 * Enforces role-based permissions for evidence operations.
 * Supports 5 roles: Investigator, LabAnalyst, CourtUser, Auditor, Admin
 */

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { logger } from '../index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load RBAC configuration
let rbacConfig;
try {
  const configPath = path.join(__dirname, '../../rbac/roles.json');
  const configData = await fs.readFile(configPath, 'utf8');
  rbacConfig = JSON.parse(configData);
} catch (error) {
  logger.error('Failed to load RBAC configuration:', error);
  throw error;
}

/**
 * Check if a user has a specific permission
 */
export function hasPermission(userRole, requiredPermission) {
  const role = rbacConfig.roles[userRole];

  if (!role) {
    return false;
  }

  // Check for wildcard permission (admin)
  if (role.permissions.includes('evidence:*') || role.permissions.includes('ipfs:*')) {
    const [resource] = requiredPermission.split(':');
    if (role.permissions.includes(`${resource}:*`)) {
      return true;
    }
  }

  // Check for exact permission
  return role.permissions.includes(requiredPermission);
}

/**
 * Check if a user's organization matches the required MSP
 */
export function hasOrgAccess(userRole, userOrgMSP) {
  const role = rbacConfig.roles[userRole];

  if (!role) {
    return false;
  }

  // If role has array of allowed MSPs
  if (Array.isArray(role.orgMSP)) {
    return role.orgMSP.includes(userOrgMSP);
  }

  // If role has single MSP requirement
  return role.orgMSP === userOrgMSP || role.orgMSP === '*';
}

/**
 * RBAC middleware factory
 * Creates middleware that checks for specific permissions
 */
export function requirePermission(permission) {
  return (req, res, next) => {
    const user = req.user;

    if (!user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication required'
      });
    }

    if (!hasPermission(user.role, permission)) {
      logger.warn(`Access denied for user ${user.id} (role: ${user.role}) - missing permission: ${permission}`);
      return res.status(403).json({
        error: 'Forbidden',
        message: `Insufficient permissions. Required: ${permission}`
      });
    }

    // Check organization access
    if (!hasOrgAccess(user.role, user.orgMSP)) {
      logger.warn(`Access denied for user ${user.id} - organization mismatch`);
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Organization access denied'
      });
    }

    next();
  };
}

/**
 * General RBAC middleware
 * Attaches permission checker to request object
 */
export function rbacMiddleware(req, res, next) {
  // Attach permission checker to request
  req.hasPermission = (permission) => {
    if (!req.user) return false;
    return hasPermission(req.user.role, permission);
  };

  // Attach org access checker to request
  req.hasOrgAccess = () => {
    if (!req.user) return false;
    return hasOrgAccess(req.user.role, req.user.orgMSP);
  };

  next();
}

/**
 * Get all permissions for a role
 */
export function getRolePermissions(role) {
  return rbacConfig.roles[role]?.permissions || [];
}

/**
 * Get all available roles
 */
export function getAllRoles() {
  return Object.keys(rbacConfig.roles);
}

/**
 * Validate if a role exists
 */
export function isValidRole(role) {
  return rbacConfig.roles.hasOwnProperty(role);
}

export default {
  rbacMiddleware,
  requirePermission,
  hasPermission,
  hasOrgAccess,
  getRolePermissions,
  getAllRoles,
  isValidRole
};
