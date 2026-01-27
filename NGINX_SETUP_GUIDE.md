# Nginx Setup Guide for JumpServer Blockchain

## 📋 Overview

This guide will help you set up nginx as a reverse proxy for JumpServer with:
- ✅ HTTPS with SSL/TLS
- ✅ mTLS (mutual TLS) for client certificate authentication
- ✅ Proxy to React frontend (Vite dev server or built files)
- ✅ Proxy to Django backend API
- ✅ WebSocket support
- ✅ Security headers

## 🎯 Two Configurations Available

### 1. **Development Mode** (`nginx-jumpserver-dev.conf`)
- Proxies to Vite dev server (port 3000)
- Hot reload support
- Use when running `npm run dev`

### 2. **Production Mode** (`nginx-jumpserver-prod.conf`)
- Serves built React files from static directory
- Better performance and caching
- Use after running `npm run build`

---

## 🚀 Quick Setup (Automated)

### **Step 1: Run the Setup Script**

```bash
# For Development Mode (with npm run dev)
sudo ./setup-nginx.sh dev

# For Production Mode (with built React files)
sudo ./setup-nginx.sh prod
```

The script will:
1. ✅ Install nginx (if not present)
2. ✅ Create necessary directories
3. ✅ Generate self-signed SSL certificates
4. ✅ Install nginx configuration
5. ✅ Test and reload nginx

### **Step 2: Start Your Services**

**For Development Mode:**
```bash
# Terminal 1 - Django Backend
cd /home/user/test/apps
python manage.py runserver 0.0.0.0:8080

# Terminal 2 - React Frontend
cd /home/user/test/frontend
npm run dev
```

**For Production Mode:**
```bash
# Build React frontend first
cd /home/user/test/frontend
npm run build

# Start Django Backend
cd /home/user/test/apps
python manage.py runserver 0.0.0.0:8080
```

### **Step 3: Access JumpServer**

Open your browser:
```
https://<your-vm-ip>/
```

---

## 🔧 Manual Setup (Advanced)

If you prefer manual setup or the script fails:

### **1. Install Nginx**

```bash
sudo apt-get update
sudo apt-get install -y nginx
```

### **2. Create Directories**

```bash
sudo mkdir -p /home/jsroot/js/data/certs/mtls/server-certs
sudo mkdir -p /home/jsroot/js/data/certs/mtls/ca-certs
sudo mkdir -p /home/jsroot/js/data/certs/mtls/client-certs
sudo mkdir -p /home/jsroot/js/data/media
sudo mkdir -p /home/jsroot/js/apps/static/frontend

sudo chown -R jsroot:jsroot /home/jsroot/js/data
```

### **3. Generate SSL Certificates**

```bash
CERT_DIR="/home/jsroot/js/data/certs/mtls"

# Generate CA certificate
sudo openssl req -x509 -newkey rsa:4096 \
  -keyout "$CERT_DIR/ca-certs/ca-key.pem" \
  -out "$CERT_DIR/ca-certs/ca-cert.pem" \
  -days 3650 -nodes \
  -subj "/C=US/ST=State/L=City/O=JumpServer/OU=CA/CN=JumpServer Root CA"

# Generate server private key
sudo openssl genrsa -out "$CERT_DIR/server-certs/server-key.pem" 4096

# Generate server CSR
sudo openssl req -new \
  -key "$CERT_DIR/server-certs/server-key.pem" \
  -out "$CERT_DIR/server-certs/server.csr" \
  -subj "/C=US/ST=State/L=City/O=JumpServer/OU=Server/CN=jumpserver.local"

# Generate server certificate
sudo openssl x509 -req \
  -in "$CERT_DIR/server-certs/server.csr" \
  -CA "$CERT_DIR/ca-certs/ca-cert.pem" \
  -CAkey "$CERT_DIR/ca-certs/ca-key.pem" \
  -CAcreateserial \
  -out "$CERT_DIR/server-certs/server-cert.pem" \
  -days 365 \
  -extfile <(printf "subjectAltName=DNS:jumpserver.local,DNS:localhost,IP:127.0.0.1")

# Set permissions
sudo chmod 600 "$CERT_DIR/server-certs/server-key.pem" "$CERT_DIR/ca-certs/ca-key.pem"
sudo chmod 644 "$CERT_DIR/server-certs/server-cert.pem" "$CERT_DIR/ca-certs/ca-cert.pem"
sudo chown -R jsroot:jsroot "$CERT_DIR"
```

