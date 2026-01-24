# Production Build & HTTPS/mTLS Access Guide

## 1. What Happens When You Run `npm run build`

### Build Process

```bash
cd /home/user/test/frontend
npm run build
```

**What it does** (configured in `vite.config.js`):
```javascript
build: {
  outDir: '../apps/static/frontend',  // Output directory
  emptyOutDir: true,                   // Clears old files first
}
```

**Result**:
1. ✅ Compiles React app with production optimizations
2. ✅ Minifies JavaScript and CSS
3. ✅ Bundles all assets (images, fonts, etc.)
4. ✅ Generates optimized static files in `/home/user/test/apps/static/frontend/`
5. ✅ Creates `index.html`, `assets/*.js`, `assets/*.css`

### File Structure After Build

```
/home/user/test/apps/static/frontend/
├── index.html              # Main HTML file
├── assets/
│   ├── index-abc123.js    # Bundled JavaScript (hash for cache busting)
│   ├── index-def456.css   # Bundled CSS
│   └── logo-xyz789.png    # Optimized images
└── vite.svg
```

---

## 2. Accessing the Built Frontend

### Current Issue: nginx Config Points to Dev Server

The current `nginx_mtls.conf` is configured to **proxy to the dev server** (port 3000), not serve static files:

```nginx
location / {
    proxy_pass http://127.0.0.1:3000;  # ❌ Dev server (must be running)
}
```

### Two Options for Production:

#### Option A: Serve Static Files via nginx (Recommended)

**Modify `nginx_mtls.conf`** to serve built files directly:

```nginx
location / {
    # Serve built React app from static directory
    root /home/user/test/apps/static/frontend;
    try_files $uri $uri/ /index.html;  # SPA fallback

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}

# Keep API proxying
location /api/ {
    proxy_pass http://127.0.0.1:8080;
    # ... rest of proxy config
}
```

**Pros**:
- ✅ No dev server needed (Vite not running)
- ✅ Faster performance (static files served by nginx)
- ✅ Production-ready

**Cons**:
- ❌ Must rebuild after every code change
- ❌ No hot module replacement (HMR)

---

#### Option B: Keep Dev Server with nginx Proxy (Current Setup)

**Keep current config** and run Vite dev server:

```nginx
location / {
    proxy_pass http://127.0.0.1:3000;  # Vite dev server
}
```

**Pros**:
- ✅ Hot module replacement (instant updates)
- ✅ Good for development

**Cons**:
- ❌ Vite must be running (`npm run dev`)
- ❌ Not for production use

---

## 3. Can You Access Over HTTPS?

### Yes, But Setup Required

Currently nginx is configured for **HTTPS with mTLS**, but you need to:

### Step 1: Generate Server Certificate

nginx needs a server certificate for HTTPS. The current config expects:

```nginx
ssl_certificate /opt/truefypjs/data/certs/server.crt;
ssl_certificate_key /opt/truefypjs/data/certs/server.key;
```

**Generate self-signed server certificate**:

```bash
# Create certs directory
sudo mkdir -p /opt/truefypjs/data/certs

# Generate server certificate (self-signed for testing)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/truefypjs/data/certs/server.key \
  -out /opt/truefypjs/data/certs/server.crt \
  -subj "/C=US/ST=State/L=City/O=JumpServer/CN=192.168.148.154"

# Set permissions
sudo chmod 600 /opt/truefypjs/data/certs/server.key
sudo chmod 644 /opt/truefypjs/data/certs/server.crt
```

### Step 2: Export CA Certificate for nginx

The CA certificate is stored in the database. You need to export it:

**Method 1: Via Django Management Command** (after setup.sh completes):

```bash
cd /home/user/test/apps
python manage.py export_ca_cert --output /opt/truefypjs/data/certs/ca.crt
```

**Method 2: Via API** (after services are running):

```bash
# Login first
TOKEN=$(curl -X POST http://localhost:8080/api/v1/authentication/auth/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  | jq -r '.token')

# Download CA certificate
curl http://localhost:8080/api/v1/pki/ca/1/cert/ \
  -H "Authorization: Bearer $TOKEN" \
  -o /tmp/ca.crt

# Copy to nginx location
sudo cp /tmp/ca.crt /opt/truefypjs/data/certs/ca.crt
```

