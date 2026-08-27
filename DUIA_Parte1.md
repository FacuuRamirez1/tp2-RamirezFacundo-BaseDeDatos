# Planilla de declaración de Uso de IA - Parte 1

| Campo | Detalle |
| :--- | :--- |
| **Herramienta** | OpenCode (Zen / Modelo Big Pickle) |
| **Spec o prompt utilizado** | "Integrar restricciones en la BD para 3 reglas: 1) Evitar venta de productos marcados con `eliminado = TRUE`. 2) Controlar stock y descontarlo únicamente cuando `pedido.estado_pedido` pase a `'PAGADO'`. 3) Validar que `precio_unitario` en `detalle_pedido` sea > 0 y <= `producto.precio`." |
| **Qué generó** | `db/schema.sql`: modificación agregando el `ENUM estado_pedido_t` y la columna `estado_pedido`. `db/restricciones.sql`: triggers `fn_validar_detalle_pedido` (BEFORE INSERT/UPDATE en `detalle_pedido`) y `fn_descontar_stock_pedido` (BEFORE UPDATE de `estado_pedido` en `pedido`). |
| **Qué se aceptó** | La arquitectura de dos triggers separados: validación puntual en `detalle_pedido` (producto no eliminado y precio unitario) y control de stock transaccional al confirmarse el pago en `pedido`. |
| **Qué se modificó o descartó** | Se descartó la ejecución automática del motor por parte de la IA. Los scripts quedaron escritos y revisados mediante `git diff` / inspección, sin aplicarse a ninguna base de datos real. |
| **Verificación realizada** | Inspección y revisión de la sintaxis y coherencia de `db/schema.sql` y `db/restricciones.sql` con el esquema existente. No se ejecutaron pruebas sobre un motor PostgreSQL; queda pendiente la validación manual siguiendo el protocolo de `protocolo_seguridad.md` (copia de desarrollo `createdb -T`, bloque `BEGIN...ROLLBACK` y respaldo `pg_dump` previo). |