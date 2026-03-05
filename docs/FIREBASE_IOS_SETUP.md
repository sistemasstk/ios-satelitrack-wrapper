# Firebase + APNs en iOS (Flutter)

## 1) Requisitos

- Cuenta Apple Developer activa.
- Proyecto Firebase creado.
- App iOS registrada en Firebase con bundle id `novadev.Satelital`.

## 2) APNs en Apple Developer

1. Crear APNs Auth Key (`.p8`) en Apple Developer.
2. Guardar `Key ID`, `Team ID` y la clave `.p8`.
3. En Firebase Console > Project settings > Cloud Messaging:
   - subir `.p8`
   - configurar `Key ID` y `Team ID`.

## 3) Configurar Flutter iOS

1. Generar proyecto iOS si aún no existe:
   - `./scripts/bootstrap_ios_project.sh`
2. Descargar `GoogleService-Info.plist` de Firebase.
3. Copiarlo a `ios/Runner/GoogleService-Info.plist`.
4. En `ios/Runner.xcworkspace` habilitar en target `Runner`:
   - `Push Notifications`
   - `Background Modes` > `Remote notifications`

## 4) Tokens en arranque

La app Flutter solicita permisos y obtiene:
- token APNs (`provider=apns`) cuando está disponible
- token FCM (`provider=fcm`) como respaldo

Se abre `https://app2025.satelitrack.com.co/app2025/` con:
- `tokenId`
- `tokenProvider`
- `platform=ios`
- `version=2025`

## 5) Pruebas

1. Instalar en iPhone físico (APNs no funciona en simulador para recepción real).
2. Verificar en login que backend guarde token y provider.
3. Probar envío por backend:
   - APNs directo para tokens APNs
   - FCM para tokens FCM
