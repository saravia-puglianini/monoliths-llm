# Chrome Web Store - Meet & Calendar Checker

Documento de preparación para la publicación del addon en Chrome Web Store.

## Ficha de la Tienda (Store Listing)

### Detalles del Addon
- **Nombre**: Meet & Calendar Checker
- **Descripción corta**: Verifica si Google Meet y Google Calendar están abiertos y los abre si es necesario con un solo clic.
- **Descripción detallada**:
  Esta extensión te ayuda a mantener tu flujo de trabajo organizado al verificar instantáneamente si tienes abiertas las pestañas de:
  - Google Meet (cuenta authuser=1)
  - Google Calendar (cuenta de usuario u/1)
  
  Si no están abiertas, la extensión las abrirá automáticamente en pestañas nuevas. Si ya están abiertas, podrás enfocarlas directamente desde el panel interactivo con un diseño moderno y minimalista en modo oscuro.

### Permisos y Justificación
- `tabs`: Requerido para poder consultar las pestañas abiertas, verificar sus URLs, y reenfocar las pestañas si ya están abiertas.
- `storage`: Requerido para almacenar el estado del interruptor de reapertura automática (auto-reopen) y persistirlo entre sesiones del navegador.
- `host_permissions` (`https://meet.google.com/*`, `https://calendar.google.com/*`): Requerido para leer las URLs específicas de Google Meet y Google Calendar en las pestañas y determinar su estado de apertura.

## Instrucciones para Cargar el Addon en Modo Desarrollador (Linux / Chrome)

1. Abre Google Chrome y navega a `chrome://extensions/`.
2. Activa el **Modo de desarrollador** (Developer mode) arriba a la derecha.
3. Haz clic en **Cargar descomprimida** (Load unpacked).
4. Selecciona la carpeta del proyecto: `/home/user/monoliths-llm/meet-addon`.
