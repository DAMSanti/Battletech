# Dockerfile para servidor dedicado BattleTech
# Usa Godot 4.5 headless para ejecutar el servidor

FROM ubuntu:22.04

# Instalar dependencias
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libx11-6 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    libgl1 \
    libglu1-mesa \
    libasound2 \
    libpulse0 \
    libudev1 \
    libdbus-1-3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Variables de entorno
ENV GODOT_VERSION=4.3
ENV GODOT_PLATFORM=linux.x86_64

# Descargar Godot headless
# Nota: Ajustar versión según la disponible
WORKDIR /opt
RUN wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_${GODOT_PLATFORM}.zip \
    && unzip Godot_v${GODOT_VERSION}-stable_${GODOT_PLATFORM}.zip \
    && mv Godot_v${GODOT_VERSION}-stable_${GODOT_PLATFORM} /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm Godot_v${GODOT_VERSION}-stable_${GODOT_PLATFORM}.zip

# Crear directorio para el servidor
WORKDIR /app

# Copiar archivos del proyecto exportado
# El .pck debe generarse con: godot --headless --export-pack "Linux/X11" server.pck
COPY exports/BattleTech_Server.pck /app/
COPY exports/BattleTech_Server.x86_64 /app/

# Puerto del servidor
EXPOSE 7777/udp

# Variables de entorno configurables
ENV SERVER_PORT=7777
ENV MAX_PLAYERS=32

# Comando de inicio
# Usa --headless para ejecutar sin ventana gráfica
CMD ["/app/BattleTech_Server.x86_64", "--headless", "--", "--port=${SERVER_PORT}"]
