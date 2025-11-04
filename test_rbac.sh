#!/bin/bash
# =============================================================================
# RBAC Testing Script - Fixed version
# =============================================================================

source venv/bin/activate
cd apps

echo "========================================="
echo "RBAC Testing"
echo "========================================="
echo

# =============================================================================
# TEST 1: List all users and their roles
# =============================================================================
echo "1. Listing all users and their roles..."
echo

python manage.py shell << 'EOF'
from users.models import User
from rbac.models import Role, SystemRoleBinding, OrgRoleBinding

print("=== All Users and Roles ===\n")

users = User.objects.all()
for user in users:
    print(f"User: {user.username}")
    print(f"  Email: {user.email}")
    print(f"  Is superuser: {user.is_superuser}")

    # Get system roles
    system_bindings = SystemRoleBinding.objects.filter(user=user)
    if system_bindings.exists():
        print(f"  System Roles:")
        for binding in system_bindings:
            print(f"    - {binding.role.name} (ID: {binding.role.id})")
    else:
        print(f"  System Roles: None")

    # Get org roles
    org_bindings = OrgRoleBinding.objects.filter(user=user)
    if org_bindings.exists():
        print(f"  Org Roles:")
        for binding in org_bindings:
            print(f"    - {binding.role.name} in {binding.org.name}")

    print()
EOF

echo

# =============================================================================
# TEST 2: List all available blockchain roles
# =============================================================================
echo "2. Available Blockchain Roles..."
echo

python manage.py shell << 'EOF'
from rbac.models import Role

print("=== Blockchain Roles ===\n")

blockchain_roles = Role.objects.filter(name__icontains='Blockchain')
for role in blockchain_roles:
    print(f"Role: {role.name}")
    print(f"  ID: {role.id}")
    print(f"  Scope: {role.scope}")
    print(f"  Builtin: {role.builtin}")
    print(f"  Permissions count: {role.permissions.count()}")
    print()
EOF

echo

# =============================================================================
# TEST 3: Create test user with BlockchainInvestigator role
# =============================================================================
echo "3. Creating test user with BlockchainInvestigator role..."
echo

python manage.py shell << 'EOF'
from users.models import User
from rbac.models import Role, SystemRoleBinding

# Create or get user
user, created = User.objects.get_or_create(
    username='investigator1',
    defaults={
        'email': 'investigator1@test.com',
        'name': 'Test Investigator'
    }
)

if created:
    user.set_password('testpass123')
    user.save()
    print(f"✅ Created user: {user.username}")
else:
    print(f"ℹ User already exists: {user.username}")

# Get BlockchainInvestigator role (ID: 00000000-0000-0000-0000-000000000008)
try:
    role = Role.objects.get(id='00000000-0000-0000-0000-000000000008')
    print(f"✅ Found role: {role.name}")

    # Create role binding
    binding, created = SystemRoleBinding.objects.get_or_create(
        user=user,
        role=role
    )

    if created:
        print(f"✅ Assigned role: {role.name} to {user.username}")
    else:
        print(f"ℹ Role already assigned")

    # Verify
    print(f"\n=== Verification ===")
    print(f"User: {user.username}")
    print(f"Roles:")
    for binding in SystemRoleBinding.objects.filter(user=user):
        print(f"  - {binding.role.name}")

except Role.DoesNotExist:
    print("❌ BlockchainInvestigator role not found!")
    print("Run: python manage.py sync_role")
EOF

echo

# =============================================================================
# TEST 4: Issue certificate for test user
# =============================================================================
echo "4. Issuing certificate for investigator1..."
echo

if [ ! -f "../data/certs/pki/investigator1.p12" ]; then
    python manage.py issue_user_cert \
        --username investigator1 \
        --output ../data/certs/pki/investigator1.p12 \
        --password testpass123

    echo "✅ Certificate issued: data/certs/pki/investigator1.p12"
    echo "   Password: testpass123"
else
    echo "ℹ Certificate already exists: data/certs/pki/investigator1.p12"
fi

echo

# =============================================================================
# TEST 5: Check all issued certificates
# =============================================================================
echo "5. All issued certificates..."
echo

python manage.py shell << 'EOF'
from pki.models import Certificate

print("=== Issued Certificates ===\n")

certs = Certificate.objects.all()
for cert in certs:
    print(f"User: {cert.user.username if cert.user else 'N/A'}")
    print(f"  Serial: {cert.serial_number}")
    print(f"  Subject: {cert.subject_dn}")
    print(f"  Valid from: {cert.not_before}")
    print(f"  Valid until: {cert.not_after}")
    print(f"  Revoked: {cert.revoked}")
    print()
EOF

echo "========================================="
echo "RBAC Testing Complete!"
echo "========================================="
