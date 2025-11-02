# Guía para Exportar Battletech a Android

## Requisitos Previos

### 1. Instalar Android Studio y SDK
1. Descarga e instala **Android Studio** desde: https://developer.android.com/studio
2. Durante la instalación, asegúrate de instalar:
   - Android SDK
   - Android SDK Platform
   - Android SDK Build-Tools
   - Android SDK Command-line Tools

### 2. Configurar Java JDK
1. Descarga e instala **Java JDK 17** (OpenJDK): https://adoptium.net/
2. Anota la ruta de instalación (ejemplo: `C:\Program Files\Eclipse Adoptium\jdk-17.0.x\`)

### 3. Descargar Android Export Templates para Godot
1. Abre Godot Engine
2. Ve a **Editor → Manage Export Templates**
3. Haz clic en **Download and Install**
4. Espera a que descargue los templates para tu versión de Godot

## Configuración en Godot

### Paso 1: Configurar Android SDK
1. En Godot, ve a **Editor → Editor Settings**
2. En la sección **Export → Android**:
   - **Android SDK Path**: `C:\Users\TuUsuario\AppData\Local\Android\Sdk`
   - **Debug Keystore**: (dejar por defecto para pruebas)

### Paso 2: Crear Preset de Exportación
1. Ve a **Project → Export**
2. Haz clic en **Add...** y selecciona **Android**
3. Configura:
   - **Name**: `Battletech Android`
   - **Runnable**: ✅ (marcado)
   - **Export With Debug**: ✅ (para pruebas iniciales)

### Paso 3: Configurar Permisos y Opciones

En la configuración de exportación Android:

#### **Options → Package**
- **Unique Name**: `com.tusitio.battletech`
- **Name**: `Battletech`
- **Signed**: ✅ (marcado)
- **Min SDK**: 21 (Android 5.0)
- **Target SDK**: 33 (Android 13)

#### **Options → Graphics**
- **Graphics API**: Vulkan (recomendado para Godot 4.x)

#### **Options → Permissions** (Marcar solo los necesarios)
- **Access Network State**: ❌ (no necesario si no hay multijugador)
- **Internet**: ❌ (no necesario por ahora)
- **Vibrate**: ✅ (opcional, para feedback táctil)

#### **Options → Screen**
- **Screen Orientation**: `Landscape` (para juego de estrategia)
- **Support Small**: ✅
- **Support Normal**: ✅
- **Support Large**: ✅
- **Support Xlarge**: ✅

## Crear el APK

### Para Pruebas (Debug)
1. En **Project → Export**
2. Selecciona el preset **Android**
3. Haz clic en **Export Project**
4. Guarda como: `Battletech-debug.apk`
5. Marca **Export With Debug** ✅

### Para Distribución (Release)
1. Primero necesitas crear un Keystore (firma digital)
2. En terminal PowerShell:
```powershell
# Navegar a la carpeta de Java
cd "C:\Program Files\Eclipse Adoptium\jdk-17.0.x\bin"

# Crear keystore
.\keytool.exe -v -genkey -keystore battletech-release.keystore -alias battletech -keyalg RSA -validity 10000
```

3. Guarda el archivo `.keystore` en un lugar seguro
4. En Godot Export → Android:
   - **Keystore → Debug**: (ruta a tu keystore)
   - **Keystore → Debug User**: `battletech`
   - **Keystore → Debug Password**: (tu contraseña)
5. Desmarca **Export With Debug**
6. Exporta como `Battletech-release.apk`

## Instalar en el Móvil

### Método 1: Conexión USB (Recomendado)
1. **Habilitar Modo Desarrollador en tu móvil**:
   - Ve a **Ajustes → Acerca del teléfono**
   - Toca 7 veces en **Número de compilación**
   - Aparecerá "Ahora eres desarrollador"

2. **Habilitar Depuración USB**:
   - Ve a **Ajustes → Sistema → Opciones de desarrollador**
   - Activa **Depuración USB**

3. **Conectar móvil al PC con cable USB**

4. **Instalar con ADB** (Android Debug Bridge):
```powershell
# Navegar a la carpeta de Android SDK
cd C:\Users\TuUsuario\AppData\Local\Android\Sdk\platform-tools

# Verificar que el dispositivo está conectado
.\adb.exe devices

# Instalar el APK
.\adb.exe install "G:\Battletech\Battletech-debug.apk"

# O para forzar reinstalación
.\adb.exe install -r "G:\Battletech\Battletech-debug.apk"
```

5. El juego aparecerá en tu lista de aplicaciones

### Método 2: Transferir APK directamente
1. Copia el archivo `Battletech-debug.apk` a tu móvil (por cable USB o Google Drive)
2. En el móvil, abre el explorador de archivos
3. Toca el archivo `.apk`
4. Permite **Instalar desde fuentes desconocidas** si te lo pide
5. Toca **Instalar**

### Método 3: Ejecutar directamente desde Godot
1. Conecta el móvil por USB con Depuración USB activada
2. En Godot, haz clic en el botón de play con el ícono de Android
3. Godot instalará y ejecutará el juego automáticamente

## Optimizaciones para Móvil

### 1. Ajustar UI para pantallas táctiles
```gdscript
# En battle_ui.gd, aumentar tamaños de botones
walk_button.size = Vector2(300, 80)  # Más grande para dedos
run_button.size = Vector2(300, 80)
jump_button.size = Vector2(300, 80)
```

### 2. Mejorar detección de toques
```gdscript
# En hex_grid.gd, aumentar área de toque
const TOUCH_TOLERANCE = 32.0  # Más tolerante en móvil

func pixel_to_hex(pixel: Vector2) -> Vector2i:
    # Código existente...
    # Agregar tolerancia para toques imprecisos
```

### 3. Optimizar rendimiento
En `project.godot`:
```ini
[rendering]
textures/vram_compression/import_etc2=true
textures/vram_compression/import_etc=true

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2  # Fullscreen
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]
ui_accept={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194309,"unicode":0,"echo":false,"script":null)
, Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"pressed":false,"double_click":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":0,"pressure":0.0,"pressed":false,"script":null)
]
}
```

### 4. Control de batería
```gdscript
# Agregar opción de ahorro de energía
var battery_saver_mode = false

