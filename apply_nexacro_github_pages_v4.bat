@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
TITLE NEXACRO GITHUB PAGES APPLY v4

rem ============================================================
rem Nexacro portfolio one-click GitHub + Pages deployment
rem Owner: programmer119
rem Repository / keyword: nexacro
rem Visibility: PUBLIC
rem Pages URL: https://programmer119.github.io/nexacro/
rem ============================================================

set "OWNER=programmer119"
set "REPO=nexacro"
set "FULL_REPO=%OWNER%/%REPO%"
set "REMOTE_URL=https://github.com/%FULL_REPO%.git"
set "PAGE_URL=https://%OWNER%.github.io/%REPO%/"
set "WORKFLOW=pages.yml"
set "ROOT=%~dp0"
set "TOOLS_DIR=%ROOT%.tools"
cd /d "%ROOT%"

call :banner "1/10  Prerequisite check / portable GitHub CLI bootstrap"
where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed or not in PATH.
  echo Install Git for Windows, reopen this folder, then run apply.bat again.
  goto :fail
)

rem Use an existing GitHub CLI if available.
where gh >nul 2>&1
if errorlevel 1 (
  if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "PATH=%ProgramFiles%\GitHub CLI;%PATH%"
)

rem No WinGet is required. If gh is still missing, download the official
rem Windows amd64 ZIP from the latest GitHub CLI release into .tools\gh.
rem IMPORTANT: this PowerShell command intentionally contains NO pipe symbols,
rem avoiding CMD/PowerShell escaping problems on older Windows CMD versions.
where gh >nul 2>&1
if errorlevel 1 (
  echo [INFO] GitHub CLI ^(gh^) is not installed. Downloading the official portable build...
  where powershell >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Windows PowerShell is not available, so GitHub CLI cannot be downloaded automatically.
    echo No repository or GitHub setting has been changed.
    goto :fail
  )

  if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%" >nul 2>&1

  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $headers=@{'User-Agent'='nexacro-apply'}; $r=Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/cli/cli/releases/latest'; $tag=[string]$r.tag_name; if([string]::IsNullOrWhiteSpace($tag)){throw 'Latest GitHub CLI tag could not be read.'}; $ver=$tag.TrimStart('v'); $asset='gh_'+$ver+'_windows_amd64.zip'; $url='https://github.com/cli/cli/releases/download/'+$tag+'/'+$asset; $zip=Join-Path $env:TOOLS_DIR 'gh.zip'; $dst=Join-Path $env:TOOLS_DIR 'gh'; if(Test-Path $dst){Remove-Item -Recurse -Force $dst}; if(Test-Path $zip){Remove-Item -Force $zip}; Write-Host ('[INFO] Downloading '+$url); Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $zip; Expand-Archive -Path $zip -DestinationPath $dst -Force; Remove-Item -Force $zip"
  if errorlevel 1 (
    echo [ERROR] Automatic portable GitHub CLI download failed.
    echo This step requires HTTPS access to api.github.com and github.com.
    echo No repository or GitHub setting has been changed.
    goto :fail
  )

  set "LOCAL_GH_DIR="
  for /r "%TOOLS_DIR%\gh" %%G in (gh.exe) do if not defined LOCAL_GH_DIR set "LOCAL_GH_DIR=%%~dpG"
  if not defined LOCAL_GH_DIR (
    echo [ERROR] gh.exe was downloaded but could not be located.
    echo No repository or GitHub setting has been changed.
    goto :fail
  )
  set "PATH=!LOCAL_GH_DIR!;%PATH%"

  where gh >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Portable gh.exe exists but cannot be executed from this CMD session.
    echo No repository or GitHub setting has been changed.
    goto :fail
  )
  echo [OK] Portable GitHub CLI downloaded locally. No administrator rights or WinGet required.
)

echo [OK] Git found.
echo [OK] GitHub CLI found.
gh --version | findstr /b /c:"gh version"

call :banner "2/10  GitHub authentication"
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

gh auth setup-git -h github.com >nul 2>&1
if errorlevel 1 (
  echo [WARN] gh could not configure Git credential integration automatically.
  echo Git push will still be attempted with the current Git credential setup.
)
echo [OK] Authenticated as %LOGIN%.

call :banner "3/10  Local repository preparation"
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

call :banner "4/10  GitHub repository check/create"
gh repo view "%FULL_REPO%" >nul 2>&1
if errorlevel 1 (
  echo Repository does not exist. Creating PUBLIC repository %FULL_REPO% ...
  gh repo create "%FULL_REPO%" --public --description "Nexacro manufacturing monitoring frontend / XFDL portfolio" --disable-issues --disable-wiki
  if errorlevel 1 (
    echo [ERROR] Repository creation failed.
    goto :fail
  )
  echo [OK] PUBLIC repository created.
) else (
  echo [OK] Existing repository found: %FULL_REPO%
)

