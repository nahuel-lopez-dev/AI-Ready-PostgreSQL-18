# Cheatsheet PostgreSQL PSQL

Guía rápida de comandos, metacomandos de `psql` y consultas útiles para trabajar desde la terminal interactiva.

---

Este entorno utiliza Docker - ver `practica-entorno/README.md` para
levantar/parar el contenedor y conectar.

## 1. Conexión y Sesión

| Comando | Descripción |
| :--- | :--- |
| `psql -U <usuario> -d <base_datos>` | Inicia sesión en `psql` con un usuario y base de datos específicos. |
| `psql -h <host> -p <puerto> -U <usuario> -d <base>` | Conecta a un servidor PostgreSQL remoto. |
| `\c <nombre_base>` | Elige / cambia a la base de datos especificada. |
| `\c <nombre_base> <usuario>` | Cambia a la base de datos autenticándose con otro usuario. |
| `\q` | Sale de la terminal interactiva `psql`. |
| `\conninfo` | Muestra información de la conexión actual (usuario, host, puerto, base de datos). |

---

## 2. Exploración e Inspección de Objetos

| Comando | Descripción |
| :--- | :--- |
| `\l` o `\list` | Lista todas las bases de datos en el servidor. |
| `\l+` | Lista bases de datos con tamaño en disco, espacio de tablas y descripción. |
| `\dt` | Lista las tablas del esquema actual. |
| `\dt+` | Lista tablas con su tamaño en disco y descripción. |
| `\dt *.*` | Muestra todas las tablas de todos los esquemas. |
| `\d <nombre_tabla>` | Describe la estructura (columnas, tipos, claves, índices) de una tabla. |
| `\d+ <nombre_tabla>` | Describe la estructura extendida de una tabla (incluye comentarios y almacenamiento). |
| `\dv` | Lista todas las vistas (`views`) del esquema actual. |
| `\di` | Lista todos los índices del esquema actual. |
| `\ds` | Lista todas las secuencias (`sequences`). |
| `\dn` | Lista todos los esquemas (`schemas`). |
| `\du` o `\dg` | Lista todos los usuarios/roles y sus permisos. |
| `\df` | Lista todas las funciones y procedimientos almacenados. |

---

## 3. Comandos Utilitarios de PSQL

| Comando | Descripción |
| :--- | :--- |
| `\i <ruta/archivo.sql>` | Ejecuta un script SQL desde un archivo externo. |
| `\o <ruta/archivo.txt>` | Redirige el resultado de las siguientes consultas a un archivo. |
| `\o` | Cancela la redirección y vuelve a mostrar los resultados en la terminal. |
| `\e` | Abre el editor por defecto (`vim`/`nano`) para escribir una consulta SQL larga. |
| `\ef <función>` | Abre el editor para modificar una función almacenada existente. |
| `\x` | Activa/desactiva el modo de visualización expandida (ideal para filas muy anchas). |
| `\timing` | Muestra u oculta el tiempo que tarda cada consulta en ejecutarse. |
| `\s [archivo]` | Muestra el historial de comandos o lo guarda en el archivo indicado. |
| `\?` | Muestra la lista completa de comandos propios de `psql` (`\`). |
| `\h [comando_SQL]` | Muestra la sintaxis y ayuda sobre un comando SQL (ej: `\h SELECT`). |

---

## 4. Ejemplos de Flujos y Consultas Frecuentes

### Exploración e Inspección de `central_analytics`

* **Listar las bases de datos:**
  ```sql
  \l
  ```

* **Elegir base `central_analytics`:**
  ```sql
  \c central_analytics
  ```

* **Ver las tablas:**
  ```sql
  \dt
  ```

* **Contar el total de tablas en esquema `public`:**
  ```sql
  SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';
  ```

* **Contar registros de tablas principales:**
  ```sql
  SELECT count(*) FROM customer.customer;
  SELECT count(*) FROM sales.sales_transaction;
  SELECT count(*) FROM sales.sales_transaction_line;
  ```

---

### Inspección de `ecommerce_reference_data`

* **Cambiar a `ecommerce_reference_data`:**
  ```sql
  \c ecommerce_reference_data
  ```

* **Ver las tablas de `ecommerce_reference_data`:**
  ```sql
  \dt
  ```

* **Contar los registros de la tabla `product` con esquema `product`:**
  ```sql
  SELECT count(*) FROM product.product;
  ```

---

### Inspección de `west_ecommerce_data`

* **Cambiar a `west_ecommerce_data`:**
  ```sql
  \c west_ecommerce_data
  ```

* **Ver las tablas de `west_ecommerce_data`:**
  ```sql
  \dt
  ```

* **Contar los registros de la tabla `customer` con esquema `customer`:**
  ```sql
  SELECT count(*) FROM customer.customer;
  ```

---

## 5. Administración de Base de Datos y Estructuras (SQL)

```sql
-- Crear y eliminar bases de datos
CREATE DATABASE nombre_base;
DROP DATABASE nombre_base;

-- Crear y eliminar esquemas
CREATE SCHEMA nombre_esquema;
DROP SCHEMA nombre_esquema CASCADE;

-- Crear tabla básica
CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Modificar tabla
ALTER TABLE usuarios ADD COLUMN activo BOOLEAN DEFAULT true;
ALTER TABLE usuarios DROP COLUMN activo;
ALTER TABLE usuarios RENAME TO clientes;

-- Eliminar tabla
DROP TABLE IF EXISTS usuarios CASCADE;
```

---

## 6. Respaldos y Restauración (Terminal del Sistema)

> **Nota:** Estos comandos se ejecutan en la terminal del sistema operativo (`bash`/`zsh`/`cmd`), no dentro de `psql`.

```bash
# Exportar/Respaldar una base de datos a un archivo .sql
pg_dump -U <usuario> -d <nombre_base> > respaldo.sql

# Exportar en formato binario/comprimido (recomendado)
pg_dump -F c -U <usuario> -d <nombre_base> -f respaldo.dump

# Exportar solo la estructura (sin datos)
pg_dump -s -U <usuario> -d <nombre_base> > estructura.sql

# Exportar solo los datos (sin estructura)
pg_dump -a -U <usuario> -d <nombre_base> > datos.sql

# Respaldar TODAS las bases de datos
pg_dumpall -U <usuario> > respaldo_completo.sql

# Restaurar desde un archivo plano .sql
psql -U <usuario> -d <nombre_base> -f respaldo.sql

# Restaurar desde un archivo comprimido .dump
pg_restore -U <usuario> -d <nombre_base> -v respaldo.dump
```

---

## 7. Monitoreo y Mantenimiento

```sql
-- Ver procesos y consultas en ejecución activa
SELECT pid, usename, pg_blocking_pids(pid) AS bloqueado_por, query, state 
FROM pg_stat_activity 
WHERE state != 'idle';

-- Cancelar una consulta en curso (sin cerrar la conexión)
SELECT pg_cancel_backend(<pid>);

-- Terminar/Forzar el cierre de una conexión colgada
SELECT pg_terminate_backend(<pid>);

-- Optimización y limpieza manual de una tabla
VACUUM ANALYZE nombre_tabla;
```