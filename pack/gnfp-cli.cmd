@echo off
setlocal
cd /d "%~dp0\.."
dart run bin\gnfp_cli.dart %*
exit /b %ERRORLEVEL%
