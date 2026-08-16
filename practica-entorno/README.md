# Entorno de práctica – AI-Ready PostgreSQL 18

Copia local del `docker-compose.yml` original (`../docker/docker-compose.yml`),
modificada para no chocar con otras instancias de Postgres en esta máquina.
Vive separada del código del libro para poder hacer `git pull` del upstream
de Packt sin conflictos.

## Diferencias vs el compose original

- Puerto host: **5433** (no 5432, porque ya corre otra instancia Postgres 18 local vía pgAdmin)
- Password vía Docker secret en `secrets/pg_password.txt` (gitignored, nunca se commitea)

## Uso normal

1. Levantar el contenedor:
   ```
   docker compose up -d
   ```
2. Conectar:
   ```
   psql -h 127.0.0.1 -p 5433 -U postgres -d postgres
   ```
   Password: `postgres`
3. Verificar extensiones cargadas:
   ```sql
   SELECT extname, extversion FROM pg_extension;
   ```
4. Al terminar de usar la db, parar el contenedor (libera RAM, tengo 8GB):
   ```
   docker compose stop
   ```
   (esto NO borra los datos; `docker compose start` los retoma tal cual quedaron)

## Primera vez / si no existe el secret

Si falta `secrets/pg_password.txt`, el contenedor no arranca:
```
mkdir -p secrets
echo -n "postgres" > secrets/pg_password.txt
docker compose up -d
```

## Troubleshooting

**Puerto ocupado por otra instancia:**
```
nano docker-compose.yml
```
Revisar y ajustar:
```
ports:
  - "5433:5432"
```
Verificar que quedó guardado:
```
cat docker-compose.yml | grep -A1 ports
```
Recrear el contenedor con la config nueva:
```
docker compose down
docker compose up -d
docker ps
```
Confirmar el mapeo de puerto en `docker ps` (debe decir `0.0.0.0:5433->5432/tcp`)
antes de reintentar la conexión con psql.

**Docker Desktop no está corriendo (error de pipe en Windows):**
Abrir Docker Desktop manualmente y esperar a que el ícono deje de animarse
antes de reintentar `docker compose up -d`.

**Borrar todo y empezar de cero (¡pierde los datos!):**
```
docker compose down -v
```

## Estado del setup

- [x] Imagen levantada, extensiones base OK (vector, pgaudit, plpython3u, pg_squeeze, pg_background, plpgsql_check, pg_stat_statements, pg_ivm)
- [ ] API key de OpenAI cargada (`ALTER SYSTEM SET api.openai_api_key = '...'`)
- [ ] `master_setup.sql` corrido desde `../psql_scripts/`