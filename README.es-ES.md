

# Babble

Una herramienta de entrada de voz para macOS que utiliza MLX Whisper para la transcripción de voz a texto local y los Modelos base de Apple para el refinamiento de texto en el dispositivo.

## Requisitos

- macOS 26+ (Tahoe)
- Mac con chip Apple Silicon

## Instalación

### Desde GitHub Releases

1. Descarga `Babble-vX.X.X.zip` desde [Releases](https://github.com/louzhixian/babble/releases)
2. Descomprime y mueve `Babble.app` a `/Applications`
3. **Seguridad al primer lanzamiento**:

   Dado que la aplicación no está notariada, macOS la bloqueará en el primer lanzamiento:

   - Haz doble clic en `Babble.app` - verás un cuadro de diálogo de advertencia
   - Abre **Ajustes del sistema > Privacidad y seguridad**
   - Desplázate hasta la sección **Seguridad**
   - Haz clic en **"Abrir de todas formas"** junto al mensaje de Babble
   - Haz clic en **"Abrir"** en el cuadro de diálogo de confirmación

4. Concede los permisos cuando se te solicite:
   - **Micrófono**: Requerido para grabar voz
   - **Accesibilidad**: Requerido para pegar texto (simulación de Cmd+V)

### Solución de problemas de permisos

Si los permisos de accesibilidad muestran la ruta incorrecta de la aplicación:

```bash
# Restablecer permisos de accesibilidad para Babble
tccutil reset Accessibility com.babble.app

# Restablecer permisos del micrófono para Babble
tccutil reset Microphone com.babble.app
```

Luego, vuelve a abrir la aplicación y concede los permisos nuevamente.

## Uso

1. Presiona **Opción+Espacio** para iniciar/detener la grabación (o mantén presionado para usar push-to-talk)
2. Habla a tu micrófono
3. El texto será transcrito y pegado en la aplicación activa

## Compilación desde el código fuente

### Aplicación Swift

```bash
cd BabbleApp
swift build -c release
./build-app.sh
```

### Servicio Whisper

El servicio whisper-service se descarga automáticamente en el primer lanzamiento. Para desarrollo:

```bash
cd whisper-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python server.py
```

## Licencia

MIT
