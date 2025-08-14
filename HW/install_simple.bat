@echo off
echo ========================================
echo Driver Monitoring System Installation
echo ========================================
echo.

echo Step 1: Upgrading pip...
python -m pip install --upgrade pip

echo.
echo Step 2: Installing core packages...
pip install opencv-python==4.11.0.86
pip install opencv-contrib-python==4.11.0.86
pip install numpy==1.26.4
pip install scipy==1.16.1
pip install pillow==11.3.0
pip install mediapipe==0.10.21
pip install ultralytics==8.3.170
pip install torch==2.5.1+cu121
pip install torchvision==0.20.1+cu121
pip install torchaudio==2.5.1+cu121
pip install matplotlib==3.10.3
pip install scikit-learn==1.7.1
pip install tqdm==4.67.1

echo.
echo Step 3: Installing dlib (trying multiple methods)...
echo Method 1: Trying pip install dlib...
pip install dlib==20.0.0
if %errorlevel% neq 0 (
    echo dlib pip install failed, trying alternative methods...
    echo Method 2: Trying conda install dlib...
    conda install -c conda-forge dlib -y
    if %errorlevel% neq 0 (
        echo conda install failed, trying pre-compiled wheel...
        echo Method 3: Trying pre-compiled wheel...
        pip install https://github.com/jloh02/dlib/releases/download/v19.22/dlib-19.22.99-cp312-cp312-win_amd64.whl
        if %errorlevel% neq 0 (
            echo All dlib installation methods failed.
            echo Please install Visual Studio Build Tools and CMake manually.
            echo Then run: pip install dlib==20.0.0
        )
    )
)

echo.
echo Step 4: Installing face-recognition...
pip install face-recognition==1.3.0
pip install face_recognition_models==0.3.0

echo.
echo Step 5: Testing installation...
python -c "import cv2; print('OpenCV: OK')"
python -c "import numpy; print('NumPy: OK')"
python -c "import mediapipe; print('MediaPipe: OK')"
python -c "import torch; print('PyTorch: OK')"
python -c "import ultralytics; print('Ultralytics: OK')"

echo.
echo Testing dlib and face_recognition...
python -c "import dlib; print('dlib: OK')" 2>nul || echo dlib: FAILED - manual installation required
python -c "import face_recognition; print('face_recognition: OK')" 2>nul || echo face_recognition: FAILED - dlib issue

echo.
echo Installation complete!
echo If dlib failed, please install Visual Studio Build Tools and CMake.
echo Run: python driver_monitor_v2.py
pause
