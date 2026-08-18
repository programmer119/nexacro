@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
TITLE NEXACRO GITHUB PAGES APPLY v5

rem ============================================================
rem Nexacro portfolio one-click GitHub + Pages deployment
rem Owner: programmer119
rem Repository / keyword: nexacro
rem Visibility: PUBLIC
rem Pages URL: https://programmer119.github.io/nexacro/
rem
rem v5 changes:
rem - DOES NOT depend on PATH after portable gh download.
rem - Calls gh.exe by its exact absolute path.
rem - Reuses any already-downloaded .tools\...\gh.exe first.
rem - Architecture-aware fallback: amd64 / arm64 / 386.
rem ============================================================

set "OWNER=programmer119"
set "REPO=nexacro"
set "FULL_REPO=%OWNER%/%REPO%"
set "REMOTE_URL=https://github.com/%FULL_REPO%.git"
set "PAGE_URL=https://%OWNER%.github.io/%REPO%/"
set "WORKFLOW=pages.yml"
set "ROOT=%~dp0"
set "TOOLS_DIR=%ROOT%.tools"
set "GH_EXE="
set "TMP_OUT=%TEMP%\nexacro_apply_%RANDOM%_%RANDOM%.txt"
cd /d "%ROOT%"

call :banner "1/10  Prerequisite check / portable GitHub CLI bootstrap"
where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed or not in PATH.
  echo Install Git for Windows, then run apply.bat again.
  goto :fail
)

echo [INFO] Looking for a usable GitHub CLI...
call :find_existing_gh
if not errorlevel 1 goto :gh_ready

echo [INFO] No usable GitHub CLI found. Bootstrapping an official portable build...
where powershell >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Windows PowerShell is not available.
  echo No repository or GitHub setting has been changed.
  goto :fail
)

if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%" >nul 2>&1

rem Choose the most likely native architecture first, then a safe fallback.
set "NATIVE_ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "NATIVE_ARCH=%PROCESSOR_ARCHITEW6432%"
echo [INFO] Windows processor architecture reported as: %NATIVE_ARCH%

if /I "%NATIVE_ARCH%"=="ARM64" (
  call :download_and_test_gh arm64
  if not errorlevel 1 goto :gh_ready
  call :download_and_test_gh amd64
  if not errorlevel 1 goto :gh_ready
  call :download_and_test_gh 386
  if not errorlevel 1 goto :gh_ready
) else if /I "%NATIVE_ARCH%"=="AMD64" (
  call :download_and_test_gh amd64
  if not errorlevel 1 goto :gh_ready
  call :download_and_test_gh 386
  if not errorlevel 1 goto :gh_ready
) else (
  call :download_and_test_gh 386
  if not errorlevel 1 goto :gh_ready
  call :download_and_test_gh amd64
  if not errorlevel 1 goto :gh_ready
)

echo [ERROR] Official portable GitHub CLI was downloaded, but none of the compatible builds could run.
echo [INFO] This is no longer a PATH problem.
echo [INFO] Likely causes: Windows application-control policy, antivirus blocking gh.exe, or an unusual CPU/OS architecture.
echo [INFO] No repository or GitHub setting has been changed.
goto :fail

:gh_ready
echo [OK] Git found.
echo [OK] GitHub CLI executable: %GH_EXE%
"%GH_EXE%" --version
if errorlevel 1 (
  echo [ERROR] GitHub CLI was located but failed its final execution test.
  goto :fail
)

call :banner "2/10  GitHub authentication"
"%GH_EXE%" auth status -h github.com >nul 2>&1
if errorlevel 1 (
  echo GitHub login is required once. A browser authentication window will open.
  "%GH_EXE%" auth login -h github.com -p https -w -s repo,workflow
  if errorlevel 1 (
    echo [ERROR] GitHub authentication failed.
    goto :fail
  )
)

"%GH_EXE%" api user --jq ".login" > "%TMP_OUT%" 2>nul
set "LOGIN="
if exist "%TMP_OUT%" set /p "LOGIN="<"%TMP_OUT%"
del /q "%TMP_OUT%" >nul 2>&1
if not defined LOGIN (
  echo [ERROR] Could not determine the authenticated GitHub account.
  goto :fail
)
if /I not "%LOGIN%"=="%OWNER%" (
  echo [ERROR] Logged-in GitHub account is "%LOGIN%", not "%OWNER%".
  echo Run this command and then rerun apply.bat:
  echo "%GH_EXE%" auth switch -h github.com -u %OWNER%
  goto :fail
)

"%GH_EXE%" auth setup-git -h github.com >nul 2>&1
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
  "%GH_EXE%" api user --jq ".id" > "%TMP_OUT%" 2>nul
  set "GH_UID="
  if exist "%TMP_OUT%" set /p "GH_UID="<"%TMP_OUT%"
  del /q "%TMP_OUT%" >nul 2>&1
  if defined GH_UID git config user.email "!GH_UID!+%OWNER%@users.noreply.github.com"
)

