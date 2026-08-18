@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
TITLE NEXACRO GITHUB PAGES APPLY

rem ============================================================
rem Nexacro portfolio one-click GitHub + Pages deployment
rem Owner: programmer119
rem Repository / keyword: nexacro
rem Pages URL: https://programmer119.github.io/nexacro/
rem ============================================================

set "OWNER=programmer119"
set "REPO=nexacro"
set "FULL_REPO=%OWNER%/%REPO%"
set "REMOTE_URL=https://github.com/%FULL_REPO%.git"
set "PAGE_URL=https://%OWNER%.github.io/%REPO%/"
set "WORKFLOW=pages.yml"
set "ROOT=%~dp0"
cd /d "%ROOT%"

call :banner "1/9  Prerequisite check"
where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed or not in PATH.
  echo Install Git for Windows, reopen this folder, then run apply.bat again.
  goto :fail
)
rem GitHub CLI: use it if already installed, otherwise install automatically with WinGet.
where gh >nul 2>&1
if errorlevel 1 (
  if exist "%ProgramFiles%\GitHub CLI\gh.exe" (
    set "PATH=%ProgramFiles%\GitHub CLI;%PATH%"
  )
)

where gh >nul 2>&1
if errorlevel 1 (
  echo [INFO] GitHub CLI ^(gh^) is not installed. Trying automatic installation with WinGet...
  where winget >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] GitHub CLI is required, but WinGet is not available on this PC.
    echo Install GitHub CLI once, then rerun this file:
    echo   https://cli.github.com/
    echo No repository or GitHub setting has been changed.
    goto :fail
  )

  winget install --id GitHub.cli --source winget -e --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo [ERROR] Automatic GitHub CLI installation failed.
    echo Please run this command manually in Windows Terminal or Command Prompt:
    echo   winget install --id GitHub.cli --source winget -e
    echo Then rerun this apply.bat.
    echo No repository or GitHub setting has been changed.
    goto :fail
  )

  rem The official installer updates PATH only for new terminal windows.
  rem Add the default install folder to this running process so deployment can continue immediately.
  if exist "%ProgramFiles%\GitHub CLI\gh.exe" (
    set "PATH=%ProgramFiles%\GitHub CLI;%PATH%"
  )

  where gh >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] GitHub CLI was installed, but this CMD session still cannot locate gh.exe.
    echo Close this window and run apply.bat again.
    echo No repository or GitHub setting has been changed yet.
    goto :fail
  )
  echo [OK] GitHub CLI installed automatically.
)

echo [OK] Git found.
echo [OK] GitHub CLI found.

call :banner "2/9  GitHub authentication"
gh auth status -h github.com >nul 2>&1
if errorlevel 1 (
  echo GitHub login is required once. A browser authentication window will open.
  gh auth login -h github.com -p https -w -s repo,workflow
  if errorlevel 1 (
    echo [ERROR] GitHub authentication failed.
    goto :fail
  )
)

set "LOGIN="
for /f "usebackq delims=" %%I in (`gh api user --jq ".login" 2^>nul`) do set "LOGIN=%%I"
if not defined LOGIN (
  echo [ERROR] Could not determine the authenticated GitHub account.
  goto :fail
)
if /I not "%LOGIN%"=="%OWNER%" (
  echo [ERROR] Logged-in GitHub account is "%LOGIN%", not "%OWNER%".
  echo Run: gh auth switch -h github.com -u %OWNER%
  echo Then run apply.bat again.
  goto :fail
)
echo [OK] Authenticated as %LOGIN%.

call :banner "3/9  Local repository preparation"
if not exist ".git" (
  git init
  if errorlevel 1 goto :gitfail
)
git checkout -B main >nul 2>&1
if errorlevel 1 goto :gitfail

git config user.name >nul 2>&1
if errorlevel 1 git config user.name "%OWNER%"
git config user.email >nul 2>&1
if errorlevel 1 (
  for /f "usebackq delims=" %%E in (`gh api user --jq ".id" 2^>nul`) do set "GH_UID=%%E"
  if defined GH_UID git config user.email "!GH_UID!+%OWNER%@users.noreply.github.com"
)

git add -A
for /f %%S in ('git status --porcelain ^| find /c /v ""') do set "CHANGE_COUNT=%%S"
if not "%CHANGE_COUNT%"=="0" (
  git commit -m "Prepare Nexacro GitHub Pages deployment"
  if errorlevel 1 goto :gitfail
) else (
  echo [OK] No uncommitted changes.
)

call :banner "4/9  GitHub repository check/create"
gh repo view "%FULL_REPO%" >nul 2>&1
if errorlevel 1 (
  echo Repository does not exist. Creating public repository %FULL_REPO% ...
  gh repo create "%FULL_REPO%" --public --description "Nexacro manufacturing monitoring frontend / XFDL portfolio" --disable-issues --disable-wiki
  if errorlevel 1 (
    echo [ERROR] Repository creation failed.
    goto :fail
  )
  echo [OK] Repository created.
) else (
  echo [OK] Existing repository found: %FULL_REPO%
)

for /f "delims=" %%R in ('git remote 2^>nul') do if /I "%%R"=="origin" set "HAS_ORIGIN=1"
if defined HAS_ORIGIN (
  git remote set-url origin "%REMOTE_URL%"
) else (
  git remote add origin "%REMOTE_URL%"
)

