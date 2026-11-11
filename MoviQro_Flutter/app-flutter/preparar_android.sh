#!/usr/bin/env bash
# Genera los archivos de Gradle/Android que faltan (una sola vez) y descarga dependencias.
# Requiere Flutter instalado y en el PATH (flutter doctor).
set -euo pipefail
cd "$(dirname "$0")"
flutter create --platforms=android --org mx.moviqro --project-name moviqro -a kotlin .
flutter pub get
echo
echo "Listo. Edite android/app/src/main/AndroidManifest.xml y ponga su clave de Google Maps."
echo "Luego: flutter run --dart-define-from-file=config/app.json"
