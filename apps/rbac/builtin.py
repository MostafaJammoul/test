from django.utils.translation import gettext_noop

from .const import Scope, system_exclude_permissions, org_exclude_permissions

_view_root_perms = (
    ('orgs', 'organization', 'view', 'rootorg'),
)
_view_all_joined_org_perms = (
    ('orgs', 'organization', 'view', 'alljoinedorg'),
)

user_perms = (
    ('rbac', 'menupermission', 'view', 'workbench'),
    ('rbac', 'menupermission', 'view', 'webterminal'),
    ('rbac', 'menupermission', 'view', 'filemanager'),
    ('perms', 'permedasset', 'view,connect', 'myassets'),
    ('perms', 'permedapplication', 'view,connect', 'myapps'),
    ('assets', 'asset', 'match', 'asset'),
    ('assets', 'systemuser', 'match', 'systemuser'),
    ('assets', 'node', 'match', 'node'),
    ("ops", "adhoc", "*", "*"),
    ("ops", "playbook", "*", "*"),
    ("ops", "job", "*", "*"),
    ("ops", "jobexecution", "*", "*"),
    ("ops", "celerytaskexecution", "view", "*"),
)

system_user_perms = (
    ('authentication', 'connectiontoken', 'add,view,reuse,expire', 'connectiontoken'),
    ('authentication', 'temptoken', 'add,change,view', 'temptoken'),
    ('authentication', 'accesskey', '*', '*'),
    ('authentication', 'passkey', '*', '*'),
    ('authentication', 'sshkey', '*', '*'),
    ('tickets', 'ticket', 'view', 'ticket'),
)
system_user_perms += (user_perms + _view_all_joined_org_perms)

_auditor_perms = (
    ('rbac', 'menupermission', 'view', 'audit'),
    ('rbac', 'menupermission', 'view', 'userloginreport'),
    ('rbac', 'menupermission', 'view', 'userchangepasswordreport'),
    ('rbac', 'menupermission', 'view', 'assetstatisticsreport'),
    ('rbac', 'menupermission', 'view', 'assetactivityreport'),
    ('rbac', 'menupermission', 'view', 'accountstatisticsreport'),
    ('rbac', 'menupermission', 'view', 'accountautomationreport'),
    ('assets', 'asset', 'view', 'asset'),
    ('users', 'user', 'view', 'user'),
    ('audits', '*', '*', '*'),
    ('audits', 'joblog', '*', '*'),
    ('terminal', 'commandstorage', 'view', 'commandstorage'),
    ('terminal', 'sessionreplay', 'view,download', 'sessionreplay'),
    ('terminal', 'session', '*', '*'),
    ('terminal', 'command', '*', '*'),
)

auditor_perms = user_perms + _auditor_perms

system_auditor_perms = system_user_perms + _auditor_perms + _view_root_perms

app_exclude_perms = [
    ('users', 'user', 'add,delete', 'user'),
    ('orgs', 'org', 'add,delete,change', 'org'),
    ('rbac', '*', '*', '*'),
]

# ==============================================================================
# BLOCKCHAIN SECURITY HARDENING - EXCLUDE BLOCKCHAIN FROM LEGACY ROLES
# ==============================================================================
# Prevent legacy JumpServer roles (SystemAuditor, OrgAdmin, etc.) from
# accessing blockchain evidence features to maintain chain of custody integrity
legacy_role_blockchain_exclude_perms = [
    ('blockchain', '*', '*', '*'),  # No blockchain model access
    ('pki', 'certificate', 'add,delete,change', '*'),  # No cert management
    ('pki', 'certificateauthority', '*', '*'),  # No CA access
]
# ==============================================================================

need_check = [
    *auditor_perms, *user_perms, *app_exclude_perms,
    *system_exclude_permissions, *org_exclude_permissions
]
defines_errors = [d for d in need_check if len(d) != 4]
if len(defines_errors) != 0:
    raise ValueError('Perms define error: {}'.format(defines_errors))


# ==============================================================================
# BLOCKCHAIN CHAIN OF CUSTODY CUSTOMIZATION - ADDED
# ==============================================================================
# Blockchain Chain of Custody Roles
# These roles provide specialized permissions for evidence management with
# Hyperledger Fabric (hot/cold chains) and IPFS storage

