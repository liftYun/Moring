@echo off
echo ========================================
echo Manual Installation Guide
echo ========================================
echo.

echo If dlib installation failed, follow these steps:
echo.
echo 1. Install Visual Studio Build Tools:
echo    - Download from: https://visualstudio.microsoft.com/visual-cpp-build-tools/
echo    - Install with "C++ build tools" selected
echo.
echo 2. Install CMake:
echo    - Download from: https://cmake.org/download/
echo    - Choose "Add CMake to PATH" during installation
echo.
echo 3. Restart your computer
echo.
echo 4. Open new command prompt and run:
echo    pip install dlib==20.0.0
echo    pip install face-recognition==1.3.0
echo.
echo 5. Test installation:
echo    python -c "import dlib; print('dlib OK')"
echo    python -c "import face_recognition; print('face_recognition OK')"
echo.
echo Alternative: Use conda instead of pip
echo    conda install -c conda-forge dlib face-recognition -y
echo.
pause


