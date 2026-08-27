# Informe de Concurrencia — Food Store

**TP Base de Datos II** · Reconstrucción y verificación de anomalías de concurrencia en PostgreSQL
(base de desarrollo `copia_trabajo`, motor PostgreSQL 17).

> **Nota de transparencia (criterio de la cátedra):**
> El flujo seguido es el de la consigna 5.2: se reproducen los escenarios con dos sesiones, se le pide
> explicación a la IA, y se verifica esa explicación en el motor. Como no se conservó el texto literal
> de la herramienta usada (Gemini), las explicaciones que siguen fueron **redactadas de forma
> equivalente** y quedan marcadas como tales. Lo que decide es el motor, no el modelo: si una
> explicación no se confirma en la ejecución, eso se documenta tal cual, sin ocultarse.

Se reproducen **3 escenarios**: Lectura no repetible, Lectura fantasma y Espera por bloqueo
(`FOR UPDATE`). El cuarto escenario (Interbloqueo / deadlock `40P01`) fue descartado.

---

## Escenario 1 — Lectura no repetible

| Campo | Contenido |
| :--- | :--- |
| **Escenario** | Lectura no repetible (non-repeatable read) sobre `producto.stock`. |
| **Cómo se reprodujo** | **Sesión A:** `BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;` → `SELECT nombre, stock FROM producto WHERE id_producto = 1;`. **Sesión B** (intercalada): `BEGIN;` → `UPDATE producto SET stock = 4 WHERE id_producto = 1;` → `COMMIT;`. **Sesión A:** vuelve a `SELECT nombre, stock FROM producto WHERE id_producto = 1;` → `COMMIT;`. Para verificar: **Sesión A:** `BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;` → `SELECT` dos veces, con la Sesión B confirmando `UPDATE producto SET stock = 20` entre ambas, → `COMMIT;`. |
| **Qué se observó** | **Sesión A (READ COMMITTED):** primer `SELECT` devuelve `stock = 10`; segundo `SELECT`, tras el commit de la Sesión B a `4`, devuelve `stock = 4` → el valor cambió dentro de la misma transacción. **Sesión A (REPEATABLE READ):** `SELECT` devuelve `stock = 4` y vuelve a devolver `stock = 4` aun cuando la Sesión B confirmó `stock = 20` entre lecturas → el valor se mantiene estable. |
| **Explicación de la IA** | *(Redactada — herramienta: Gemini)* En `READ COMMITTED` cada sentencia individual ve una "foto" nueva del estado confirmado; como la Sesión B confirmó su `UPDATE` entre las dos lecturas, la segunda lectura ve un valor distinto → lectura no repetible. En `REPEATABLE READ` la transacción usa un snapshot fijo tomado al comenzar, por lo que las lecturas repetidas del mismo dato dan siempre el mismo valor, independientemente de commits ajenos. El `REPEATABLE READ` es el nivel que evita la anomalía. |
| **Verificación en el motor** | Se repitió el experimento con `SET/BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ`: la Sesión A leyó `stock = 4` y volvió a leer `stock = 4`, mientras la Sesión B confirmó `UPDATE producto SET stock = 20`. La lectura no cambió → el resultado fue el esperado. |
| **Conclusión** | La explicación se **confirmó** en el motor. La lectura no repetible se resuelve con el nivel de aislamiento **`REPEATABLE READ`** (la Sesión A ve un snapshot estable). |

---

## Escenario 2 — Lectura fantasma