**Method 3: Query Database Directly**:

```bash
PGPASSWORD=jsroot psql -h localhost -U jsroot -d jumpserver -t -A -c \
  "SELECT certificate FROM pki_certificateauthority WHERE is_active=TRUE LIMIT 1;" \
  | sudo tee /opt/truefypjs/data/certs/ca.crt > /dev/null
```

### Step 3: Configure nginx

```bash
# Copy config to nginx
sudo cp /home/user/test/nginx_mtls.conf /etc/nginx/sites-available/jumpserver

# Update paths in config if needed
sudo nano /etc/nginx/sites-available/jumpserver

# Enable site
sudo ln -s /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

### Step 4: Access via HTTPS

**Without client certificate** (if `ssl_verify_client optional;`):
- URL: `https://192.168.148.154/`
- Browser warning about self-signed certificate (click "Advanced" → "Proceed")

**With client certificate** (if `ssl_verify_client on;`):
- Browser will prompt for certificate
- Select your imported .p12 certificate
- Automatically authenticated!

---

## 4. Where to Get Certificate to Import into Browser

### Step 1: Get Your User Certificate

You need a **.p12 (PKCS#12)** file containing:
- Your private key
- Your certificate
- CA certificate chain

### Method 1: Via Django Admin Panel

1. **Login to admin panel**:
   ```
   http://192.168.148.154:8080/django-admin/
   Username: admin
   Password: admin
   ```

2. **Navigate to PKI → Certificates**

3. **Find your certificate** (admin user)

4. **Click "Download" action**

5. **Browser downloads**: `admin.p12`

### Method 2: Via API

**Get your certificate ID**:

```bash
# Login
TOKEN=$(curl -X POST http://192.168.148.154:8080/api/v1/authentication/auth/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' \
  | jq -r '.token')

# List your certificates
curl http://192.168.148.154:8080/api/v1/pki/certificates/ \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.results[] | {id, serial_number, subject_dn, not_after}'
```

**Download .p12 file**:

```bash
# Replace {CERT_ID} with actual ID from above
CERT_ID="abc-123-def-456"

# Download without password
curl "http://192.168.148.154:8080/api/v1/pki/certificates/$CERT_ID/download/" \
  -H "Authorization: Bearer $TOKEN" \
  -o admin.p12

# Or with password protection
curl "http://192.168.148.154:8080/api/v1/pki/certificates/$CERT_ID/download/?password=changeme123" \
  -H "Authorization: Bearer $TOKEN" \
  -o admin.p12
```

### Method 3: Via Management Command

```bash
cd /home/user/test/apps
python manage.py issue_user_cert --username admin

# Then export from database (see API method above)
```

### Method 4: Check Filesystem (if auto-generated)

During `setup.sh`, certificates might be exported to:

```bash
ls -la /home/user/test/data/certs/pki/
# Should contain: admin.p12
```

If exists:
```bash
cp /home/user/test/data/certs/pki/admin.p12 ~/Downloads/
```

---

## 5. How to Import Certificate into Browser

### Firefox

1. **Open Firefox Settings**
2. **Privacy & Security** → **View Certificates**
3. **Your Certificates** tab → **Import**
4. **Select file**: `admin.p12`
5. **Enter password**: (empty if no password, or `changeme123`)
6. **Click OK**

### Chrome (Windows/Mac)

#### Windows:
1. **Double-click** `admin.p12` file
2. **Certificate Import Wizard** opens
3. **Store Location**: Current User → Next
4. **File to Import**: (already selected) → Next
5. **Password**: (enter if protected) → Next
6. **Certificate Store**: Automatically select → Next
7. **Finish**

#### Mac:
1. **Open Keychain Access** (`/Applications/Utilities/`)
2. **File** → **Import Items**
3. **Select** `admin.p12`
4. **Enter password** if prompted
5. **Select keychain**: login
6. **Right-click certificate** → **Get Info** → **Trust** → **Always Trust**

### Linux (Firefox/Chrome)

**Firefox**: Same as above

**Chrome** (uses system certificate store):
```bash
# Convert .p12 to .pem
openssl pkcs12 -in admin.p12 -out admin.pem -nodes

# Import to NSS database (Chrome's cert store)
certutil -d sql:$HOME/.pki/nssdb -A -t "P,," -n "Admin mTLS" -i admin.pem
```

---

## 6. Complete Production Workflow

### Build and Deploy Flow:

```bash
# 1. Build frontend
cd /home/user/test/frontend
npm run build

# 2. Collect Django static files
cd /home/user/test/apps
python manage.py collectstatic --noinput

# 3. Generate server certificate (one-time)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/truefypjs/data/certs/server.key \
  -out /opt/truefypjs/data/certs/server.crt \
  -subj "/C=US/O=JumpServer/CN=192.168.148.154"

# 4. Export CA certificate (one-time)
cd /home/user/test/apps
python manage.py export_ca_cert --output /opt/truefypjs/data/certs/ca.crt

# 5. Configure nginx
sudo cp /home/user/test/nginx_mtls.conf /etc/nginx/sites-available/jumpserver

# Update nginx to serve static files (edit the config)
sudo nano /etc/nginx/sites-available/jumpserver
# Change:
#   location / { proxy_pass http://127.0.0.1:3000; }
# To:
#   location / { root /home/user/test/apps/static/frontend; try_files $uri /index.html; }

# 6. Enable and restart nginx
sudo ln -sf /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# 7. Start Django backend only (no Vite needed)
cd /home/user/test/apps
python manage.py runserver 0.0.0.0:8080

# 8. Access via HTTPS
# https://192.168.148.154/
```

### Download Your Certificate:

```bash
# Via API
TOKEN=$(curl -X POST http://192.168.148.154:8080/api/v1/authentication/auth/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}' | jq -r '.token')

CERT_ID=$(curl http://192.168.148.154:8080/api/v1/pki/certificates/ \
  -H "Authorization: Bearer $TOKEN" | jq -r '.results[0].id')

curl "http://192.168.148.154:8080/api/v1/pki/certificates/$CERT_ID/download/" \
  -H "Authorization: Bearer $TOKEN" \
  -o admin.p12
```

---

## 7. Summary

| Scenario | Frontend Serving | Backend | HTTPS | mTLS |
|----------|------------------|---------|-------|------|
| **Development** | Vite dev server (port 3000) | Django (8080) | ❌ HTTP | ❌ No |
| **nginx Proxy (Current)** | Vite dev server via nginx | Django (8080) | ✅ HTTPS | ✅ Yes |
| **Production Build** | Static files from nginx | Django (8080) | ✅ HTTPS | ✅ Yes |

### Current State (After Your Setup):

- ❌ nginx not configured yet
- ❌ Server certificate not generated
- ❌ CA certificate not exported to nginx path
- ✅ Frontend built files created (after `npm run build`)
- ✅ Dev server works on HTTP (port 3000)

### To Enable HTTPS/mTLS:

1. Complete setup.sh (creates CA in database)
2. Generate server certificate
3. Export CA certificate
4. Configure nginx
5. Download your .p12 certificate
6. Import into browser
7. Access via https://192.168.148.154/

---

## 8. Quick Commands Reference

```bash
# Build frontend
npm run build

# Generate server cert
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/truefypjs/data/certs/server.key \
  -out /opt/truefypjs/data/certs/server.crt \
  -subj "/CN=192.168.148.154"

# Export CA cert (after Django is running)
cd apps && python manage.py export_ca_cert --output /opt/truefypjs/data/certs/ca.crt

# Configure nginx
sudo cp nginx_mtls.conf /etc/nginx/sites-available/jumpserver
sudo ln -s /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Download certificate
curl "http://localhost:8080/api/v1/pki/certificates/{ID}/download/" \
  -H "Authorization: Bearer {TOKEN}" -o admin.p12

# Import to Firefox
firefox → Settings → Certificates → Import → admin.p12
```

---

**Next Step**: Complete `setup.sh` first to initialize the CA, then follow this guide!
