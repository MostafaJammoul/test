# mTLS Testing & Verification Guide

Quick reference for testing and verifying mTLS (Mutual TLS) authentication.

---

## Certificate Storage Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Certificate Storage                      │
└─────────────────────────────────────────────────────────────┘

PRIMARY STORAGE (Database):
┌────────────────────────────────────────────────────────────┐
│ data/db.sqlite3                                            │
│                                                            │
│ Table: pki_certificateauthority                            │
│ ├── id (UUID)                                             │
│ ├── common_name: "JumpServer Internal CA"                 │
│ ├── certificate_pem: "-----BEGIN CERTIFICATE-----..."     │
│ ├── private_key_pem_encrypted: <encrypted blob>           │
│ ├── created_at, valid_until                               │
│                                                            │
│ Table: pki_certificate                                     │
│ ├── id (UUID)                                             │
│ ├── user_id (FK to auth_user)                            │
│ ├── serial_number: "1234567890"                           │
│ ├── certificate_pem: "-----BEGIN CERTIFICATE-----..."     │
│ ├── private_key_pem_encrypted: <encrypted blob>           │
│ ├── created_at, valid_until, revoked_at                   │
└────────────────────────────────────────────────────────────┘

EXPORTED FOR NGINX (Filesystem):
┌────────────────────────────────────────────────────────────┐
│ data/certs/mtls/                                           │
│ ├── internal-ca.crt          # CA cert (public)           │
│ │   Purpose: nginx ssl_client_certificate                 │
│ │   Command: python manage.py export_ca_cert              │
│ │                                                          │
│ └── internal-ca.crl          # Certificate Revocation List│
│     Purpose: nginx ssl_crl                                 │
│     Command: python manage.py export_crl                   │
│                                                            │
│ data/certs/pki/                                            │
│ ├── admin.p12               # User certificate (PKCS#12)  │
│ │   Purpose: Import into browser                          │
│ │   Command: python manage.py issue_user_cert             │
│ │   Contents: User cert + private key + CA chain          │
│ │                                                          │
│ └── investigator.p12                                       │
└────────────────────────────────────────────────────────────┘
```

---

## Quick Commands

### 1. Initialize PKI

```bash
# Run once on first setup
python manage.py init_pki

# Verify
python manage.py shell
>>> from pki.models import CertificateAuthority
>>> ca = CertificateAuthority.objects.first()
>>> print(f"CA: {ca.common_name}")
>>> print(f"Valid until: {ca.valid_until}")
>>> exit()
```

### 2. Issue User Certificate

```bash
# Issue certificate for user 'admin'
python manage.py issue_user_cert \
    --username admin \
    --output data/certs/pki/admin.p12 \
    --password "changeme"

# Verify certificate
openssl pkcs12 -in data/certs/pki/admin.p12 -passin pass:changeme -nokeys | openssl x509 -text -noout
```

### 3. Export CA Certificate for nginx

```bash
# Export CA cert
python manage.py export_ca_cert \
    --output data/certs/mtls/internal-ca.crt

# Export CRL (Certificate Revocation List)
python manage.py export_crl \
    --output data/certs/mtls/internal-ca.crl

# Verify export
openssl x509 -in data/certs/mtls/internal-ca.crt -text -noout
```

### 4. List All Certificates

```bash
python manage.py shell

from pki.models import Certificate
certs = Certificate.objects.all()

for cert in certs:
    print(f"User: {cert.user.username}")
    print(f"  Serial: {cert.serial_number}")
    print(f"  Valid until: {cert.valid_until}")
    print(f"  Revoked: {cert.is_revoked}")
    print()
```

### 5. Revoke Certificate

```bash
python manage.py shell

from pki.models import Certificate
cert = Certificate.objects.get(user__username='admin')
cert.revoke()
cert.save()

# Re-export CRL
python manage.py export_crl --output data/certs/mtls/internal-ca.crl

# Reload nginx
sudo nginx -s reload
```

---

## Testing mTLS

### Test 1: Certificate in Browser

**1. Import certificate into Firefox:**

```bash
# Issue certificate
python manage.py issue_user_cert --username admin --output admin.p12 --password "test123"

# Firefox → Settings → Privacy & Security → Certificates
# → View Certificates → Your Certificates → Import
# Select: admin.p12
# Password: test123
```

**2. Access application:**

```
https://localhost  (or your domain)

Browser will prompt to select certificate
Select: admin (JumpServer Internal CA)
You're now authenticated automatically!
```

**3. Verify in logs:**

```bash
# Check nginx mTLS log
tail -f /var/log/nginx/jumpserver-mtls.log

# Should see:
# cert_verify=SUCCESS cert_dn="CN=admin,OU=Users,O=JumpServer,..."
```

### Test 2: Certificate with curl

```bash
# Test with P12 certificate
curl -v https://localhost/api/health/ \
    --cert data/certs/pki/admin.p12 \
    --cert-type P12 \
    --pass "test123"

