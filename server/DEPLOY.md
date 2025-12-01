# 🚀 Steel Titans - Deployment Guide

## Resumen de Infraestructura

| Componente | Ubicación | Puerto |
|------------|-----------|--------|
| nginx (proxy) | DigitalOcean | 80, 443 |
| FastAPI | DigitalOcean | 8080 |
| PostgreSQL | DigitalOcean | 5432 |
| Dominio | steeltitans.damsanti.app | - |
| SSL | Let's Encrypt | auto-renovación |

## Despliegue de la API

### 1. Subir archivos al servidor

```bash
# Desde Windows (PowerShell)
scp -i "G:\Battletech\key" -r server/api/* root@159.65.94.179:/root/steeltitans-api/
```

### 2. Instalar dependencias nuevas

```bash
# SSH al servidor
ssh -i "G:\Battletech\key" root@159.65.94.179

# En el servidor
cd /root/steeltitans-api
pip install -r requirements.txt
```

### 3. Reiniciar el servicio

```bash
systemctl restart steeltitans-api
systemctl status steeltitans-api
```

### 4. Verificar funcionamiento

```bash
# Health check básico
curl https://steeltitans.damsanti.app/health

# Health check detallado
curl https://steeltitans.damsanti.app/health/detailed

# Verificar rate limiting headers
curl -I https://steeltitans.damsanti.app/auth/login
```

## Configuración de Backups

### 1. Copiar scripts de backup

```bash
scp -i "G:\Battletech\key" server/scripts/*.sh root@159.65.94.179:/root/scripts/
ssh -i "G:\Battletech\key" root@159.65.94.179 "chmod +x /root/scripts/*.sh"
```

### 2. Configurar cron para backups automáticos

```bash
# En el servidor
crontab -e

# Añadir esta línea (backup cada 6 horas)
0 */6 * * * /root/scripts/backup_db.sh >> /var/log/steeltitans-backup.log 2>&1
```

### 3. Ejecutar backup manual

```bash
/root/scripts/backup_db.sh
```

### 4. Restaurar desde backup

```bash
# Ver backups disponibles
ls -la /root/backups/postgresql/

# Restaurar (CUIDADO: sobrescribe todos los datos)
/root/scripts/restore_db.sh /root/backups/postgresql/steeltitans_YYYYMMDD_HHMMSS.sql.gz
```

## Rate Limiting

La API tiene los siguientes límites:

| Endpoint | Límite |
|----------|--------|
| `/auth/login` | 5/minuto |
| `/auth/register` | 3/minuto |
| `/auth/guest` | 10/minuto |
| `/auth/refresh` | 20/minuto |
| General | 60/minuto |

Los headers de respuesta incluyen:
- `X-RateLimit-Limit`: Límite máximo
- `X-RateLimit-Remaining`: Requests restantes
- `Retry-After`: Segundos hasta reset (cuando se excede)

## Health Checks

| Endpoint | Uso |
|----------|-----|
| `/health` | Load balancer (simple) |
| `/health/detailed` | Monitoreo con DB status |
| `/health/live` | Kubernetes liveness |
| `/health/ready` | Kubernetes readiness |
| `/health/metrics` | Métricas básicas |

## Anti-Cheat (Servidor de Juego)

El servidor de Godot incluye:
- `ServerActionValidator`: Valida todas las acciones
- `SuspiciousActivityDetector`: Detecta comportamiento anómalo

Niveles de sospecha:
- NONE (0-19): Normal
- LOW (20-39): Solo logging
- MEDIUM (40-69): Rate limit en acciones
- HIGH (70-99): Requiere verificación
- CRITICAL (100+): Ban temporal (5 min)

## Troubleshooting

### Ver logs de la API

```bash
journalctl -u steeltitans-api -f
```

### Ver logs de nginx

```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Verificar certificado SSL

```bash
certbot certificates
```

### Renovar certificado manualmente

```bash
certbot renew
systemctl reload nginx
```

### Verificar conexión a PostgreSQL

```bash
psql -U steeltitans_api -h localhost steeltitans -c "SELECT 1"
```
