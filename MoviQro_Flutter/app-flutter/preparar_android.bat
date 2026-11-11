@echo off
REM Genera los archivos de Gradle/Android que faltan (una sola vez) y descarga dependencias.
REM Requiere Flutter instalado y en el PATH (flutter doctor).
cd /d "%~dp0"
flutter create --platforms=android --org mx.moviqro --project-name moviqro -a kotlin .
if errorlevel 1 exit /b 1
flutter pub get
echo.
echo Listo. Edite android\app\src\main\AndroidManifest.xml y ponga su clave de Google Maps.
echo Luego: flutter run --dart-define-from-file=config\app.json
