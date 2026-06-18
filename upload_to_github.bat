@echo off
setlocal EnableExtensions EnableDelayedExpansion

if /I not "%~1"=="--worker" (
  for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "LAUNCH_STAMP=%%I"
  set "WORKER_BAT=%TEMP%\my-mascot-upload-worker-!LAUNCH_STAMP!.bat"
  copy /Y "%~f0" "!WORKER_BAT!" >nul
  if errorlevel 1 (
    echo Failed to create temporary upload worker.
    ping -n 16 127.0.0.1 >nul
    exit /b 1
  )
  call "!WORKER_BAT!" --worker "%~dp0"
  set "EXIT_CODE=%ERRORLEVEL%"
  del "!WORKER_BAT!" >nul 2>nul
  exit /b !EXIT_CODE!
)

set "PROJECT_DIR=%~2"
if "%PROJECT_DIR%"=="" set "PROJECT_DIR=%CD%"
cd /d "%PROJECT_DIR%"

set "REPO_URL=https://github.com/DSKR2023/my-mascot.git"
set "BRANCH=main"
set "COMMIT_MSG=Update Desktop Mascot site for ad review"
set "FILES=.editorconfig index.html privacy.html terms.html robots.txt sitemap.xml ads.txt README.md upload_to_github.bat"

echo.
echo Desktop Mascot site upload script
echo Target repository: %REPO_URL%
echo Target branch: %BRANCH%
echo Working folder: %CD%
echo This script is only for https://my-mascot-bay.vercel.app/
echo.

where git >nul 2>nul
if errorlevel 1 (
  echo Git is not installed or not available in PATH.
  pause
  exit /b 1
)

if not exist ".git" (
  echo Initializing git repository...
  git init
  if errorlevel 1 goto :error
)

git remote get-url origin >nul 2>nul
if errorlevel 1 (
  git remote add origin %REPO_URL%
) else (
  git remote set-url origin %REPO_URL%
)
if errorlevel 1 goto :error

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "STAMP=%%I"
set "SYNC_DIR=%TEMP%\my-mascot-upload-%STAMP%"
mkdir "%SYNC_DIR%"
if errorlevel 1 goto :error

echo.
echo Saving current site files temporarily...
for %%F in (%FILES%) do (
  if exist "%%F" copy /Y "%%F" "%SYNC_DIR%\%%F" >nul
)

echo.
echo Saving local changes before syncing with GitHub main...
git branch -M %BRANCH%
git add %FILES%
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "Save local Desktop Mascot site files before syncing"
  if errorlevel 1 goto :error
) else (
  echo No local pre-sync changes to commit.
)

git rev-parse --verify HEAD >nul 2>nul
if not errorlevel 1 (
  git branch "backup-before-upload-%STAMP%" HEAD >nul 2>nul
)

echo.
echo Fetching GitHub main...
git fetch origin %BRANCH%
if errorlevel 1 goto :error

git rev-parse --verify "origin/%BRANCH%" >nul 2>nul
if not errorlevel 1 (
  echo Switching local main to GitHub main...
  git switch -C %BRANCH% "origin/%BRANCH%"
  if errorlevel 1 goto :error
) else (
  echo GitHub main was not found. Creating local main...
  git switch -C %BRANCH%
  if errorlevel 1 goto :error
)

echo.
echo Restoring site files onto main...
for %%F in (%FILES%) do (
  if exist "%SYNC_DIR%\%%F" copy /Y "%SYNC_DIR%\%%F" "%%F" >nul
)
rmdir /S /Q "%SYNC_DIR%" >nul 2>nul

git add %FILES%
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "%COMMIT_MSG%"
  if errorlevel 1 goto :error
) else (
  echo No site file changes to commit.
)

echo.
echo Pushing to GitHub main...
git push -u origin %BRANCH%
if errorlevel 1 goto :error

echo.
echo Upload completed.
echo Branch: %BRANCH%
echo Commit message: %COMMIT_MSG%
ping -n 9 127.0.0.1 >nul
exit /b 0

:error
echo.
echo Upload failed. Check the message above, GitHub login, and repository permission.
if exist "%SYNC_DIR%" rmdir /S /Q "%SYNC_DIR%" >nul 2>nul
ping -n 16 127.0.0.1 >nul
exit /b 1