# Expected output:
# * SSL certificate verify ok.
# * Server certificate:
# ...
# * Client certificate:
# ...
# < HTTP/2 200
# {"status": "ok"}
```

### Test 3: Without Certificate (Should Fail)

```bash
# Access without certificate
curl -v https://localhost/api/health/

# Expected output:
# * SSL certificate problem: unable to get local issuer certificate
# curl: (60) SSL certificate problem: unable to get local issuer certificate
```

### Test 4: Convert P12 to PEM (for testing)

```bash
# Extract certificate
openssl pkcs12 -in admin.p12 -passin pass:test123 -clcerts -nokeys -out admin-cert.pem

# Extract private key
openssl pkcs12 -in admin.p12 -passin pass:test123 -nocerts -nodes -out admin-key.pem

# Test with PEM files
curl -v https://localhost/api/health/ \
    --cert admin-cert.pem \
    --key admin-key.pem
```

---

## nginx Configuration Checklist

### 1. Install nginx (if not installed)

```bash
sudo apt install -y nginx
```

### 2. Copy mTLS configuration

```bash
sudo cp config/nginx-mtls.conf.example /etc/nginx/sites-available/jumpserver
sudo ln -s /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/
```

### 3. Update paths in nginx config

```bash
sudo nano /etc/nginx/sites-available/jumpserver

# Update these lines with ABSOLUTE PATHS:
ssl_client_certificate /absolute/path/to/data/certs/mtls/internal-ca.crt;
ssl_crl /absolute/path/to/data/certs/mtls/internal-ca.crl;

# Example:
# ssl_client_certificate /home/user/truefypjs/data/certs/mtls/internal-ca.crt;
# ssl_crl /home/user/truefypjs/data/certs/mtls/internal-ca.crl;
```

### 4. Obtain server certificate (SSL/TLS)

**Option A: Self-signed (for testing)**

```bash
# Generate self-signed cert
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/CN=localhost"

# Update nginx config:
ssl_certificate /etc/nginx/ssl/server.crt;
ssl_certificate_key /etc/nginx/ssl/server.key;
```

**Option B: Let's Encrypt (for production)**

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d jumpserver.example.com

# Certbot automatically updates nginx config
```

### 5. Test nginx configuration

```bash
sudo nginx -t

# Expected output:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 6. Start/reload nginx

```bash
# Start nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Or reload if already running
sudo systemctl reload nginx
```

---

## Verification Steps

### Step 1: Verify PKI Initialization

```bash
python manage.py shell

from pki.models import CertificateAuthority
ca = CertificateAuthority.objects.first()

print(f"✓ CA exists: {ca is not None}")
print(f"✓ CA name: {ca.common_name}")
print(f"✓ Valid until: {ca.valid_until}")
print(f"✓ Has private key: {ca.private_key_pem_encrypted is not None}")
```

### Step 2: Verify User Certificate

```bash
# List certificates
python manage.py shell

from pki.models import Certificate
certs = Certificate.objects.all()

for cert in certs:
    print(f"✓ User: {cert.user.username}")
    print(f"  Serial: {cert.serial_number}")
    print(f"  Expires: {cert.valid_until}")
    print(f"  Revoked: {cert.is_revoked}")
```

### Step 3: Verify Certificate Chain

```bash
# Verify user cert is signed by CA
openssl verify -CAfile data/certs/mtls/internal-ca.crt data/certs/pki/admin-cert.pem

# Expected output:
# data/certs/pki/admin-cert.pem: OK
```

### Step 4: Verify nginx Can Read Certificates

```bash
# Check file permissions
ls -l data/certs/mtls/

# Should be readable by nginx user:
# -rw-r--r-- 1 user user 1234 Nov  4 12:00 internal-ca.crt
# -rw-r--r-- 1 user user 5678 Nov  4 12:00 internal-ca.crl

# Test nginx can read
sudo -u www-data cat data/certs/mtls/internal-ca.crt > /dev/null
echo $?  # Should be 0
```

### Step 5: Verify mTLS in Django

```bash
# Enable mTLS
nano config.yml
# Set: MTLS_ENABLED: true

# Restart server
python manage.py runserver 0.0.0.0:8080

# Check Django can read cert from headers
python manage.py shell

# Test authentication backend
from authentication.backends import MTLSBackend
backend = MTLSBackend()
print(f"✓ mTLS backend loaded: {backend is not None}")
```

### Step 6: End-to-End Test

```bash
# 1. Issue certificate
python manage.py issue_user_cert --username testuser --output test.p12 --password "test"

# 2. Test with curl
curl -v https://localhost/api/health/ \
    --cert test.p12 \
    --cert-type P12 \
    --pass "test"

# 3. Check logs
tail -f /var/log/nginx/jumpserver-mtls.log
# Should show: cert_verify=SUCCESS

tail -f data/logs/jumpserver.log
# Should show: mTLS authentication successful for user: testuser
```

---

## Certificate Renewal

### Manual Renewal

```bash
# Check certificate expiration
python manage.py shell

from pki.models import Certificate
cert = Certificate.objects.get(user__username='admin')
print(f"Expires: {cert.valid_until}")
print(f"Days until expiry: {(cert.valid_until - timezone.now()).days}")