rem The user explicitly requested a public source repository + public Pages site.
gh repo edit "%FULL_REPO%" --visibility public --accept-visibility-change-consequences >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Could not ensure that %FULL_REPO% is PUBLIC.
  echo No source will be pushed until repository visibility can be verified.
  goto :fail
)
for /f "usebackq delims=" %%V in (`gh repo view "%FULL_REPO%" --json visibility --jq ".visibility" 2^>nul`) do set "REPO_VISIBILITY=%%V"
if /I not "%REPO_VISIBILITY%"=="PUBLIC" (
  echo [ERROR] Repository visibility is "%REPO_VISIBILITY%", expected PUBLIC.
  goto :fail
)
echo [OK] Repository visibility verified: PUBLIC.

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
    echo or explicitly decide that replacing its contents is safe.
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

call :banner "5/10  Repository metadata / keyword"
gh repo edit "%FULL_REPO%" --description "Nexacro manufacturing monitoring frontend / XFDL portfolio" --homepage "%PAGE_URL%" --add-topic nexacro
if errorlevel 1 (
  echo [WARN] Repository metadata/topic update failed. Deployment will still be attempted.
) else (
  echo [OK] GitHub topic added: nexacro
)

call :banner "6/10  Push source"
git push -u origin main
if errorlevel 1 goto :gitfail
for /f "usebackq delims=" %%H in (`git rev-parse HEAD`) do set "HEAD_SHA=%%H"
echo [OK] Source pushed to https://github.com/%FULL_REPO%
echo [OK] Commit: %HEAD_SHA%

call :banner "7/10  Enable GitHub Pages (GitHub Actions)"
gh api "repos/%FULL_REPO%/pages" >nul 2>&1
if errorlevel 1 (
  gh api --method POST "repos/%FULL_REPO%/pages" -f build_type=workflow >nul
  if errorlevel 1 (
    echo [ERROR] Could not enable GitHub Pages through the GitHub API.
    echo Manual fallback: GitHub repository ^> Settings ^> Pages ^> Source: GitHub Actions.
    goto :fail
  )
  echo [OK] GitHub Pages enabled with workflow source.
) else (
  gh api --method PUT "repos/%FULL_REPO%/pages" -f build_type=workflow >nul
  if errorlevel 1 (
    echo [ERROR] Pages exists, but its source could not be changed to GitHub Actions automatically.
    echo Manual fallback: GitHub repository ^> Settings ^> Pages ^> Source: GitHub Actions.
    goto :fail
  )
  echo [OK] GitHub Pages source set to GitHub Actions.
)

call :banner "8/10  Register and trigger Pages workflow"
set /a WF_RETRY=0
:waitworkflow
set /a WF_RETRY+=1
gh workflow view "%WORKFLOW%" --repo "%FULL_REPO%" >nul 2>&1
if not errorlevel 1 goto :triggerworkflow
if %WF_RETRY% GEQ 20 (
  echo [ERROR] GitHub did not register %WORKFLOW% after the source push.
  echo Check: https://github.com/%FULL_REPO%/actions
  goto :fail
)
echo Waiting for workflow registration... %WF_RETRY%/20
ping 127.0.0.1 -n 3 >nul
goto :waitworkflow

:triggerworkflow
gh workflow run "%WORKFLOW%" --repo "%FULL_REPO%" --ref main
if errorlevel 1 (
  echo [ERROR] Could not trigger the Pages workflow manually.
  goto :fail
)
echo [OK] Pages workflow dispatch requested.

call :banner "9/10  Wait for Pages workflow"
set "RUN_ID="
set /a RETRY=0
:findrun
set /a RETRY+=1
for /f "usebackq delims=" %%R in (`gh run list --repo "%FULL_REPO%" --workflow "%WORKFLOW%" --branch main --commit "%HEAD_SHA%" --event workflow_dispatch --limit 1 --json databaseId --jq ".[0].databaseId" 2^>nul`) do set "RUN_ID=%%R"
if defined RUN_ID goto :watchrun
if %RETRY% GEQ 20 (
  echo [ERROR] Could not find the manually triggered GitHub Pages workflow run.
  echo Check: https://github.com/%FULL_REPO%/actions
  goto :fail
)
echo Waiting for workflow run registration... %RETRY%/20
ping 127.0.0.1 -n 3 >nul
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

call :banner "10/10  Verify deployed page"
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
echo  Repository : https://github.com/%FULL_REPO%
echo  Visibility : PUBLIC
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
