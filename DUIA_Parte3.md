# Planilla de declaración de Uso de IA - Parte 3

| Campo | Detalle |
| :--- | :--- |
| **Herramienta** | OpenCode (Zen / Modelo Big Pickle) |
| **Spec o prompt utilizado** | *"Leer críticamente dos scripts SQL supuestamente generados para dar de baja registros vencidos sobre el esquema genérico de cátedra, identificar qué hacen realmente tal como están escritos, y reescribirlos corregidos."* |
| **Qué generó** | El análisis y la corrección de ambos scripts: 1) `UPDATE funcion SET activa = FALSE;` → agregado un `WHERE` que filtra solo las funciones de películas retiradas de cartelera. 2) `DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);` → reemplazado por una condición `NOT EXISTS` para manejar correctamente los `NULL` de la subconsulta. |
| **Qué se aceptó** | Que el Script 1 realmente afectaría **todas** las filas de `funcion` (falta el `WHERE`), y que el Script 2 con `NOT IN` es no confiable ante `NULL` en `producto.categoria_id` (puede no borrar nada). Ambas correcciones se aceptaron con una nota de que los nombres de columna son inferidos por no contar con el DDL del esquema de cátedra. |
| **Qué se modificó o descartó** | Se implementaron las versiones corregidas: Script 1 con `WHERE ... IN (SELECT id FROM pelicula WHERE activa = FALSE)` (y alternativa con `EXISTS`); Script 2 con `NOT EXISTS` (manejo correcto de `NULL`). El análisis completo quedó en `ejercicio_lectura_critica.md`. |
| **Verificación realizada** | Revisión línea por línea de la lógica de cada corrección y coherencia con la consigna declarada. No se ejecutó sobre un motor ni se commiteó el archivo; el análisis se entregó como documento `ejercicio_lectura_critica.md` sin commitear. |

**Nota sobre el rol de la IA:** La IA se utilizó únicamente como guía y herramienta de redacción para organizar el análisis de lectura crítica y redactar la explicación. La identificación de qué hace cada script tal como está escrito y las correcciones propuestas (agregar `WHERE` en el Script 1; reemplazar `NOT IN` por `NOT EXISTS` en el Script 2) fueron revisadas y validadas con criterio propio del usuario antes de aceptarlas como resultado del ejercicio. Los resultados y las decisiones que prevalecen son los del usuario que realizó el análisis y la revisión crítica; la IA no determinó ni validó de forma autónoma el contenido final.