# Renew certificate
cert.renew()
cert.save()

# Re-export P12
python manage.py issue_user_cert --username admin --output admin.p12 --password "newpass"

# User must re-import certificate into browser
```

### Automatic Renewal (Celery)

```bash
# Start Celery worker
celery -A jumpserver worker -l info

# Start Celery beat (scheduler)
celery -A jumpserver beat -l info

# Automatic renewal happens 30 days before expiry
# Check logs:
tail -f data/logs/celery.log
# Should see: [INFO] Certificate renewal task executed for user: admin
```

---

## Common Issues

### Issue 1: Certificate not accepted by nginx

**Symptoms:**
- nginx returns: 400 Bad Request
- Log shows: "client certificate CN is invalid"

**Solution:**

```bash
# Check certificate is signed by correct CA
openssl verify -CAfile data/certs/mtls/internal-ca.crt admin-cert.pem

# Re-export CA cert
python manage.py export_ca_cert --output data/certs/mtls/internal-ca.crt --force

# Reload nginx
sudo nginx -s reload
```

### Issue 2: Django doesn't recognize certificate

**Symptoms:**
- nginx accepts certificate
- Django returns: 401 Unauthorized
- Log shows: "mTLS header not found"

**Solution:**

```bash
# Check nginx passes headers
curl -v https://localhost/api/debug-headers/

# Should see:
# X-SSL-Client-Cert: -----BEGIN CERTIFICATE-----...
# X-SSL-Client-DN: CN=admin,OU=Users,O=JumpServer,...

# If missing, check nginx config:
proxy_set_header X-SSL-Client-Cert $ssl_client_cert;
proxy_set_header X-SSL-Client-DN $ssl_client_s_dn;
proxy_set_header X-SSL-Client-Verify $ssl_client_verify;
```

### Issue 3: Browser doesn't prompt for certificate

**Symptoms:**
- Browser doesn't show certificate selection dialog
- Gets 400 Bad Request immediately

**Solution:**

```bash
# Check certificate is imported in browser
# Firefox: Settings → Privacy & Security → Certificates → View Certificates → Your Certificates
# Should see: admin (JumpServer Internal CA)

# Re-import if missing:
# 1. Delete old certificate from browser
# 2. Re-issue: python manage.py issue_user_cert --username admin --output admin.p12
# 3. Import admin.p12 into browser
```

### Issue 4: Certificate expired

**Symptoms:**
- nginx returns: 495 SSL Certificate Error
- Log shows: "client certificate expired"

**Solution:**

```bash
# Renew certificate
python manage.py shell
from pki.models import Certificate
cert = Certificate.objects.get(user__username='admin')
cert.renew()

# Re-export P12
python manage.py issue_user_cert --username admin --output admin.p12

# Re-import into browser
```

---

## Security Best Practices

### 1. Certificate Expiry

```yaml
# config.yml
PKI_USER_CERT_VALIDITY_DAYS: 365  # 1 year
PKI_AUTO_RENEWAL_DAYS_BEFORE: 30  # Renew 30 days before expiry
PKI_AUTO_RENEWAL_ENABLED: true
```

### 2. Strong Private Keys

```python
# apps/pki/ca_manager.py (already configured)
key_size = 4096  # RSA 4096-bit
```

### 3. Certificate Revocation

```bash
# Revoke compromised certificate
python manage.py shell
from pki.models import Certificate
cert = Certificate.objects.get(serial_number='1234567890')
cert.revoke()

# Re-export CRL
python manage.py export_crl --output data/certs/mtls/internal-ca.crl

# Reload nginx (to read updated CRL)
sudo nginx -s reload
```

### 4. Secure Storage

- Private keys encrypted in database (AES-256)
- Filesystem permissions: `chmod 600` for private keys
- P12 files protected with password

### 5. Audit Logging

```bash
# All certificate operations are logged
tail -f data/logs/jumpserver.log | grep certificate

# Check certificate issuance
# [INFO] Certificate issued for user: admin, serial: 1234567890

# Check certificate revocation
# [WARNING] Certificate revoked: serial=1234567890, user=admin
```

---

## Quick Troubleshooting

```bash
# 1. Check PKI initialized
python manage.py shell -c "from pki.models import CertificateAuthority; print('OK' if CertificateAuthority.objects.exists() else 'NOT FOUND')"

# 2. Check Redis running
redis-cli ping  # Should return: PONG

# 3. Check nginx syntax
sudo nginx -t

# 4. Check nginx running
sudo systemctl status nginx

# 5. Check Django can access cert
ls -l data/certs/mtls/internal-ca.crt

# 6. Check certificate valid
openssl x509 -in data/certs/mtls/internal-ca.crt -noout -dates

# 7. Check mTLS enabled
grep MTLS_ENABLED config.yml

# 8. Test certificate with curl
curl -v https://localhost/api/health/ --cert admin.p12 --cert-type P12 --pass "password"
```

---

**For complete setup instructions, see [SETUP.md](SETUP.md)**