# ==============================================================================
# PKI PERMISSIONS (BLOCKCHAIN SECURITY HARDENING)
# ==============================================================================
# SystemAdmin has full PKI control for certificate lifecycle management
_system_admin_pki_perms = (
    ('pki', 'certificateauthority', '*', '*'),  # Full CA management
    ('pki', 'certificate', '*', '*'),  # Full certificate management
)

# Blockchain roles can view their own certificates only
_blockchain_user_pki_perms = (
    ('pki', 'certificate', 'view', 'self'),  # View own certificate status
)
# ==============================================================================

_blockchain_investigator_perms = (
    # Blockchain operations - Investigators work on assigned investigations only (no create)
    ('blockchain', 'investigation', 'view,change', '*'),
    ('blockchain', 'evidence', 'add,view', '*'),
    ('blockchain', 'blockchaintransaction', 'add,view', '*'),
    ('blockchain', 'blockchaintransaction', 'append', 'hot'),
    ('blockchain', 'blockchaintransaction', 'append', 'cold'),
    # Notes - investigators can add notes to their investigations
    ('blockchain', 'investigationnote', 'add,view', '*'),
    # PKI permissions
    *_blockchain_user_pki_perms,
    # Audit logs (view own actions)
    ('audits', 'userloginlog', 'view', 'self'),
    ('audits', 'operatelog', 'view', 'self'),
    # User perms
    *user_perms,
)

_blockchain_auditor_perms = (
    # Read-only blockchain access
    ('blockchain', 'investigation', 'view', '*'),
    ('blockchain', 'evidence', 'view', '*'),
    ('blockchain', 'blockchaintransaction', 'view', '*'),
    # PKI permissions
    *_blockchain_user_pki_perms,
    # Full audit log access
    ('audits', '*', 'view', '*'),
    # Reports
    ('reports', '*', 'view', '*'),
    # User perms
    *user_perms,
)

_blockchain_court_perms = (
    # Court can CREATE, view, archive, and reopen investigations
    ('blockchain', 'investigation', 'add,view,change', '*'),
    ('blockchain', 'investigation', 'archive', '*'),
    ('blockchain', 'investigation', 'reopen', '*'),
    # Court can view all evidence and transactions
    ('blockchain', 'evidence', 'view', '*'),
    ('blockchain', 'blockchaintransaction', 'view', '*'),
    # Court can assign tags to investigations
    ('blockchain', 'tag', 'view', '*'),
    ('blockchain', 'investigationtag', 'add,view,delete', '*'),
    # GUID resolution (ONLY court role)
    ('blockchain', 'guidmapping', 'resolve_guid', '*'),
    # Court needs to view users to assign investigators/auditors
    ('users', 'user', 'view', '*'),
    # Court needs to view system role bindings to see user roles in API responses
    ('rbac', 'systemrolebinding', 'view', '*'),
    # PKI permissions
    *_blockchain_user_pki_perms,
    # Full audit log access
    ('audits', '*', 'view', '*'),
    # Reports
    ('reports', '*', 'view', '*'),
    # User perms
    *user_perms,
)
# ==============================================================================
# END BLOCKCHAIN CUSTOMIZATION
# ==============================================================================


class PredefineRole:
    id_prefix = '00000000-0000-0000-0000-00000000000'

    def __init__(self, index, name, scope, perms, perms_type='include'):
        self.id = self.id_prefix + index
        self.name = name
        self.scope = scope
        self.perms = perms
        self.perms_type = perms_type

    def get_role(self):
        from rbac.models import Role
        return Role.objects.get(id=self.id)

    @property
    def default_perms(self):
        from rbac.models import Permission
        q = Permission.get_define_permissions_q(self.perms)
        permissions = Permission.get_permissions(self.scope)

        if not q:
            permissions = permissions.none()
        elif self.perms_type == 'include':
            permissions = permissions.filter(q)
        else:
            permissions = permissions.exclude(q)

        perms = permissions.values_list('id', flat=True)
        return perms

    def _get_defaults(self):
        perms = self.default_perms
        defaults = {
            'id': self.id, 'name': self.name, 'scope': self.scope,
            'builtin': True, 'permissions': perms, 'created_by': 'System',
        }
        return defaults

    def update_or_create_role(self):
        from rbac.models import Role
        defaults = self._get_defaults()
        permissions = defaults.pop('permissions', [])
        role, created = Role.objects.update_or_create(defaults, id=self.id)
        role.permissions.set(permissions)
        return role, created


