# Ejercicio de Lectura Crítica — Scripts SQL (Parte 3)

**TP Base de Datos II** · Análisis y corrección de dos scripts supuestamente generados para "dar de baja
registros vencidos" sobre el esquema genérico de cátedra.

> **Nota de contexto:** no se dispone del DDL del esquema genérico de cátedra. Los nombres de columnas
> usados en las correcciones son inferidos de forma razonable a partir de los propios scripts y del dominio
> (`funcion(activa, pelicula_id)`, `pelicula(id, activa)`, `categoria(id)`, `producto(id, categoria_id)`).

---

## Script 1

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartelera
UPDATE funcion
SET activa = FALSE;
```

### Consigna que declara cumplir
Dar de baja únicamente las **funciones de películas retiradas de cartelera** (es decir, las proyecciones de
películas que ya no están vigentes).

### Qué filas afectaría realmente tal como está escrito
**Todas las filas de la tabla `funcion`.** El `UPDATE` no tiene cláusula `WHERE`, por lo que pone
`activa = FALSE` en el **100 %** de las funciones, incluidas las de películas que siguen en cartelera.

### Por qué no coincide con la consigna
- Sin `WHERE` no se filtra por la condición que define "película retirada de cartelera".
- Se modifica también `funcion.activa` de funciones de películas **vigentes**, que no debían tocarse.
- La consigna es condicional ("las funciones **de** películas retiradas"); un `UPDATE` completo la
  simplifica incorrectamente a "todas las funciones".

### Versión corregida

```sql
UPDATE funcion f
SET activa = FALSE
WHERE f.pelicula_id IN (
    SELECT p.id
      FROM pelicula p
     WHERE p.activa = FALSE
);
```

Alternativa equivalente con `EXISTS`:

```sql
UPDATE funcion f
SET activa = FALSE
WHERE EXISTS (
    SELECT 1
      FROM pelicula p
     WHERE p.id = f.pelicula_id
       AND p.activa = FALSE
);
```

> Supuesto: `funcion.pelicula_id` es una FK NOT NULL hacia `pelicula` y `pelicula.activa` (BOOLEAN)
> es el indicador de "retirada de cartelera".

---

## Script 2

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto)
```

### Consigna que declara cumplir
Eliminar las categorías que no tienen ningún producto asociado.

### Qué filas afectaría realmente tal como está escrito
- **Caso sin NULL:** si `producto.categoria_id` no contiene ningún `NULL`, el `NOT IN` funciona y borraría
  las categorías sin productos (resultado aparentemente correcto).
- **Caso con NULL:** si **existe al menos un** `producto.categoria_id = NULL`, el conjunto devuelto por la
  subconsulta contiene un `NULL`. Con `NOT IN`, la comparación `id <> NULL` se evalúa como `UNKNOWN` para
  **todas** las filas, por lo que la condición nunca es verdadera y **no se borra ninguna categoría**
  (falla silenciosa: quedan categorías que sí deberían eliminarse).

### Por qué no coincide con la consigna
El uso de `NOT IN` con una subconsulta que puede devolver `NULL` produce un resultado **no fiable**:
- en el caso de filtros con `NULL`, **no borra nada** cuando sí hay categorías huérfanas que limpiar.

El comportamiento depende de datos que la consigna no controla (`categoria_id` nullable), por lo que no
satisface "limpiar las categorías sin productos asociados" de forma robusta.

### Versión corregida (manejo correcto de NULL)

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
      FROM producto p
     WHERE p.categoria_id = c.id
);
```

`NOT EXISTS` no se ve afectado por `NULL`: evalúa fila por fila y elimina cada categoría para la que no
exista ningún producto con su `categoria_id` apuntando a ese `id`.

---

## Resumen

| Script | Qué hace tal como está escrito | Por qué no cumple la consigna | Corrección |
| :--- | :--- | :--- | :--- |
| 1) `UPDATE funcion SET activa = FALSE;` | Desactiva **todas** las funciones | Falta el `WHERE`; afecta también funciones de películas vigentes | Agregar `WHERE` filtrando por películas retiradas de cartelera |
| 2) `DELETE FROM categoria WHERE id NOT IN (...);` | Borra categorías sin productos solo si no hay `NULL`; con `NULL` no borra nada | `NOT IN` es no confiable ante `NULL` en la subconsulta | Usar `NOT EXISTS` (maneja correctamente los `NULL`) |
