# iOS Wrapper para `app2025`

Base de app iOS usando Capacitor para abrir `app2025/index.php` y pasar `tokenId` de Firebase Cloud Messaging.

## Estructura
- `www/`: bootstrap local que solicita permisos push, obtiene token FCM y redirige a `index.php`.
- `capacitor.config.ts`: configuración de app y plugins.
- `docs/FIREBASE_IOS_SETUP.md`: pasos de Firebase/APNs/Xcode.

## Configuración rápida
1. Edita `www/config.js`:
   - `BASE_URL`: URL real de tu sistema (`https://.../app2025/index.php`).
2. Ajusta `appId` y `appName` en `capacitor.config.ts` si lo necesitas.

## Comandos (ejecutar en Mac)
```bash
cd mobile/ios-satelitrack-wrapper
npm install
npm run add:ios
npm run sync
npm run open:ios
```

## Qué hace el arranque
1. Pide permisos de notificación en iOS.
2. Registra push nativo.
3. Obtiene token FCM con `@capacitor-firebase/messaging`.
4. Abre:
   - `https://TU-DOMINIO.com/app2025/index.php?tokenId=<TOKEN>&version=2025`

Si no se puede obtener token, abre con `tokenId=vacio`.

## Nota importante
- La compilación final sí requiere Mac + Xcode.
- Push real en iOS requiere dispositivo físico (no solo simulador).
