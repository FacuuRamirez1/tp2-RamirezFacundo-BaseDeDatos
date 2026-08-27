-- ============================================================
-- Facundo Ramírez - COM4
-- TP N.1 - Base de Datos II
-- Food Store - restricciones.sql
-- Funciones y triggers de integridad y reglas de negocio
-- ============================================================
--
-- Reglas implementadas:
--   R1) Un detalle de pedido no puede referenciar un producto eliminado.
--   R2) Al pasar el pedido a PAGADO se valida que cada detalle no supere
--       el stock disponible y se descuenta el stock de cada producto.
--   R3) precio_unitario debe ser mayor a 0 y no superar el precio de
--       lista actual del producto al momento de la venta.
--
-- NOTA (protocolo de seguridad): este archivo solo define código.
-- Probarlo/ejecutarlo requiere: copia de desarrollo, transaccion
-- BEGIN...ROLLBACK y respaldo pg_dump previo, segun security-policies.md.

-- ============================================================
-- Reglas 1 y 3: validacion sobre detalle_pedido
-- BEFORE INSERT OR UPDATE en detalle_pedido
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validar_detalle_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_producto_eliminado BOOLEAN;
    v_precio_lista       NUMERIC(10, 2);
    v_nombre_producto    VARCHAR(100);
BEGIN
    -- R1: el producto referenciado no debe estar eliminado (baja logica)
    SELECT eliminado, precio, nombre
      INTO v_producto_eliminado, v_precio_lista, v_nombre_producto
      FROM producto
     WHERE id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el producto con id %', NEW.id_producto
            USING ERRCODE = 'P0001';
    END IF;

    IF v_producto_eliminado THEN
        RAISE EXCEPTION 'El producto "%" (id %) no esta disponible: fue eliminado',
            v_nombre_producto, NEW.id_producto
            USING ERRCODE = 'P0001';
    END IF;

    -- R3: precio_unitario debe ser mayor a 0
    IF NEW.precio_unitario <= 0 THEN
        RAISE EXCEPTION 'precio_unitario debe ser mayor a 0 (se recibio %)',
            NEW.precio_unitario
            USING ERRCODE = 'P0001';
    END IF;

    -- R3: precio_unitario no debe superar el precio de lista vigente del producto
    IF NEW.precio_unitario > v_precio_lista THEN
        RAISE EXCEPTION 'precio_unitario (%) supera el precio de lista actual del producto "%" (%)',
            NEW.precio_unitario, v_nombre_producto, v_precio_lista
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_detalle_pedido ON detalle_pedido;
CREATE TRIGGER trg_validar_detalle_pedido
    BEFORE INSERT OR UPDATE ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_detalle_pedido();

-- ============================================================
-- Regla 2: validacion de stock y descuento al pasar a PAGADO
-- BEFORE UPDATE OF estado_pedido en pedido
-- ============================================================

CREATE OR REPLACE FUNCTION fn_descontar_stock_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    r_detalle     RECORD;
    v_stock       INTEGER;
    v_nombre      VARCHAR(100);
BEGIN
    -- Solo se descuenta cuando el pedido pasa a PAGADO.
    IF NEW.estado_pedido <> 'PAGADO' OR OLD.estado_pedido = 'PAGADO' THEN
        RETURN NEW;
    END IF;

    FOR r_detalle IN
        SELECT dp.id_producto, dp.cantidad
          FROM detalle_pedido dp
         WHERE dp.id_pedido = NEW.id_pedido
    LOOP
        SELECT stock, nombre
          INTO v_stock, v_nombre
          FROM producto
         WHERE id_producto = r_detalle.id_producto;

        IF v_stock < r_detalle.cantidad THEN
            RAISE EXCEPTION 'Cantidad solicitada del producto "%" (id %) supera el stock disponible (% < %)',
                v_nombre, r_detalle.id_producto, v_stock, r_detalle.cantidad
                USING ERRCODE = 'P0001';
        END IF;
    END LOOP;

    -- Todas las validaciones pasaron: se descuenta el stock
    FOR r_detalle IN
        SELECT dp.id_producto, dp.cantidad
          FROM detalle_pedido dp
         WHERE dp.id_pedido = NEW.id_pedido
    LOOP
        UPDATE producto
           SET stock = stock - r_detalle.cantidad
         WHERE id_producto = r_detalle.id_producto;
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_descontar_stock_pedido ON pedido;
CREATE TRIGGER trg_descontar_stock_pedido
    BEFORE UPDATE OF estado_pedido ON pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_descontar_stock_pedido();