git add -A
set "CHANGE_COUNT=0"
for /f %%S in ('git status --porcelain ^| find /c /v ""') do set "CHANGE_COUNT=%%S"
if not "%CHANGE_COUNT%"=="0" (
  git commit -m "Prepare Nexacro GitHub Pages deployment"
  if errorlevel 1 goto :gitfail
) else (
  echo [OK] No uncommitted changes.
)

call :banner "4/10  GitHub repository check/create"
"%GH_EXE%" repo view "%FULL_REPO%" >nul 2>&1
if errorlevel 1 (
  echo Repository does not exist. Creating PUBLIC repository %FULL_REPO% ...
  "%GH_EXE%" repo create "%FULL_REPO%" --public --description "Nexacro manufacturing monitoring frontend / XFDL portfolio" --disable-issues --disable-wiki
  if errorlevel 1 (
    echo [ERROR] Repository creation failed.
    goto :fail
  )
  echo [OK] PUBLIC repository created.
) else (
  echo [OK] Existing repository found: %FULL_REPO%
)

"%GH_EXE%" repo edit "%FULL_REPO%" --visibility public --accept-visibility-change-consequences >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Could not ensure that %FULL_REPO% is PUBLIC.
  echo Source push was stopped before continuing.
  goto :fail
)

"%GH_EXE%" repo view "%FULL_REPO%" --json visibility --jq ".visibility" > "%TMP_OUT%" 2>nul
set "REPO_VISIBILITY="
if exist "%TMP_OUT%" set /p "REPO_VISIBILITY="<"%TMP_OUT%"
del /q "%TMP_OUT%" >nul 2>&1
if /I not "%REPO_VISIBILITY%"=="PUBLIC" (
  echo [ERROR] Repository visibility is "%REPO_VISIBILITY%", expected PUBLIC.
  goto :fail
)
echo [OK] Repository visibility verified: PUBLIC.

set "HAS_ORIGIN="
for /f "delims=" %%R in ('git remote 2^>nul') do if /I "%%R"=="origin" set "HAS_ORIGIN=1"
if defined HAS_ORIGIN (
  git remote set-url origin "%REMOTE_URL%"
) else (
  git remote add origin "%REMOTE_URL%"
)

rem Existing remote main is protected from accidental unrelated-history overwrite.
git ls-remote --exit-code --heads origin main >nul 2>&1
if not errorlevel 1 (
  git fetch origin main
  if errorlevel 1 goto :gitfail
  git merge-base HEAD origin/main >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] %FULL_REPO% already has an unrelated main history.
    echo The script stopped instead of overwriting it.
    echo Check: https://github.com/%FULL_REPO%
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
"%GH_EXE%" repo edit "%FULL_REPO%" --description "Nexacro manufacturing monitoring frontend / XFDL portfolio" --homepage "%PAGE_URL%" --add-topic nexacro
if errorlevel 1 (
  echo [WARN] Repository metadata/topic update failed. Deployment will still be attempted.
) else (
  echo [OK] GitHub topic added: nexacro
)

call :banner "6/10  Push source"
git push -u origin main
if errorlevel 1 goto :gitfail
set "HEAD_SHA="
for /f "delims=" %%H in ('git rev-parse HEAD') do set "HEAD_SHA=%%H"
echo [OK] Source pushed to https://github.com/%FULL_REPO%
echo [OK] Commit: %HEAD_SHA%

call :banner "7/10  Enable GitHub Pages (GitHub Actions)"
"%GH_EXE%" api "repos/%FULL_REPO%/pages" >nul 2>&1
if errorlevel 1 (
  "%GH_EXE%" api --method POST "repos/%FULL_REPO%/pages" -f build_type=workflow >nul
  if errorlevel 1 (
    echo [ERROR] Could not enable GitHub Pages through the GitHub API.
    echo Manual fallback required: Repository ^> Settings ^> Pages ^> Source: GitHub Actions.
    goto :fail
  )
  echo [OK] GitHub Pages enabled with workflow source.
) else (
  "%GH_EXE%" api --method PUT "repos/%FULL_REPO%/pages" -f build_type=workflow >nul
  if errorlevel 1 (
    echo [ERROR] Pages exists, but its source could not be changed to GitHub Actions automatically.
    echo Manual fallback required: Repository ^> Settings ^> Pages ^> Source: GitHub Actions.
    goto :fail
  )
  echo [OK] GitHub Pages source set to GitHub Actions.
)

