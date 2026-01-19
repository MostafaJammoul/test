# Quick Start Guide - JumpServer Blockchain Chain of Custody

## Problem: Connection Refused from Host OS

### Root Cause
The Vite dev server was not configured to listen on all network interfaces (0.0.0.0), only on localhost (127.0.0.1). This has been **FIXED**.

---

## ✅ Fixed Issues

1. **Updated `frontend/vite.config.js`**:
   - Added `host: '0.0.0.0'` to listen on all network interfaces
   - Changed API proxy target to `http://127.0.0.1:8080` (local Django)

2. **Created `start_dev.sh`**: Single script to start both services

---

## 🚀 How to Start the Application

### Option 1: Use the Startup Script (Recommended)

```bash
# From the project directory
./start_dev.sh
```

This will:
- ✅ Start PostgreSQL and Redis if not running
- ✅ Start Django backend on `0.0.0.0:8080`
- ✅ Start Vite frontend on `0.0.0.0:3000`
- ✅ Display access URLs
- ✅ Handle graceful shutdown with Ctrl+C

---

### Option 2: Manual Start (Two Terminals)

**Terminal 1 - Django Backend:**
```bash
cd /home/user/test
source venv/bin/activate
cd apps
python manage.py runserver 0.0.0.0:8080
```

**Terminal 2 - Vite Frontend:**
```bash
cd /home/user/test/frontend
npm run dev
```

(No need for `--host` flag anymore, it's in the config)

---

## 🌐 Access URLs

### From Host OS (Windows/Mac):

**VM IP: 21.0.0.180** (auto-detected)

| Service | URL | Purpose |
|---------|-----|---------|
| **Frontend** | `http://21.0.0.180:3000` | Main React UI |
| **Backend** | `http://21.0.0.180:8080` | Django API |
| **Admin Panel** | `http://21.0.0.180:8080/admin` | Django Admin |
| **API Docs** | `http://21.0.0.180:8080/api/docs/` | API Documentation |

**Note**: If you have multiple network interfaces, check your actual IP with:
```bash
hostname -I
```

---

## 🔍 Troubleshooting

### 1. Still Getting "Connection Refused"?

**Check if services are running:**
```bash
# Check Django (should show 0.0.0.0:8080)
ss -tlnp | grep 8080

# Check Vite (should show 0.0.0.0:3000)
ss -tlnp | grep 3000

# Check processes
ps aux | grep -E '(manage.py|vite)'
```

**Expected output:**
```
tcp   LISTEN  0.0.0.0:8080    0.0.0.0:*    users:(("python",pid=XXXX))
tcp   LISTEN  0.0.0.0:3000    0.0.0.0:*    users:(("node",pid=XXXX))
```

---

### 2. Find Your VM's IP Address

```bash
# Method 1
hostname -I

# Method 2
ifconfig | grep "inet " | grep -v "127.0.0.1"

# Method 3 (if ip command exists)
ip addr show | grep "inet " | grep -v "127.0.0.1"
```

---

### 3. Test Connectivity from Within the VM

```bash
# Test Django
curl http://localhost:8080/api/health/

# Test Vite
curl http://localhost:3000
```

---

### 4. Test from Host OS

**Open Command Prompt (Windows) or Terminal (Mac):**

```bash
# Ping the VM
ping 21.0.0.180

# Test port connectivity (if telnet is available)
telnet 21.0.0.180 3000

# Or use curl
curl http://21.0.0.180:3000
curl http://21.0.0.180:8080/api/health/
```

---

### 5. Check Firewall (if needed)

**Ubuntu/Debian:**
```bash
# Check UFW status
sudo ufw status

# If active, allow ports
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp
```

**CentOS/RHEL:**
```bash
# Check firewalld
sudo firewall-cmd --list-ports

# Add ports
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

---

### 6. VM Network Settings (VMware/VirtualBox)

Make sure your VM network adapter is set to:
- **Bridged Mode** (direct access from host)
- **NAT with Port Forwarding** (forward ports 3000 and 8080)
- **Host-Only with DHCP** (if using static IP)

---

## 📝 Default Credentials

**Superuser:**
- Username: `admin`
- Password: `admin`
- Email: `admin@example.com`

**Database:**
- Host: `127.0.0.1:5432`
- Database: `jumpserver`
- User: `jsroot`
- Password: `jsroot`

---

## 🛑 Stopping Services

**If using start_dev.sh:**
```bash
Press Ctrl+C (it will stop both services gracefully)
```

**If running manually:**
```bash
# Find processes
ps aux | grep -E '(manage.py|vite)'

# Kill them
kill <PID>
```

---

## ✅ Verification Checklist

After starting services, verify:

- [ ] Django responds: `curl http://21.0.0.180:8080/api/health/`
- [ ] Vite responds: `curl http://21.0.0.180:3000`
- [ ] Can ping VM from host: `ping 21.0.0.180`
- [ ] Can access frontend in browser: `http://21.0.0.180:3000`
- [ ] Can login with admin/admin

---

## 🔐 Next Steps - Test mTLS

Once connected, test the mTLS authentication:

1. **Import certificate into browser**:
   - File: `data/certs/pki/admin.p12`
   - Password: `changeme123`

2. **Configure nginx for mTLS**:
   ```bash
   sudo cp nginx_mtls.conf /etc/nginx/sites-available/jumpserver
   sudo ln -s /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

3. **Access via HTTPS**:
   - URL: `https://21.0.0.180`
   - Browser will prompt for certificate
   - Select your admin certificate

---

## 📞 Support

If issues persist, check:
1. VM network adapter type (Bridged vs NAT)
2. Host OS firewall (Windows Firewall, Mac Firewall)
3. Antivirus software blocking ports
4. VPN interfering with local network

---

**Auto-detected VM IP**: `21.0.0.180`
**Update this if your IP is different!**
