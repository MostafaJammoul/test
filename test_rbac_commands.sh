#!/bin/bash
# =============================================================================
# RBAC Testing Commands
# =============================================================================

set -e

cd /opt/truefypjs
source venv/bin/activate
cd apps

echo "========================================="
echo "RBAC Test Suite"
echo "========================================="
echo

# =============================================================================
# 1. LIST ALL ROLES
# =============================================================================
echo "[TEST 1] List all system roles:"
echo "-----------------------------------"
python manage.py shell << 'EOF'
from rbac.models import Role

print("\nSystem Roles:")
for role in Role.system_roles.all():
    print(f"  - {role.name} (ID: {role.id})")
EOF

echo

# =============================================================================
# 2. CHECK BLOCKCHAIN ROLES EXIST
# =============================================================================
echo "[TEST 2] Verify blockchain roles exist:"
echo "-----------------------------------"
python manage.py shell << 'EOF'
from rbac.models import Role

blockchain_roles = ['BlockchainInvestigator', 'BlockchainAuditor', 'BlockchainCourt']
for role_name in blockchain_roles:
    exists = Role.objects.filter(name=role_name).exists()
    status = "✓" if exists else "✗"
    print(f"  {status} {role_name}")
EOF

echo

# =============================================================================
# 3. LIST ALL USERS AND THEIR ROLES
# =============================================================================
echo "[TEST 3] List all users and their roles:"
echo "-----------------------------------"
python manage.py shell << 'EOF'
from users.models import User
from rbac.models import SystemRoleBinding

print("\nUsers and Roles:")
for user in User.objects.all():
    bindings = SystemRoleBinding.objects.filter(user=user)
    roles = [b.role.name for b in bindings]
    print(f"  User: {user.username}")
    print(f"    Roles: {', '.join(roles) if roles else 'No roles'}")
    print(f"    Is superuser: {user.is_superuser}")
    print()
EOF

echo

# =============================================================================
# 4. CREATE TEST USER WITH BLOCKCHAIN ROLE
# =============================================================================
echo "[TEST 4] Create test user with BlockchainInvestigator role:"
echo "-----------------------------------"
python manage.py shell << 'EOF'
from users.models import User
from rbac.models import Role, SystemRoleBinding
from orgs.models import Organization

# Get or create test user
username = "investigator_test"
user, created = User.objects.get_or_create(
    username=username,
    defaults={
        'name': 'Test Investigator',
        'email': 'investigator@test.com',
    }
)

if created:
    user.set_password('TestPass123!')
    user.save()
    print(f"✓ Created user: {username}")
else:
    print(f"  User already exists: {username}")

# Assign BlockchainInvestigator role
role = Role.objects.get(name='BlockchainInvestigator')
binding, created = SystemRoleBinding.objects.get_or_create(
    user=user,
    role=role,
    scope='system'
)

if created:
    print(f"✓ Assigned role: BlockchainInvestigator")
else:
    print(f"  Role already assigned")

print(f"\n  Username: {username}")
print(f"  Password: TestPass123!")
print(f"  Role: BlockchainInvestigator")
EOF

echo

# =============================================================================
# 5. TEST ROLE PERMISSIONS
# =============================================================================
echo "[TEST 5] Check BlockchainInvestigator permissions:"
echo "-----------------------------------"
python manage.py shell << 'EOF'
from rbac.models import Role

role = Role.objects.get(name='BlockchainInvestigator')
perms = role.get_permissions()

print(f"\nBlockchainInvestigator has {perms.count()} permissions:")
blockchain_perms = [p for p in perms if 'blockchain' in p.content_type.app_label]
for perm in blockchain_perms[:10]:  # Show first 10
    print(f"  - {perm.content_type.app_label}.{perm.codename}")
EOF

echo

# =============================================================================
# 6. ISSUE CERTIFICATE FOR TEST USER
# =============================================================================
echo "[TEST 6] Issue certificate for test user:"
echo "-----------------------------------"

if [ -f "../data/certs/pki/investigator_test.p12" ]; then
    echo "  Certificate already exists: investigator_test.p12"
else
    python manage.py issue_user_cert \
        --username investigator_test \
        --output ../data/certs/pki/investigator_test.p12 \
        --password TestCert123

    echo "✓ Certificate issued: data/certs/pki/investigator_test.p12"
    echo "  Password: TestCert123"
fi

echo

# =============================================================================
# 7. VERIFY MTLS + RBAC INTEGRATION
# =============================================================================
echo "[TEST 7] Verify mTLS certificate → User mapping:"
echo "-----------------------------------"
python manage.py shell << 'EOF'
from pki.models import Certificate
from users.models import User

print("\nUser → Certificate Mappings:")
for cert in Certificate.objects.filter(certificate_type='user'):
    user = cert.user
    print(f"  User: {user.username}")
    print(f"    Certificate DN: {cert.subject_dn}")
    print(f"    Valid until: {cert.not_after}")
    print(f"    Revoked: {cert.is_revoked}")
    print()
EOF

echo

echo "========================================="
echo "RBAC Tests Complete!"
echo "========================================="
echo
echo "Summary:"
echo "  - All blockchain roles created"
echo "  - Test user 'investigator_test' created with BlockchainInvestigator role"
echo "  - Certificate issued for test user"
echo
echo "Next steps:"
echo "  1. Download certificate:"
echo "     scp jsroot@192.168.148.154:/opt/truefypjs/data/certs/pki/investigator_test.p12 ."
echo
echo "  2. Import to browser (password: TestCert123)"
echo
echo "  3. Access https://192.168.148.154/"
echo "     - Browser will prompt for certificate selection"
echo "     - Select investigator_test certificate"
echo "     - You'll be logged in with BlockchainInvestigator role"
echo
