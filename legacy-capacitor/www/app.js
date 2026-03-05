(function () {
  const state = document.getElementById('state');

  function setState(message) {
    if (state) state.textContent = message;
    console.log('[BOOT]', message);
  }

  function buildAppUrl(token) {
    const config = window.APP_CONFIG || {};
    const base = config.BASE_URL || 'https://TU-DOMINIO.com/app2025/index.php';
    const version = config.APP_VERSION || '2025';
    const tokenParamName = config.TOKEN_PARAM_NAME || 'tokenId';

    const url = new URL(base);
    url.searchParams.set(tokenParamName, token || 'vacio');
    url.searchParams.set('version', version);

    return url.toString();
  }

  async function tryGetFcmToken() {
    const hasCapacitor = !!window.Capacitor;
    if (!hasCapacitor) {
      setState('Modo navegador: no se detecta Capacitor.');
      return 'vacio';
    }

    const platform = window.Capacitor.getPlatform?.() || 'web';
    if (platform !== 'ios') {
      setState('Plataforma no iOS detectada: ' + platform);
      return 'vacio';
    }

    const plugins = window.Capacitor.Plugins || {};
    const PushNotifications = plugins.PushNotifications;
    const FirebaseMessaging = plugins.FirebaseMessaging;

    if (!PushNotifications || !FirebaseMessaging) {
      setState('Faltan plugins de Push/Firebase en el runtime.');
      return 'vacio';
    }

    setState('Solicitando permisos de notificación...');

    const permResult = await PushNotifications.requestPermissions();
    if (permResult.receive !== 'granted') {
      setState('Permiso de notificaciones denegado.');
      return 'vacio';
    }

    await PushNotifications.register();

    setState('Obteniendo token FCM...');
    const tokenResult = await FirebaseMessaging.getToken();
    const token = tokenResult && tokenResult.token ? tokenResult.token : 'vacio';

    if (token === 'vacio') {
      setState('No fue posible obtener token FCM.');
    } else {
      setState('Token FCM obtenido. Abriendo app...');
    }

    PushNotifications.addListener('pushNotificationActionPerformed', function (notification) {
      const data = (notification && notification.notification && notification.notification.data) || {};
      const deepLink = data && data.deep_link;
      if (typeof deepLink === 'string' && deepLink.trim()) {
        window.location.href = deepLink;
      }
    });

    return token;
  }

  async function bootstrap() {
    try {
      const token = await tryGetFcmToken();
      const targetUrl = buildAppUrl(token);
      setState('Redirigiendo...');
      window.location.replace(targetUrl);
    } catch (error) {
      console.error(error);
      setState('Error en arranque. Continuando sin token...');
      window.location.replace(buildAppUrl('vacio'));
    }
  }

  bootstrap();
})();
