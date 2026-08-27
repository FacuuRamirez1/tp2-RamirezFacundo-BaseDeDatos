---
inclusion: always
---

# Normas de seguridad del proyecto

- Nunca hardcodear contraseñas, tokens ni claves de API en el código.
  Todo secreto va en `.env`, que está en `.gitignore`.
- Validar y sanitizar todo input que venga del usuario antes de
  usarlo en una consulta SQL (usar parámetros, nunca concatenar strings).
- Las contraseñas de usuarios se guardan siempre hasheadas (bcrypt/argon2),
  nunca en texto plano.
- No exponer mensajes de error de la base de datos directamente al cliente.

## Protocolo obligatorio para modificaciones de base de datos

### 1. Flujo de IA y Modificación de Código

- **Modo Plan Primero (OpenCode):** Para cualquier cambio o generación de scripts en la base de datos, siempre se debe usar el modo `Plan` de OpenCode para describir y revisar qué se ejecutará antes de aplicar cambios a los archivos físicos (modo `Build`).
- **Revisión Humana Obligatoria (Diff):** Ningún código o script generado se aplica sin antes realizar un `git diff` e inspeccionar línea por línea su comportamiento.

### 2. Protocolo Inviolable de Base de Datos (3 Pasos)

Cualquier script que interactúe con el motor de base de datos debe cumplir sin excepción los tres pasos del protocolo:

1. **Copia de Desarrollo:**
   - Nunca trabajar sobre la base de producción o datos reales principales.
   - Toda operación de prueba o desarrollo se ejecuta sobre una base duplicada (`createdb -T plantilla_base copia_trabajo`).

2. **Transacción en Pruebas:**
   - Todo script con instrucciones de escritura (`INSERT`, `UPDATE`, `DELETE`, `ALTER`) debe probarse obligatoriamente dentro de un bloque transaccional explícito:
     ```sql
     BEGIN;
     -- Ejecución de scripts
     -- Inspección de efectos y filas afectadas
     ROLLBACK;
     ```
   - Solo se ejecutará `COMMIT` tras confirmar visualmente que el comportamiento y los mensajes son los esperados.

3. **Respaldo previo a DDL:**
   - Antes de aplicar cualquier cambio estructural (`ALTER`, `DROP`, migraciones o cambios de esquema), es obligatorio generar una copia de respaldo independiente usando `pg_dump` sobre la base de trabajo.