### **4. Install Nginx Configuration**

**For Development:**
```bash
sudo cp nginx-jumpserver-dev.conf /etc/nginx/sites-available/jumpserver-dev
sudo ln -sf /etc/nginx/sites-available/jumpserver-dev /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
```

**For Production:**
```bash
sudo cp nginx-jumpserver-prod.conf /etc/nginx/sites-available/jumpserver
sudo ln -sf /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
```

### **5. Test and Reload Nginx**

```bash
# Test configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Check status
sudo systemctl status nginx
```

---

## 🔐 Client Certificate Setup (mTLS)

For users who need client certificates (Investigators, Auditors, Court officials):

### **Generate Client Certificate**

```bash
CERT_DIR="/home/jsroot/js/data/certs/mtls"
USERNAME="investigator_test"

# Generate client private key
openssl genrsa -out "$CERT_DIR/client-certs/${USERNAME}-key.pem" 4096

# Generate client CSR
openssl req -new \
  -key "$CERT_DIR/client-certs/${USERNAME}-key.pem" \
  -out "$CERT_DIR/client-certs/${USERNAME}.csr" \
  -subj "/C=US/ST=State/L=City/O=JumpServer/OU=Users/CN=${USERNAME}"

# Sign client certificate with CA
openssl x509 -req \
  -in "$CERT_DIR/client-certs/${USERNAME}.csr" \
  -CA "$CERT_DIR/ca-certs/ca-cert.pem" \
  -CAkey "$CERT_DIR/ca-certs/ca-key.pem" \
  -CAcreateserial \
  -out "$CERT_DIR/client-certs/${USERNAME}-cert.pem" \
  -days 365

# Create PKCS#12 file for browser import (.p12)
openssl pkcs12 -export \
  -in "$CERT_DIR/client-certs/${USERNAME}-cert.pem" \
  -inkey "$CERT_DIR/client-certs/${USERNAME}-key.pem" \
  -out "$CERT_DIR/client-certs/${USERNAME}.p12" \
  -name "${USERNAME}" \
  -passout pass:changeme

echo "Client certificate created: ${USERNAME}.p12"
echo "Password: changeme"
```

### **Import Certificate in Browser**

**Chrome/Edge:**
1. Go to Settings → Privacy and Security → Security
2. Click "Manage certificates"
3. Import → Select `.p12` file
4. Enter password: `changeme`
5. Restart browser

**Firefox:**
1. Go to Settings → Privacy & Security
2. Scroll to "Certificates" → View Certificates
3. Your Certificates → Import
4. Select `.p12` file → Enter password
5. Restart browser

---

## 🧪 Testing

### **1. Check Nginx Status**

```bash
sudo systemctl status nginx
```

### **2. Check Nginx Logs**

```bash
# Development mode
sudo tail -f /var/log/nginx/jumpserver_dev_access.log
sudo tail -f /var/log/nginx/jumpserver_dev_error.log

# Production mode
sudo tail -f /var/log/nginx/jumpserver_access.log
sudo tail -f /var/log/nginx/jumpserver_error.log
```

### **3. Test HTTPS Access**

```bash
# Test without certificate (should work for admin login)
curl -k https://localhost/api/v1/users/me/

# Test SSL connection
openssl s_client -connect localhost:443 -showcerts
```

### **4. Access from Browser**

**Without Certificate (Admin Login):**
```
https://<vm-ip>/admin
```
- Should show React login page
- Login with admin username/password
- Optional MFA for password auth

**With Certificate (User Login):**
```
https://<vm-ip>/
```
- Browser will prompt for certificate
- Select your imported `.p12` certificate
- Should redirect to MFA setup (first time) or MFA challenge
- After MFA: Redirects to role-based dashboard

---

## 🐛 Troubleshooting

### **Issue: "Connection Refused"**

**Cause:** Backend services not running

**Fix:**
```bash
# Check if Django is running
curl http://localhost:8080/api/v1/users/me/

# Check if Vite is running (dev mode)
curl http://localhost:3000/

# Check nginx is running
sudo systemctl status nginx
```

### **Issue: "502 Bad Gateway"**

**Cause:** Nginx can't connect to backend