func _process(delta):
    if battery_saver_mode:
        Engine.max_fps = 30  # Reducir FPS
    else:
        Engine.max_fps = 60
```

## Testing en Móvil

### Checklist de pruebas:
- [ ] El juego inicia correctamente
- [ ] Los botones son fáciles de tocar
- [ ] El juego se ve bien en horizontal
- [ ] No hay lag al mover unidades
- [ ] Los toques en hexágonos se registran correctamente
- [ ] El menú de movimiento es accesible
- [ ] El selector de armas funciona bien
- [ ] Los logs de combate son legibles
- [ ] La batería no se consume demasiado rápido
- [ ] No hay crashes después de 10 minutos de juego

## Solución de Problemas Comunes

### "App no instalada"
- Verifica que el APK no esté corrupto
- Desinstala versión anterior si existe
- Verifica que hay espacio suficiente en el móvil

### "Parsing error"
- El APK puede estar mal firmado
- Regenera el APK con configuración correcta
- Verifica que el Min SDK es compatible con tu móvil

### Controles no responden
- Aumenta el tamaño de los botones
- Verifica que InputEventScreenTouch esté habilitado
- Agrega más tolerancia en la detección de toques

### Rendimiento lento
- Reduce la resolución del juego
- Desactiva sombras y efectos visuales
- Optimiza el redibujado de hexágonos
- Usa GLES3 en lugar de Vulkan si hay problemas

### Pantalla muy pequeña
- Ajusta el scaling en project settings
- Aumenta el tamaño de fuentes
- Rediseña la UI para móvil

## Próximos Pasos

1. **Testing Alpha**: Prueba en varios dispositivos Android diferentes
2. **Optimización**: Ajusta según feedback y rendimiento
3. **Google Play Store**: 
   - Crea cuenta de desarrollador ($25 único pago)
   - Prepara assets (iconos, screenshots, descripción)
   - Sube el APK firmado
4. **iOS** (opcional): Requiere Mac y cuenta de Apple Developer ($99/año)

## Recursos Útiles

- **Documentación Godot Android**: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- **Android Studio**: https://developer.android.com/studio
- **Debugging con Logcat**: `adb logcat | findstr Godot`

---

**Fecha**: Noviembre 1, 2025
**Estado**: Listo para exportar a Android
