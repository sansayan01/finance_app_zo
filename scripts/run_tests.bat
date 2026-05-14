@echo off
REM Test Runner Script for MicroFlow Pro
REM Run all tests with coverage

echo ========================================
echo MicroFlow Pro - Test Runner
echo ========================================
echo.

echo [1/4] Running Unit Tests...
call flutter test test/unit/ --reporter compact
if errorlevel 1 (
    echo UNIT TESTS FAILED
    exit /b 1
)
echo.

echo [2/4] Running Widget Tests...
call flutter test test/widget/ --reporter compact
if errorlevel 1 (
    echo WIDGET TESTS FAILED
    exit /b 1
)
echo.

echo [3/4] Running Analysis...
call flutter analyze
if errorlevel 1 (
    echo ANALYSIS FAILED
    exit /b 1
)
echo.

echo [4/4] Running Integration Tests...
call flutter test integration_test/ --reporter compact
if errorlevel 1 (
    echo INTEGRATION TESTS FAILED
    exit /b 1
)
echo.

echo ========================================
echo ALL TESTS PASSED!
echo ========================================
exit /b 0