# Pasos para exportar con la nueva configuración

## Cambios realizados:

1. ✅ Configuración del proyecto cambiada a:
   - Resolución base: 1920x1080 (landscape/horizontal)
   - Orientación: Landscape (horizontal)
   - Modo stretch: "viewport" con aspect "keep"

2. ✅ UI adaptada para ser responsiva:
   - Los paneles ahora se centran en pantalla
   - El log de combate se posiciona desde el fondo
   - Los botones son más grandes (mejor para móvil)
   - Las fuentes son más grandes (20-22px)

## Pasos para exportar de nuevo:

1. **Abre Godot Engine**

2. **Cierra el proyecto si está abierto y vuelve a abrirlo**
   (Para que cargue la nueva configuración de project.godot)

3. **Ve a Project → Export**

4. **Selecciona el preset "Battletech"**

5. **Marca "Export With Debug"** ✓

6. **Click en "Export Project"**

7. **Guarda como BattleTech.apk** (reemplaza el anterior)

8. **Espera a que termine** (1-2 minutos)

## Instalar en el móvil:

Ejecuta en PowerShell:
```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r ".\BattleTech.apk"
```

O copia manualmente al móvil e instala.

## Resultado esperado:

- ✅ El juego se verá en horizontal (landscape)
- ✅ Los botones serán más grandes y fáciles de tocar
- ✅ La interfaz estará centrada y no se cortará
- ✅ El texto será más legible

## Si todavía se ve mal:

Dime qué modelo de móvil tienes y qué resolución tiene, para ajustar mejor.