call :banner "8/10  Register and trigger Pages workflow"
set /a WF_RETRY=0
:waitworkflow
set /a WF_RETRY+=1
"%GH_EXE%" workflow view "%WORKFLOW%" --repo "%FULL_REPO%" >nul 2>&1
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
"%GH_EXE%" workflow run "%WORKFLOW%" --repo "%FULL_REPO%" --ref main
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
"%GH_EXE%" run list --repo "%FULL_REPO%" --workflow "%WORKFLOW%" --branch main --commit "%HEAD_SHA%" --event workflow_dispatch --limit 1 --json databaseId --jq ".[0].databaseId" > "%TMP_OUT%" 2>nul
set "RUN_ID="
if exist "%TMP_OUT%" set /p "RUN_ID="<"%TMP_OUT%"
del /q "%TMP_OUT%" >nul 2>&1
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
"%GH_EXE%" run watch "%RUN_ID%" --repo "%FULL_REPO%" --exit-status
if errorlevel 1 (
  echo [ERROR] GitHub Pages workflow failed.
  echo -------- failed log --------
  "%GH_EXE%" run view "%RUN_ID%" --repo "%FULL_REPO%" --log-failed
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

rem ------------------------------------------------------------
rem Find any usable gh.exe without relying on PATH changes.
rem ------------------------------------------------------------
:find_existing_gh
set "GH_EXE="
where gh > "%TMP_OUT%" 2>nul
if not errorlevel 1 (
  set /p "GH_EXE="<"%TMP_OUT%"
  if defined GH_EXE (
    "%GH_EXE%" --version >nul 2>&1
    if not errorlevel 1 (
      del /q "%TMP_OUT%" >nul 2>&1
      exit /b 0
    )
    set "GH_EXE="
  )
)
del /q "%TMP_OUT%" >nul 2>&1

if exist "%ProgramFiles%\GitHub CLI\gh.exe" (
  set "GH_EXE=%ProgramFiles%\GitHub CLI\gh.exe"
  "%ProgramFiles%\GitHub CLI\gh.exe" --version >nul 2>&1
  if not errorlevel 1 exit /b 0
  set "GH_EXE="
)

rem Reuse portable builds from previous apply attempts.
if exist "%TOOLS_DIR%" (
  for /r "%TOOLS_DIR%" %%G in (gh.exe) do (
    if not defined GH_EXE (
      "%%~fG" --version >nul 2>&1
      if not errorlevel 1 set "GH_EXE=%%~fG"
    )
  )
)
if defined GH_EXE exit /b 0
exit /b 1

rem ------------------------------------------------------------
rem Download one official architecture build and test exact EXE.
rem arg1: amd64 / arm64 / 386
rem ------------------------------------------------------------
:download_and_test_gh
set "TRY_ARCH=%~1"
set "TRY_DIR=%TOOLS_DIR%\gh-%TRY_ARCH%"
set "TRY_EXE="
echo [INFO] Trying official GitHub CLI Windows %TRY_ARCH% build...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $headers=@{'User-Agent'='nexacro-apply-v5'}; $r=Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/cli/cli/releases/latest'; $tag=[string]$r.tag_name; if([string]::IsNullOrWhiteSpace($tag)){throw 'Latest GitHub CLI tag could not be read.'}; $ver=$tag.TrimStart('v'); $arch='%TRY_ARCH%'; $asset='gh_'+$ver+'_windows_'+$arch+'.zip'; $url='https://github.com/cli/cli/releases/download/'+$tag+'/'+$asset; $zip=Join-Path $env:TEMP ('nexacro_gh_'+$arch+'.zip'); $dst='%TRY_DIR%'; if(Test-Path $dst){Remove-Item -Recurse -Force $dst}; if(Test-Path $zip){Remove-Item -Force $zip}; Write-Host ('[INFO] Downloading '+$url); Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $zip; Expand-Archive -Path $zip -DestinationPath $dst -Force; Remove-Item -Force $zip"
if errorlevel 1 (
  echo [WARN] Download/extract failed for %TRY_ARCH%.
  exit /b 1
)

for /r "%TRY_DIR%" %%G in (gh.exe) do if not defined TRY_EXE set "TRY_EXE=%%~fG"
if not defined TRY_EXE (
  echo [WARN] gh.exe was not found after extracting %TRY_ARCH% build.
  exit /b 1
)

echo [INFO] Direct execution test: %TRY_EXE%
"%TRY_EXE%" --version >nul 2>&1
if errorlevel 1 (
  echo [WARN] %TRY_ARCH% gh.exe exists but Windows refused to execute it.
  set "TRY_EXE="
  exit /b 1
)

set "GH_EXE=%TRY_EXE%"
echo [OK] Portable GitHub CLI is executable: %GH_EXE%
exit /b 0

:gitfail
echo [ERROR] Git command failed.
goto :fail

:fail
if exist "%TMP_OUT%" del /q "%TMP_OUT%" >nul 2>&1
echo.
echo ============================================================
echo  APPLY FAILED - read the error above.
echo ============================================================
pause
exit /b 1

:done
if exist "%TMP_OUT%" del /q "%TMP_OUT%" >nul 2>&1
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
