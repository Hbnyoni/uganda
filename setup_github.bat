@echo off
echo Setting up CHEAQI Uganda Spatial Analysis for GitHub...
echo.

REM Initialize git repository using GitHub Desktop's git
"C:\Users\%USERNAME%\AppData\Local\GitHubDesktop\app-3.3.6\resources\app\git\cmd\git.exe" init

echo Git repository initialized!
echo.
echo Next steps:
echo 1. Open GitHub Desktop
echo 2. Go to File -> Add Local Repository
echo 3. Browse to this folder: %CD%
echo 4. Click "Add Repository"
echo 5. Click "Publish repository" to create it on GitHub
echo.
pause