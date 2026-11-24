#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Folio · Script de desarrollo y ejecución (plantilla de la skill
# nuevo-proyecto, Laboratory/skills/nuevo-proyecto/plantillas/run-flutter.sh)
#
# Uso:
#   ./run.sh                 Linux si existe la plataforma; si no, Android
#   ./run.sh linux           Ejecuta en Linux desktop
#   ./run.sh android         Ejecuta en el Android conectado por USB (adb)
#   ./run.sh apk             Compila el APK release
#   ./run.sh install         Compila el APK release y lo instala por adb
#   ./run.sh build-linux     Compila el bundle release de Linux
#   ./run.sh test            Pruebas (flutter test)
#   ./run.sh analyze         Análisis estático (flutter analyze)
#
# Argumentos extra se pasan a flutter: ./run.sh android --release
# Si existe .env, se pasa como --dart-define-from-file=.env (no se versiona).
# ─────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# JDK: 17 o 21 del sistema, o el JBR de Android Studio.
if [ -d /usr/lib/jvm/java-17-openjdk-amd64 ]; then
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
elif [ -d /usr/lib/jvm/java-21-openjdk-amd64 ]; then
  export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
else
  export JAVA_HOME="${JAVA_HOME:-$HOME/.local/share/flatpak/app/com.google.AndroidStudio/current/active/files/extra/jbr}"
fi
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$JAVA_HOME/bin:$HOME/flutter/bin:$ANDROID_HOME/platform-tools:$PATH"

DEFINES=()
[ -f .env ] && DEFINES=(--dart-define-from-file=.env)

if [ -d linux ]; then DEFAULT=linux; else DEFAULT=android; fi
ACTION="${1:-$DEFAULT}"
[ $# -gt 0 ] && shift

android_id() {
  adb devices | awk '$2=="device"{print $1; exit}'
}

need_android() {
  ID="$(android_id || true)"
  if [ -z "$ID" ]; then
    echo "❌ No hay ningún Android conectado (adb devices está vacío)."
    echo "   Conecta el celular por USB con la depuración USB activada."
    exit 1
  fi
  echo "📱 Android: $ID"
}

case "$ACTION" in
  linux)
    [ -d linux ] || { echo "❌ El proyecto no tiene plataforma Linux (flutter create --platforms linux .)"; exit 1; }
    echo "▶ Ejecutando en Linux…"
    flutter run -d linux "${DEFINES[@]}" "$@"
    ;;
  android)
    need_android
    echo "▶ Ejecutando en Android…"
    flutter run -d "$ID" "${DEFINES[@]}" "$@"
    ;;
  apk)
    echo "▶ Compilando APK release…"
    flutter build apk --release "${DEFINES[@]}" "$@"
    ls -lh build/app/outputs/flutter-apk/app-release.apk
    ;;
  install)
    need_android
    # Solo arm64 (los celulares actuales): APK más liviano y compilación más rápida.
    flutter build apk --release --target-platform android-arm64 "${DEFINES[@]}" "$@"
    adb -s "$ID" install -r build/app/outputs/flutter-apk/app-release.apk
    echo "✔ Instalado en $ID"
    ;;
  build-linux)
    flutter build linux --release "${DEFINES[@]}" "$@"
    echo "✔ Bundle en build/linux/x64/release/bundle/"
    ;;
  test)
    flutter test "$@"
    ;;
  analyze)
    flutter analyze "$@"
    ;;
  -h|--help|help)
    sed -n '2,20p' "$0"
    ;;
  *)
    echo "▶ Ejecutando en el dispositivo «$ACTION»…"
    flutter run -d "$ACTION" "${DEFINES[@]}" "$@"
    ;;
esac
