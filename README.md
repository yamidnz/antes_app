# ANTES — App de alerta sísmica (Flutter)

Prototipo funcional en Flutter con: inicio, mapa de zonas seguras (OpenStreetMap + Overpass),
guía de acción, actividad sísmica reciente (feed público del USGS) y **botón SOS** que envía
tu ubicación exacta a tus contactos de confianza y, opcionalmente, a tu red comunitaria.

## Cómo correrla

Necesitas tener el SDK de Flutter instalado (no viene incluido en este ZIP porque el entorno
donde se generó este código no tiene acceso a internet para descargarlo).

```bash
# 1. Instala Flutter si no lo tienes: https://docs.flutter.dev/get-started/install

# 2. Dentro de esta carpeta, genera los proyectos nativos de Android/iOS:
flutter create .

# 3. Instala las dependencias:
flutter pub get

# 4. Corre en un emulador o dispositivo conectado:
flutter run
```

`flutter create .` generará las carpetas `android/` e `ios/` que faltan (se omiten aquí porque
son auto-generadas y specíficas de tu máquina/SDK). Todo el código de la app vive en `lib/`.

## Permisos que debes agregar

**Android** (`android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
*(`SEND_SMS` no es estrictamente necesaria porque el SOS abre la app nativa de Mensajes en vez
de enviar en segundo plano — pero déjala si luego decides enviar sin abrir la app.)*

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ANTES necesita tu ubicación para mostrarte zonas seguras cercanas y enviar tus coordenadas exactas si activas un SOS.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ANTES necesita tu ubicación para las alertas de zonas seguras y el botón SOS.</string>
```

## Sobre el botón SOS (léelo antes de tocar `sos_service.dart`)

- **Por defecto**, el SOS solo envía SMS a contactos de confianza que tú mismo configuras
  desde la app. Los números **se guardan solo en tu teléfono**, nunca en un servidor.
- La opción de avisar a la "red comunitaria" (otros usuarios de ANTES cerca de ti) es
  **opcional y apagada por defecto**. El usuario debe activarla explícitamente.
- El endpoint de red comunitaria (`https://api.antesapp.co/v1/sos`) es un **stub** — no existe
  todavía. Cuando construyas el backend real (ver `ANTES-especificacion-tecnica.md`), agrégale
  autenticación por token y limita la difusión por radio geográfico, para evitar spam y
  exponer la identidad de quien pide ayuda.
- Hay un límite de un SOS por minuto para evitar envíos duplicados por doble toque accidental.
- Activar el SOS requiere mantener presionado el botón 3 segundos, para evitar disparos
  accidentales en el bolsillo.

## Próximos pasos sugeridos

1. Añadir notificaciones push (Firebase Cloud Messaging) para alertas oficiales del SGC/USGS.
2. Construir el backend real de red comunitaria con autenticación y límites de radio.
3. Explorar recolección de datos de acelerómetro en segundo plano (fase 2 de la
   especificación técnica) para detección temprana tipo MyShake/SASMEX.