**Fix:**
```bash
# Check nginx error log
sudo tail -f /var/log/nginx/jumpserver_error.log

# Check if ports are listening
sudo netstat -tlnp | grep -E '(3000|8080)'

# Test backend directly
curl http://localhost:8080/api/v1/users/me/
```

### **Issue: "SSL Certificate Error"**

**Cause:** Self-signed certificate not trusted

**Fix:**
1. **Accept the certificate in browser** (proceed anyway)
2. **Or import CA certificate:**
   ```bash
   # Copy CA cert to your local machine
   scp jsroot@<vm-ip>:/home/jsroot/js/data/certs/mtls/ca-certs/ca-cert.pem ./
   ```
   - **Windows:** Double-click → Install → Trusted Root Certification Authorities
   - **Mac:** Keychain Access → Import → Set to "Always Trust"
   - **Linux:** `sudo cp ca-cert.pem /usr/local/share/ca-certificates/jumpserver-ca.crt && sudo update-ca-certificates`

### **Issue: "403 Forbidden" with Client Certificate**

**Cause:** Client certificate not valid or not imported

**Fix:**
1. Check certificate is imported in browser
2. Check certificate is signed by the same CA as server
3. Check nginx logs for certificate validation errors

### **Issue: Vite HMR Not Working**

**Cause:** WebSocket connection failing

**Fix:**
- Check `/@vite/` location in nginx config
- Ensure `proxy_set_header Upgrade` is present
- Check browser console for WebSocket errors

### **Issue: Static Files Not Loading (Production)**

**Cause:** React not built or wrong paths

**Fix:**
```bash
# Build React frontend
cd /home/user/test/frontend
npm run build

# Verify files exist
ls -la /home/user/test/apps/static/frontend/

# Check nginx static location matches
grep -A 5 "location /static/" /etc/nginx/sites-available/jumpserver
```

---

## 📊 Architecture Diagram

```
Browser (HTTPS + Client Cert)
    ↓
nginx (Port 443)
├─ SSL/TLS Termination
├─ Client Certificate Validation (optional)
└─ Reverse Proxy
    ├─ / → React Frontend (Dev: Port 3000 | Prod: Static files)
    ├─ /api/ → Django Backend (Port 8080)
    ├─ /django-admin/ → Django Admin (Port 8080)
    ├─ /static/ → Static Files
    └─ /media/ → Media Files
```

---

## 🔄 Switching Between Dev and Prod

### **Switch to Development Mode:**
```bash
sudo ./setup-nginx.sh dev
```

### **Switch to Production Mode:**
```bash
# Build React first
cd /home/user/test/frontend
npm run build

# Install production config
sudo ./setup-nginx.sh prod
```

---

## 📝 Configuration Files

| File | Purpose |
|------|---------|
| `nginx-jumpserver-dev.conf` | Development config (proxies to Vite) |
| `nginx-jumpserver-prod.conf` | Production config (serves built files) |
| `setup-nginx.sh` | Automated setup script |
| `/etc/nginx/sites-available/` | Nginx config storage |
| `/etc/nginx/sites-enabled/` | Active nginx configs |
| `/home/jsroot/js/data/certs/mtls/` | SSL certificates |

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Nginx is running: `sudo systemctl status nginx`
- [ ] Django backend is running on port 8080
- [ ] React frontend is running on port 3000 (dev) or built (prod)
- [ ] Can access `https://<vm-ip>/` without errors
- [ ] SSL certificate is accepted (or warning is expected for self-signed)
- [ ] Admin login works at `/admin`
- [ ] API calls work: `curl -k https://localhost/api/v1/users/me/`
- [ ] Client certificate import works (for mTLS users)
- [ ] Role-based dashboards load correctly

---

## 🎉 Success!

If everything is working:
- ✅ JumpServer is accessible via HTTPS
- ✅ Admin can login with password + MFA
- ✅ Users can login with certificate + MFA
- ✅ Role-based dashboards display correctly
- ✅ Blockchain integration works
- ✅ Evidence upload/query functions

**Next Steps:**
1. Create users with blockchain roles in Django admin
2. Generate client certificates for users
3. Test evidence upload to blockchain
4. Verify chain of custody tracking

---

**For questions or issues, check the logs:**
```bash
sudo tail -f /var/log/nginx/jumpserver_*_error.log
```