| Campo | Contenido |
| :--- | :--- |
| **Escenario** | Lectura fantasma (phantom read): aparece una fila nueva en una consulta de agregación sobre `producto`. |
| **Cómo se reprodujo** | **Sesión A:** `BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;` → `SELECT COUNT(*), SUM(stock) FROM producto WHERE eliminado = FALSE;`. **Sesión B** (intercalada): `BEGIN;` → `INSERT INTO producto (id_categoria, nombre, precio, stock, eliminado) VALUES (1, 'Hamburguesa Triple', 9000, 8, FALSE);` → `COMMIT;`. **Sesión A:** repite `SELECT COUNT(*), SUM(stock) FROM producto WHERE eliminado = FALSE;` → `COMMIT;`. |
| **Qué se observó** | **Sesión A:** primera consulta devuelve `count = 2, sum = 25`; segunda consulta, tras el `INSERT` confirmado de la Sesión B, devuelve `count = 3, sum = 33`. Apareció una fila nueva (fantasma) en el resultado del agregado. |
| **Explicación de la IA** | *(Redactada — herramienta: Gemini)* En `READ COMMITTED` cada consulta ve las filas confirmadas hasta ese momento; como la Sesión B confirmó su `INSERT` entre las dos consultas, la fila nueva aparece en el resultado → lectura fantasma. `REPEATABLE READ` (snapshot fijo) y `SERIALIZABLE` evitan que el resultado de una consulta repetida cambie por filas insertadas por otras transacciones. |
| **Verificación en el motor** | El mecanismo que propone la IA es `REPEATABLE READ` / `SERIALIZABLE` (snapshot fijo). **Nota:** la evidencia capturada no incluye la repetición de *este* escenario en `REPEATABLE READ`; la confirmación práctica de esa repetición queda **pendiente de registrar**, no se documenta una salida que no se observó. |
| **Conclusión** | El mecanismo señalado (snapshot fijo de `REPEATABLE READ` / `SERIALIZABLE`) es el correcto para evitar la lectura fantasma en agregados. La **repetición verificatoria de este caso en el motor queda pendiente** de capturar para dejar la confirmación explícita. |

---

## Escenario 3 — Espera por bloqueo (`FOR UPDATE`)

| Campo | Contenido |
| :--- | :--- |
| **Escenario** | Espera por bloqueo (blocking / lock wait) a nivel de fila usando `SELECT ... FOR UPDATE`. |
| **Cómo se reprodujo** | **Sesión A:** `BEGIN;` → `SELECT * FROM producto WHERE id_producto = 1 FOR UPDATE;` (retiene el lock de fila **sin confirmar**). **Sesión B:** `BEGIN;` → `SELECT * FROM producto WHERE id_producto = 1 FOR UPDATE;` (queda esperando el lock). **Sesión A:** `COMMIT;` (libera el lock). **Sesión B** (tras la liberación): devuelve la fila → `COMMIT;`. |
| **Qué se observó** | **Sesión A** devuelve la fila (`stock = 20`) y la retiene con el lock. **Sesión B**, al ejecutar su `FOR UPDATE` mientras la Sesión A mantenía el lock, **quedó bloqueada esperando**; recién avanzó y devolvió la fila (también `stock = 20`) una vez que la Sesión A confirmó. La transcripción muestra el resultado **post-liberación**, por lo que la espera en sí no aparece en la captura. |
| **Explicación de la IA** | *(Redactada — herramienta: Gemini)* La espera por bloqueo **no es una anomalía de la que proteja un nivel de aislamiento**: es el comportamiento del bloqueo a nivel de **fila**. `SELECT ... FOR UPDATE` adquiere un lock exclusivo sobre la fila; otra transacción que quiera alterarla o leerla con `FOR UPDATE` queda **en espera** hasta que la primera haga `COMMIT` o `ROLLBACK`. Se resuelve **liberando el lock** y puede acotarse con `lock_timeout`. |
| **Verificación en el motor** | Se repitió el experimento: la Sesión A tomó la fila con `FOR UPDATE`, la Sesión B quedó en espera, y tras el `COMMIT` de la Sesión A la Sesión B obtuvo la fila. El bloqueo y su liberación se confirmaron en el motor. |
| **Conclusión** | La explicación se **confirmó** en el motor. No aplica un nivel de aislamiento; el mecanismo que resuelve la espera es el **lock de fila con `SELECT ... FOR UPDATE`**, liberado mediante `COMMIT` / `ROLLBACK` (y acotable con `lock_timeout`). |

---

## Resumen

| Escenario | Anomalía/mecanismo | ¿Se confirmó en el motor? | Qué lo resuelve |
| :--- | :--- | :--- | :--- |
| Lectura no repetible | Valor cambia entre lecturas | Sí | `REPEATABLE READ` (snapshot fijo) |
| Lectura fantasma | Fila nueva aparece en un agregado | Mecanismo correcto; repetición en RR pendiente | `REPEATABLE READ` / `SERIALIZABLE` |
| Espera por bloqueo | Lock de fila; la Sesión B espera | Sí | Lock `SELECT ... FOR UPDATE` liberado por `COMMIT`/`ROLLBACK` (acotable con `lock_timeout`) |
