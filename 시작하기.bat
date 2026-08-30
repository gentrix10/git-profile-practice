@echo off
rem =====================================================
rem  Git Tutorial launcher - double-click to start.
rem  Opens the tutorial in Git Bash automatically.
rem  (ASCII only in this file - do not add Korean here,
rem   cmd.exe cannot parse UTF-8 batch files reliably.)
rem =====================================================
setlocal
cd /d "%~dp0"

set "GITDIR="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "GITDIR=%ProgramFiles%\Git"
if not defined GITDIR if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "GITDIR=%ProgramFiles(x86)%\Git"
if not defined GITDIR if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "GITDIR=%LocalAppData%\Programs\Git"
if not defined GITDIR (
  for /f "delims=" %%i in ('where git.exe 2^>nul') do (
    if not defined GITDIR if exist "%%~dpi..\bin\bash.exe" set "GITDIR=%%~dpi.."
  )
)

if not defined GITDIR (
  echo.
  echo  [Git Tutorial]
  echo  Git is not installed on this computer.
  echo  A download page will now open in your browser.
  echo  Install Git with all DEFAULT options, then run this file again.
  echo.
  start "" https://git-scm.com/downloads
  pause
  exit /b 1
)

rem 1st choice: Windows Terminal hosting Git Bash (best rendering on Win10/11).
rem Note: "%~dp0." keeps the trailing backslash from escaping the closing quote.
where wt.exe >nul 2>nul
if not errorlevel 1 (
  start "" wt.exe -w new -M -d "%~dp0." "%GITDIR%\bin\bash.exe" -lc "exec ./tutorial.sh"
  exit /b 0
)

rem 2nd choice: mintty (the Git Bash terminal) - good Korean/emoji rendering.
if exist "%GITDIR%\usr\bin\mintty.exe" (
  start "Git Tutorial" "%GITDIR%\usr\bin\mintty.exe" -t "Git Tutorial" -w max -h error -e /usr/bin/bash -lc "exec ./tutorial.sh"
  exit /b 0
)

rem Fallback: run bash inside this console window (UTF-8 codepage).
chcp 65001 >nul
"%GITDIR%\bin\bash.exe" -lc "exec ./tutorial.sh"
if errorlevel 1 pause
