# Codemagic Setup (iOS Signed)

## 1. Connect repository

- Conectar el repositorio GitHub de `mobile/ios-satelitrack-wrapper`.
- Activar lectura de `codemagic.yaml`.

## 2. Variables requeridas

- `APP_BASE_URL`: URL final de `app2025/index.php`.

## 3. iOS signing

- Subir certificado de distribución iOS.
- Subir provisioning profile para `com.satelitrack.app2025`.
- Asignar a workflows:
  - `ios_signed_main` -> App Store
  - `ios_validate_develop` -> Ad Hoc

## 4. Firebase/APNs en runner

- Agregar `GoogleService-Info.plist` al proyecto iOS Flutter (`ios/Runner/`).
- Configurar APNs key en Firebase para compatibilidad FCM.
- Configurar APNs direct credentials en backend vía variables de entorno (no en Codemagic).
