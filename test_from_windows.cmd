@echo off
REM =============================================================================
REM JumpServer Windows Host Test Suite
REM =============================================================================
REM Tests connectivity from Windows host to Ubuntu VM
REM =============================================================================

setlocal enabledelayedexpansion

set VM_IP=192.168.148.154
set PASSED=0
set FAILED=0

echo =========================================
echo JumpServer Test Suite (Windows Host)
echo =========================================
echo.

REM =============================================================================
REM 1. PING TEST
REM =============================================================================
echo [INFO] TEST 1: Network Connectivity
echo -----------------------------------

ping -n 1 %VM_IP% >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] VM is reachable at %VM_IP%
    set /a PASSED+=1
) else (
    echo [FAIL] Cannot ping VM at %VM_IP%
    set /a FAILED+=1
)
echo.

REM =============================================================================
REM 2. HTTP PORT 8080 (Direct Django)
REM =============================================================================
echo [INFO] TEST 2: HTTP Direct Django (Port 8080^)
echo -----------------------------------

curl -s -o nul -w "HTTP %%{http_code}" http://%VM_IP%:8080/api/health/ 2>nul | findstr "200" >nul
if %errorlevel% equ 0 (
    echo [OK] Django accessible on port 8080
    set /a PASSED+=1
) else (
    echo [FAIL] Django NOT accessible on port 8080
    set /a FAILED+=1
)
echo.

REM =============================================================================
REM 3. HTTP PORT 80 (nginx)
REM =============================================================================
echo [INFO] TEST 3: HTTP nginx (Port 80^)
echo -----------------------------------

curl -s -o nul -w "HTTP %%{http_code}" http://%VM_IP%/ 2>nul | findstr /C:"301" /C:"302" >nul
if %errorlevel% equ 0 (
    echo [OK] nginx port 80 redirects to HTTPS
    set /a PASSED+=1
) else (
    echo [FAIL] nginx NOT responding on port 80
    set /a FAILED+=1
)
echo.

REM =============================================================================
REM 4. HTTPS PORT 443 (nginx with SSL)
REM =============================================================================
echo [INFO] TEST 4: HTTPS nginx (Port 443^)
echo -----------------------------------

curl -k -s -o nul -w "HTTP %%{http_code}" https://%VM_IP%/api/health/ 2>nul | findstr "200" >nul
if %errorlevel% equ 0 (
    echo [OK] nginx HTTPS accessible on port 443
    set /a PASSED+=1
) else (
    echo [FAIL] nginx HTTPS NOT accessible on port 443
    set /a FAILED+=1
)
echo.

REM =============================================================================
REM 5. API HEALTH CHECK
REM =============================================================================
echo [INFO] TEST 5: API Health Endpoint
echo -----------------------------------

curl -s http://%VM_IP%:8080/api/health/ 2>nul | findstr "status" >nul
if %errorlevel% equ 0 (
    echo [OK] API health endpoint returns valid JSON
    set /a PASSED+=1
) else (
    echo [FAIL] API health endpoint invalid response
    set /a FAILED+=1
)
echo.

REM =============================================================================
REM 6. CERTIFICATE DOWNLOAD CHECK
REM =============================================================================
echo [INFO] TEST 6: Certificate Files
echo -----------------------------------

if exist "%USERPROFILE%\Desktop\admin.p12" (
    echo [OK] User certificate found on Desktop (admin.p12^)
    set /a PASSED+=1
) else (
    echo [FAIL] User certificate NOT found on Desktop
    echo [INFO] Download with: scp jsroot@%VM_IP%:/opt/truefypjs/data/certs/pki/admin.p12 %USERPROFILE%\Desktop\
    set /a FAILED+=1
)

if exist "%USERPROFILE%\Desktop\internal-ca.crt" (
    echo [OK] CA certificate found on Desktop (internal-ca.crt^)
    set /a PASSED+=1
) else (
    echo [FAIL] CA certificate NOT found on Desktop
    echo [INFO] Download with: scp jsroot@%VM_IP%:/opt/truefypjs/data/certs/mtls/internal-ca.crt %USERPROFILE%\Desktop\
    set /a FAILED+=1
)
echo.

REM =============================================================================
REM SUMMARY
REM =============================================================================
echo =========================================
echo Test Summary
echo =========================================
echo.

set /a TOTAL=PASSED+FAILED
echo Total Tests: %TOTAL%
echo Passed: %PASSED%
echo Failed: %FAILED%
echo.

if %FAILED% equ 0 (
    echo [SUCCESS] ALL TESTS PASSED!
    echo.
    echo Your JumpServer is accessible from Windows host.
    echo.
    echo Next Steps:
    echo   1. Download certificates if not already done
    echo   2. Import admin.p12 into browser (password: changeme123^)
    echo   3. Access https://%VM_IP%/
    echo.
) else (
    echo [ERROR] Some tests failed
    echo.
    echo Common Issues:
    echo   1. Django not running: SSH to VM and run "cd /opt/truefypjs/apps && python manage.py runserver 0.0.0.0:8080"
    echo   2. nginx not running: SSH to VM and run "sudo systemctl start nginx"
    echo   3. Firewall blocking: Check VM firewall settings
    echo.
)

pause
