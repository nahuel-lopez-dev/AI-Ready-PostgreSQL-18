# Entorno de práctica – AI-Ready PostgreSQL 18

Copia local del `docker-compose.yml` original (`../docker/docker-compose.yml`),
modificada para no chocar con otras instancias de Postgres en esta máquina.
Vive separada del código del libro para poder hacer `git pull` del upstream
de Packt sin conflictos.

## Diferencias vs el compose original

- Puerto host: **5433** (no 5432, porque ya corre otra instancia Postgres 18 local vía pgAdmin)
- Password vía Docker secret en `secrets/pg_password.txt` (gitignored, nunca se commitea)

## Uso normal

1. Levantar el contenedor (si ya existe, solo lo arranca; no reinicializa nada):
   ```
   docker compose up -d
   ```

2. Conectar:
   ```
   psql -h 127.0.0.1 -p 5433 -U postgres -d postgres
   ```
   Password: `postgres`

3. Prueba para verificar extensiones cargadas:
   
   ```sql
   SELECT extname, extversion FROM pg_extension;
   ```

4. Al terminar de usar la db, salir de PSQL y parar el contenedor (libera RAM, tengo 8GB):

   ```sql
   \q
   ```

   ```
   docker compose stop
   ```
   (esto NO borra los datos; `docker compose start` los retoma tal cual quedaron)

5. Para retomar el trabajo:

   ```
   docker compose start
   ```

## Primera vez / si no existe el secret

Si falta `secrets/pg_password.txt`, el contenedor no arranca:
```
mkdir -p secrets
echo -n "postgres" > secrets/pg_password.txt
docker compose up -d
```

## Cargar el sample de e-commerce (master_setup.sql)
 
El compose solo levanta el motor Postgres vacío. Para crear las 5 bases del
proyecto (`ecommerce_reference_data`, `east_ecommerce_data`, `west_ecommerce_data`,
`central_analytics`, `aidb`) con schema, replicación y datos de ejemplo, hay que
correr los scripts de `../psql_scripts/` **contra este contenedor** (puerto 5433).
 
Parado en `../psql_scripts/`:
 
```
psql -h 127.0.0.1 -p 5433 -U postgres -f master_setup.sql
```
 
⚠️ Antes de correrlo, ver la sección **"Bug conocido: replication slot falla en
customer_sales_replication_setup.sql"** más abajo — sin ese fix aplicado, el
script se corta antes de cargar clientes y ventas.
 
Para resetear todo y volver a correr desde cero:
```
psql -h 127.0.0.1 -p 5433 -U postgres -f master_teardown.sql
psql -h 127.0.0.1 -p 5433 -U postgres -f master_setup.sql
```
 
Con el fix aplicado, el setup completo deja aproximadamente:
- `central_analytics`: ~5.000 clientes, ~11.700 sales_transaction, ~23.400 sales_transaction_line
- `east_ecommerce_data` / `west_ecommerce_data`: clientes y ventas regionales
- 31 productos replicados en las 5 bases

## Troubleshooting
 
### Bug conocido: replication slot falla en customer_sales_replication_setup.sql
 
**Síntoma:** `master_setup.sql` corre bien hasta la replicación de clientes/ventas
y se corta con:
```
ERROR:  snapshot reference 0x... is not owned by resource owner TopTransaction
CONTEXT:  SQL statement "SELECT pg_create_logical_replication_slot(sub_slot_5, 'pgoutput')"
PL/pgSQL function inline_code_block line 7 at PERFORM
```
Como el script corta ahí, nunca llega a la carga de `customer`/`sales_transaction`,
y todas las tablas de datos quedan en 0 filas (aunque el schema se creó bien).
 
**Causa:** bug conocido de PostgreSQL — `pg_create_logical_replication_slot()`
llamada desde adentro de un bloque `DO $$ ... $$` (PL/pgSQL) puede chocar con el
resource owner de la transacción. Confirmado reproducible 3/3 veces en este
entorno (Postgres 18.3, Docker Desktop, Windows). El mismo patrón en
`product_replication_setup.sql` no falla — solo pasa en `customer_sales_replication_setup.sql`.
 
**Fix:** en `../psql_scripts/replication/customer_sales_replication_setup.sql`,
reemplazar los dos bloques `DO $$ ... PERFORM pg_create_logical_replication_slot(...) ... END$$;`
(uno para `sub_slot_5`, otro para `sub_slot_6`) por SQL plano de nivel superior:
 
```sql
-- en vez del bloque DO para slot_5:
\echo 'Connected back to publisher to manage replication slots...'
\echo '--> Creating replication slot (if not exists):' :'sub_slot_5'
SELECT pg_create_logical_replication_slot(:'sub_slot_5', 'pgoutput')
WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = :'sub_slot_5');
```
(ídem para `sub_slot_6`, cambiando el nombre de la variable)
 
Este cambio es idempotente igual que el original (el `WHERE NOT EXISTS` reemplaza
al `IF`), solo evita crear el slot desde dentro de una función PL/pgSQL. Con esto
el script corre completo sin errores.
 
*Nota: este fix se aplica directo sobre el repo del libro (`psql_scripts/`), no
sobre esta carpeta. Si se hace `git pull` del upstream y el archivo se sobreescribe,
hay que volver a aplicarlo.*
 
### Puerto ocupado por otra instancia
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
 
### Conflicto de nombre de contenedor ("name is already in use")
Pasa si quedó otro contenedor viejo usando el nombre `pg18book` (por ejemplo,
de un intento anterior en otra carpeta). Borrarlo (no toca los volúmenes):
```
docker rm pg18book
docker compose up -d
```
 
### Docker Desktop no está corriendo (error de pipe en Windows)
Abrir Docker Desktop manualmente y esperar a que el ícono deje de animarse
antes de reintentar `docker compose up -d`.
 
### Borrar todo y empezar de cero (¡pierde los datos!)
```
docker compose down -v
```
 
## Estado del setup
 
- [x] Imagen levantada, extensiones base OK (vector, pgaudit, plpython3u, pg_squeeze, pg_background, plpgsql_check, pg_stat_statements, pg_ivm)
- [x] `master_setup.sql` corrido con éxito desde `../psql_scripts/` (con fix de replication slot aplicado)
- [x] Datos verificados: ~5.000 clientes y ~23.400 líneas de venta en `central_analytics`
- [ ] API key de OpenAI cargada (`ALTER SYSTEM SET api.openai_api_key = '...'`) — pendiente para capítulos 16+