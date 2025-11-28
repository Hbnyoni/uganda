@echo off
REM CHEAQI Docker Management Script for Windows
REM This script provides easy management commands for the CHEAQI containerization

setlocal enabledelayedexpansion

set PROJECT_NAME=cheaqi-spatial-workbench
set COMPOSE_FILE=docker-compose.yml

REM Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not running. Please start Docker first.
    exit /b 1
)

if "%1"=="build" goto build
if "%1"=="start" goto start
if "%1"=="start-full" goto start_full
if "%1"=="start-batch" goto start_batch
if "%1"=="stop" goto stop
if "%1"=="restart" goto restart
if "%1"=="status" goto status
if "%1"=="logs" goto logs
if "%1"=="shell" goto shell
if "%1"=="process" goto process
if "%1"=="clean" goto clean
if "%1"=="help" goto help
if "%1"=="--help" goto help
if "%1"=="-h" goto help

echo [ERROR] Unknown command: %1
echo.
goto help

:build
echo ================================
echo  Building CHEAQI Container
echo ================================
echo [INFO] Building Docker image...
docker-compose build --no-cache
if %errorlevel% neq 0 exit /b %errorlevel%
echo [INFO] Build completed successfully!
goto :eof

:start
echo ================================
echo  Starting CHEAQI Services
echo ================================
echo [INFO] Starting Jupyter notebook service...
docker-compose up -d cheaqi-notebook
timeout /t 5 >nul
echo [INFO] CHEAQI Jupyter Lab is starting up...
echo [INFO] Access the notebook at: http://localhost:8888
echo [INFO] Use 'docker logs cheaqi-spatial-workbench' to see startup logs
goto :eof

:start_full
echo ================================
echo  Starting CHEAQI with File Server
echo ================================
echo [INFO] Starting all services...
docker-compose --profile fileserver up -d
timeout /t 5 >nul
echo [INFO] Services started successfully!
echo [INFO] Jupyter Lab: http://localhost:8888
echo [INFO] File Server: http://localhost:8080
goto :eof

:start_batch
echo ================================
echo  Starting CHEAQI Batch Processor
echo ================================
echo [INFO] Starting batch processing service...
docker-compose --profile batch up -d cheaqi-processor
echo [INFO] Batch processor is ready!
echo [INFO] Run commands with: docker exec -it cheaqi-batch-processor bash
goto :eof

:stop
echo ================================
echo  Stopping CHEAQI Services
echo ================================
echo [INFO] Stopping all services...
docker-compose down
echo [INFO] All services stopped.
goto :eof

:restart
call :stop
call :start
goto :eof

:status
echo ================================
echo  CHEAQI Service Status
echo ================================
docker-compose ps
goto :eof

:logs
echo ================================
echo  CHEAQI Service Logs
echo ================================
if "%2"=="" (
    docker-compose logs -f
) else (
    docker-compose logs -f %2
)
goto :eof

:shell
echo ================================
echo  Entering CHEAQI Container Shell
echo ================================
docker ps | findstr "cheaqi-spatial-workbench" >nul
if %errorlevel% neq 0 (
    echo [ERROR] CHEAQI container is not running. Start it first with: %0 start
    exit /b 1
)
docker exec -it cheaqi-spatial-workbench bash -c "source activate cheaqi && bash"
goto :eof

:process
echo ================================
echo  Running CHEAQI Processing Workflow
echo ================================
if "%2"=="" (
    echo [ERROR] Please specify a CSV file: %0 process ^<csv_file^>
    exit /b 1
)
set CSV_FILE=%2
if not exist ".\data\%CSV_FILE%" (
    echo [ERROR] CSV file not found in .\data\%CSV_FILE%
    exit /b 1
)
echo [INFO] Processing %CSV_FILE%...
docker exec -it cheaqi-spatial-workbench bash -c "source activate cheaqi && cd /app/scripts && python batch_process.py --input /app/data/%CSV_FILE% --output /app/outputs"
goto :eof

:clean
echo ================================
echo  Cleaning CHEAQI Environment
echo ================================
set /p response="[WARNING] This will remove all containers and images. Continue? (y/N): "
if /i "!response!"=="y" (
    echo [INFO] Stopping services...
    docker-compose down
    echo [INFO] Removing images...
    docker-compose down --rmi all --volumes --remove-orphans
    echo [INFO] Cleanup completed!
) else (
    echo [INFO] Cleanup cancelled.
)
goto :eof

:help
echo CHEAQI Docker Management Script
echo.
echo Usage: %0 ^<command^> [options]
echo.
echo Commands:
echo   build              Build the Docker image
echo   start              Start the Jupyter notebook service
echo   start-full         Start with file server
echo   start-batch        Start batch processor
echo   stop               Stop all services
echo   restart            Restart all services
echo   status             Show service status
echo   logs [service]     Show logs (optionally for specific service)
echo   shell              Enter container shell
echo   process ^<csv^>      Process CSV file with batch workflow
echo   clean              Clean up containers and images
echo   help               Show this help message
echo.
echo Examples:
echo   %0 build                    # Build the container
echo   %0 start                    # Start Jupyter Lab
echo   %0 logs cheaqi-notebook     # Show notebook logs
echo   %0 process data.csv         # Process data.csv file
goto :eof