# Guía rápida: Instalar Android Export Templates

## El Problema
No tienes instalados los Android Export Templates de Godot 4.5.
Sin estos templates, el APK que exportas está corrupto/inválido.

## La Solución

### Paso 1: Abrir Godot Engine
1. Abre tu proyecto Battletech en Godot

### Paso 2: Ir al gestor de templates
1. En el menú superior, haz clic en: **Editor**
2. Selecciona: **Manage Export Templates**

### Paso 3: Descargar templates
1. Se abrirá una ventana
2. Haz clic en el botón: **Download and Install**
3. Espera a que descargue (puede tardar 2-5 minutos, son ~400MB)
4. Verás una barra de progreso
5. Cuando termine, cierra la ventana

### Paso 4: Exportar el APK correctamente
1. Ve a: **Project → Export**
2. Selecciona el preset: **Battletech**
3. Haz clic en: **Export Project** (NO "Export PCK/ZIP")
4. Guarda como: **BattleTech.apk**
5. **IMPORTANTE: Marca la casilla "Export With Debug"** ✓
6. Haz clic en **Save**
7. Espera 1-2 minutos a que termine

### Paso 5: Verificar el APK
El archivo BattleTech.apk debería tener al menos 30-40 MB.
Si es más pequeño, algo salió mal.

### Paso 6: Instalar en el móvil
Método más fácil:
1. Copia BattleTech.apk a tu móvil (cable USB, Drive, correo, etc.)
2. En el móvil, abre el archivo .apk
3. Permite "Instalar desde fuentes desconocidas" si te lo pide
4. Toca "Instalar"
5. ¡Listo!

## Si sigue sin funcionar

Posibles causas adicionales:
- Tu móvil es muy antiguo (necesita Android 5.0 o superior)
- No hay suficiente espacio en el móvil
- La instalación anterior está corrupta (desinstala primero)

Para desinstalar versión anterior:
- Mantén presionado el icono de Battletech
- Selecciona "Desinstalar"
- Luego vuelve a instalar el nuevo APK