rem If remote main already exists, only continue when histories are compatible.
git ls-remote --exit-code --heads origin main >nul 2>&1
if not errorlevel 1 (
  git fetch origin main
  if errorlevel 1 goto :gitfail
  git merge-base HEAD origin/main >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] %FULL_REPO% already has an unrelated main history.
    echo To avoid overwriting an unrelated repository, this script stopped safely.
    echo Check https://github.com/%FULL_REPO% and either rename/delete that repository,
    echo or tell me to make the script merge/replace it explicitly.
    goto :fail
  )
  git merge-base --is-ancestor origin/main HEAD >nul 2>&1
  if errorlevel 1 (
    git pull --rebase origin main
    if errorlevel 1 (
      echo [ERROR] Existing remote changes could not be rebased automatically.
      echo Resolve the Git conflict first, then rerun apply.bat.
      goto :fail
    )
  )
)

call :banner "5/9  Repository metadata / keyword"
gh repo edit "%FULL_REPO%" --description "Nexacro manufacturing monitoring frontend / XFDL portfolio" --homepage "%PAGE_URL%" --add-topic nexacro
if errorlevel 1 (
  echo [WARN] Repository metadata/topic update failed. Deployment will still be attempted.
) else (
  echo [OK] GitHub topic added: nexacro
)

call :banner "6/9  Enable GitHub Pages (GitHub Actions)"
gh api "repos/%FULL_REPO%/pages" >nul 2>&1
if errorlevel 1 (
  gh api --method POST "repos/%FULL_REPO%/pages" -f build_type=workflow >nul
  if errorlevel 1 (
    echo [ERROR] Could not enable GitHub Pages through the GitHub API.
    echo Your token/account must have permission to manage Pages for this repository.
    echo Manual fallback: GitHub repository ^> Settings ^> Pages ^> Source: GitHub Actions.
    goto :fail
  )
  echo [OK] GitHub Pages enabled with workflow source.
) else (
  gh api --method PUT "repos/%FULL_REPO%/pages" -f build_type=workflow >nul
  if errorlevel 1 (
    echo [WARN] Pages already exists but build type could not be updated automatically.
    echo The existing setting may already be correct; continuing.
  ) else (
    echo [OK] GitHub Pages source set to GitHub Actions.
  )
)

call :banner "7/9  Push source"
git push -u origin main
if errorlevel 1 goto :gitfail
for /f "usebackq delims=" %%H in (`git rev-parse HEAD`) do set "HEAD_SHA=%%H"

echo [OK] Source pushed to https://github.com/%FULL_REPO%
echo [OK] Commit: %HEAD_SHA%

call :banner "8/9  Wait for Pages workflow"
set "RUN_ID="
set /a RETRY=0
:findrun
set /a RETRY+=1
for /f "usebackq delims=" %%R in (`gh run list --repo "%FULL_REPO%" --workflow "%WORKFLOW%" --branch main --commit "%HEAD_SHA%" --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul`) do set "RUN_ID=%%R"
if defined RUN_ID goto :watchrun
if %RETRY% GEQ 20 (
  echo [ERROR] Could not find the GitHub Pages workflow run after waiting.
  echo Check: https://github.com/%FULL_REPO%/actions
  goto :fail
)
echo Waiting for workflow registration... %RETRY%/20
ping 127.0.0.1 -n 4 >nul
goto :findrun

:watchrun
echo Workflow run ID: %RUN_ID%
gh run watch "%RUN_ID%" --repo "%FULL_REPO%" --exit-status
if errorlevel 1 (
  echo [ERROR] GitHub Pages workflow failed.
  echo -------- failed log --------
  gh run view "%RUN_ID%" --repo "%FULL_REPO%" --log-failed
  echo ----------------------------
  goto :fail
)

call :banner "9/9  Verify deployed page"
set /a WEB_RETRY=0
:checkweb
set /a WEB_RETRY+=1
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest -UseBasicParsing -Uri '%PAGE_URL%' -TimeoutSec 15; if($r.StatusCode -ge 200 -and $r.StatusCode -lt 400){exit 0}else{exit 1} } catch { exit 1 }"
if not errorlevel 1 goto :success
if %WEB_RETRY% GEQ 12 (
  echo [WARN] Workflow succeeded, but the public URL did not answer yet.
  echo GitHub Pages propagation can take a little longer.
  echo Check manually: %PAGE_URL%
  goto :done
)
echo Waiting for Pages propagation... %WEB_RETRY%/12
ping 127.0.0.1 -n 6 >nul
goto :checkweb

:success
echo.
echo ============================================================
echo  SUCCESS
ECHO  Repository : https://github.com/%FULL_REPO%
echo  GitHub Page : %PAGE_URL%
echo  Keyword     : nexacro
echo ============================================================
start "" "%PAGE_URL%"
goto :done

:gitfail
echo [ERROR] Git command failed.
goto :fail

:fail
echo.
echo ============================================================
echo  APPLY FAILED - read the error above.
echo ============================================================
pause
exit /b 1

:done
echo.
echo Finished.
pause
exit /b 0

:banner
echo.
echo ============================================================
echo  %~1
echo ============================================================
exit /b 0