class BuiltinRole:
    # ==============================================================================
    # SystemAdmin: Full access including PKI management (BLOCKCHAIN HARDENING)
    # ==============================================================================
    system_admin = PredefineRole(
        '1', gettext_noop('SystemAdmin'), Scope.system,
        _system_admin_pki_perms  # Add PKI permissions explicitly
    )
    # Note: SystemAdmin still gets ALL permissions via is_admin() bypass,
    # but explicitly defining PKI perms ensures permission checks work correctly
    # ==============================================================================
    # ==============================================================================
    # BLOCKCHAIN SECURITY: Legacy roles with blockchain exclusions
    # ==============================================================================
    system_auditor = PredefineRole(
        '2', gettext_noop('SystemAuditor'), Scope.system,
        legacy_role_blockchain_exclude_perms, 'exclude'  # EXCLUDE blockchain access
    )
    # ==============================================================================
    system_component = PredefineRole(
        '4', gettext_noop('SystemComponent'), Scope.system, app_exclude_perms, 'exclude'
    )
    system_user = PredefineRole(
        '3', gettext_noop('User'), Scope.system, system_user_perms
    )
    org_admin = PredefineRole(
        '5', gettext_noop('OrgAdmin'), Scope.org, []
    )
    # ==============================================================================
    # BLOCKCHAIN SECURITY: Legacy roles with blockchain exclusions
    # ==============================================================================
    org_auditor = PredefineRole(
        '6', gettext_noop('OrgAuditor'), Scope.org,
        legacy_role_blockchain_exclude_perms, 'exclude'  # EXCLUDE blockchain access
    )
    # ==============================================================================
    org_user = PredefineRole(
        '7', gettext_noop('OrgUser'), Scope.org, user_perms
    )

    # ==============================================================================
    # BLOCKCHAIN CHAIN OF CUSTODY ROLES - ADDED
    # ==============================================================================
    blockchain_investigator = PredefineRole(
        '8', gettext_noop('BlockchainInvestigator'), Scope.system, _blockchain_investigator_perms
    )
    blockchain_auditor = PredefineRole(
        '9', gettext_noop('BlockchainAuditor'), Scope.system, _blockchain_auditor_perms
    )
    blockchain_court = PredefineRole(
        'A', gettext_noop('BlockchainCourt'), Scope.system, _blockchain_court_perms
    )
    # ==============================================================================
    # END BLOCKCHAIN CUSTOMIZATION
    # ==============================================================================

    system_role_mapper = None
    org_role_mapper = None

    @classmethod
    def get_roles(cls):
        roles = {
            k: v
            for k, v in cls.__dict__.items()
            if isinstance(v, PredefineRole)
        }
        return roles

    @classmethod
    def get_system_role_by_old_name(cls, name):
        if not cls.system_role_mapper:
            cls.system_role_mapper = {
                'App': cls.system_component.get_role(),
                'Admin': cls.system_admin.get_role(),
                'User': cls.system_user.get_role(),
                'Auditor': cls.system_auditor.get_role(),
                # BLOCKCHAIN CUSTOMIZATION - ADDED
                'Investigator': cls.blockchain_investigator.get_role(),
                'BlockchainAuditor': cls.blockchain_auditor.get_role(),
                'Court': cls.blockchain_court.get_role(),
            }
        return cls.system_role_mapper.get(name, cls.system_role_mapper['User'])

    @classmethod
    def get_org_role_by_old_name(cls, name):
        if not cls.org_role_mapper:
            cls.org_role_mapper = {
                'Admin': cls.org_admin.get_role(),
                'User': cls.org_user.get_role(),
                'Auditor': cls.org_auditor.get_role(),
            }
        return cls.org_role_mapper.get(name, cls.org_role_mapper['User'])

    @classmethod
    def sync_to_db(cls, show_msg=False):
        roles = cls.get_roles()
        print("  - Update builtin roles")

        for pre_role in roles.values():
            role, created = pre_role.update_or_create_role()
            if show_msg:
                print("    - Update: {} - {}".format(role.name, created))
