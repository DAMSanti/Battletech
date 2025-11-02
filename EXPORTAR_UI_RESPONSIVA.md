# PASOS PARA EXPORTAR CON UI RESPONSIVA EN PORTRAIT

## ✅ Cambios aplicados:

### 1. Configuración del proyecto (project.godot):
- ✅ Resolución base: 720x1280 (portrait/vertical)
- ✅ Orientación: Portrait (vertical) 
- ✅ Modo stretch: "viewport" con aspect "expand"
- ✅ Optimizado para móviles

### 2. UI completamente responsiva (battle_ui.gd):
- ✅ **Todos los elementos calculados con porcentajes**
- ✅ Panel info: 95% ancho, 18% altura
- ✅ Log de combate: 95% ancho, 23% altura, en la parte inferior
- ✅ Botones grandes y fáciles de tocar
- ✅ Fuentes escaladas automáticamente según tamaño de pantalla
- ✅ Paneles centrados automáticamente
- ✅ Márgenes y espaciados proporcionales

### 3. Tamaños optimizados:
- ✅ Botón "End Activation": 95% del ancho, 70px alto
- ✅ Selector de movimiento: 85% ancho, 35% alto
- ✅ Selector de armas: 85% ancho, 65% alto
- ✅ Selector físico: 85% ancho, 50% alto
- ✅ Fuentes de 16px a 26px según elemento

## 📱 Ahora exporta:

1. **CIERRA el proyecto en Godot** (si está abierto)

2. **ABRE de nuevo el proyecto** 
   (Para que cargue los nuevos cambios de project.godot)

3. **Ve a: Project → Export**

4. **Selecciona: Battletech**

5. **MARCA: Export With Debug** ✓

6. **Click: Export Project**

7. **Guarda como: BattleTech.apk** (reemplaza el anterior)

8. **Espera 1-2 minutos**

## 📲 Instala en el móvil:

En PowerShell ejecuta:
```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r ".\BattleTech.apk"
```

## ✨ Resultado esperado:

- ✅ Interfaz en vertical (portrait)
- ✅ Todo encaja en la pantalla
- ✅ Botones grandes y tocables
- ✅ Texto legible
- ✅ Se adapta automáticamente a cualquier resolución móvil
- ✅ Log de combate siempre visible en la parte inferior

## 🔍 La UI ahora es 100% responsiva:

- Usa porcentajes en lugar de píxeles fijos
- Se escala según el ancho de la pantalla
- Funciona en cualquier resolución móvil
- Los paneles están centrados automáticamente
- Las fuentes se escalan proporcionalmente

---

**¡Ahora debería verse perfecto en tu móvil!**
