# Satelitrack Native App (Flutter)

App nativa para iOS/Android conectada al backend actual de `app2025` sin `WebView`.

## Implementado

- Login nativo (`Principal` / `Tercero`).
- Integracion de token push (APNs/FCM) en login.
- Sesion PHP persistente con cookie (`PHPSESSID`) en `SharedPreferences`.
- Dashboard nativo con:
  - Conteo de vehiculos (`idfn=1`).
  - Ultimas posiciones (`idfn=2`).
  - Colores por frescura de reporte.
  - Refresco manual y `pull-to-refresh`.
- Mapa nativo de flota (`flutter_map`) con buscador de placa y opcion de seguimiento.
- Detalle nativo por vehiculo con mapa y metricas.
- Alarmas:
  - Pendientes (`idfn=6`).
  - Atender alarma (`idfn=7`).
  - Historial por vehiculo/rango (`idfn=5`).
- Comandos remotos:
  - Estandar (`idfn=8`).
  - Video/personalizado (`idfn=14`).
  - Consulta de respuesta (`idfn=12`).
- Geocercas:
  - Listar y visualizar (`idfn=10`).
  - Crear por puntos en mapa (`idfn=9`).
  - Asociar a vehiculo con horario (`idfn=11`).
- Evidencias multimedia:
  - Historial fotos/videos por vehiculo y rango (`idfn=15`).
- Panico operativo:
  - Envio de evento de panico por placa (`idfn=16`).
- Cierre de sesion (`logout.php`).

## Backend que consume

- `POST /login.php`
- `POST /includes/funciones.php` con payload JSON (`idfn`)
- `GET /logout.php`

Base URL configurable por `--dart-define`.

## Variables de compilacion

- `APP_BASE_URL` (default: `https://app.satelitrack.com.co/`)
- `APP_VERSION` (default: `2025`)
- `TOKEN_PARAM_NAME` (default: `tokenId`)
- `APP_MEDIA_BASE_URL` (default: `https://intranet.satelitrack.com.co/platform/`)

Ejemplo:

```bash
flutter run \
  --dart-define=APP_BASE_URL=https://app.satelitrack.com.co/ \
  --dart-define=APP_VERSION=2025 \
  --dart-define=APP_MEDIA_BASE_URL=https://intranet.satelitrack.com.co/platform/
```

## Estructura principal

- `lib/main.dart`: bootstrap y navegacion por estado de sesion.
- `lib/src/app_controller.dart`: estado global de auth/dashboard.
- `lib/src/services/backend_client.dart`: cliente HTTP + cookie de sesion.
- `lib/src/services/notification_token_service.dart`: token APNs/FCM.
- `lib/src/ui/login_page.dart`: pantalla login nativa.
- `lib/src/ui/dashboard_page.dart`: dashboard + accesos a modulos.
- `lib/src/ui/map_page.dart`: mapa de flota.
- `lib/src/ui/vehicle_detail_page.dart`: detalle de vehiculo.
- `lib/src/ui/alarms_page.dart`: alarmas pendientes/historicas.
- `lib/src/ui/commands_page.dart`: envio de comandos y polling de respuesta.
- `lib/src/ui/geofences_page.dart`: geocercas (crear/listar/asociar).
- `lib/src/ui/media_evidence_page.dart`: fotos/videos historicos.
- `lib/src/ui/panic_page.dart`: envio de panico.

## Siguiente fase sugerida

- Historial de desplazamientos y encendidos (`idfn=4/13`).
- Geocercas avanzadas (editar/eliminar geocercos y multi-poligono).
