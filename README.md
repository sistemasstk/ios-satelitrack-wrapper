# Satelitrack iOS Wrapper (Flutter)

Wrapper Flutter para iOS que abre `https://app2025.satelitrack.com.co/app2025/` en `WebView` y envía token móvil por querystring para mantener compatibilidad con el backend actual.

## Flujo de arranque

1. Solicita permisos de notificaciones iOS.
2. Obtiene token APNs y token FCM (si existe).
3. Prioriza token en orden: `apns` > `fcm` > `vacio`.
4. Abre:
   - `https://app2025.satelitrack.com.co/app2025/?tokenId=<TOKEN>&version=2025&tokenProvider=<apns|fcm|none>&platform=ios`

## Variables de compilación

- `APP_BASE_URL` (default: `https://app2025.satelitrack.com.co/app2025/`)
- `APP_VERSION` (default: `2025`)
- `TOKEN_PARAM_NAME` (default: `tokenId`)

Ejemplo:

```bash
flutter run \
  --dart-define=APP_BASE_URL=https://app2025.satelitrack.com.co/app2025/ \
  --dart-define=APP_VERSION=2025
```

## Requisitos iOS

- Apple Developer activo.
- Capacidades en Xcode: `Push Notifications` y `Background Modes > Remote notifications`.
- Firebase configurado para obtener `getAPNSToken()` y `getToken()`.
- Generar carpeta nativa iOS (si no existe) con:

```bash
./scripts/bootstrap_ios_project.sh
```

## Codemagic

`codemagic.yaml` incluido para compilar IPA firmada en ramas `main` y `develop`.

## Nota

La carpeta `legacy-capacitor/` conserva la implementación anterior para rollback controlado.
