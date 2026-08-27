-- ============================================================
-- Facundo Ramírez - COM4
-- TP N.1 - Base de Datos II
-- Food Store - schema.sql
-- ============================================================

-- Limpieza previa
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido         CASCADE;
DROP TABLE IF EXISTS producto       CASCADE;
DROP TABLE IF EXISTS cliente        CASCADE;
DROP TABLE IF EXISTS categoria      CASCADE;
DROP TYPE IF EXISTS forma_pago_t;
DROP TYPE IF EXISTS estado_pedido_t;

-- Dominio cerrado para la forma de pago
CREATE TYPE forma_pago_t AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- Estado del pedido (permite descontar stock solo cuando el pedido queda PAGADO)
CREATE TYPE estado_pedido_t AS ENUM ('PENDIENTE', 'PAGADO', 'EN_PREPARACION', 'CANCELADO');

-- Creamos tabla categoria
CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(150) NOT NULL UNIQUE,
    eliminado    BOOLEAN      NOT NULL DEFAULT FALSE  -- baja logica (R7)
);

-- Creamos tabla cliente
CREATE TABLE cliente (
    id_cliente      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email           VARCHAR(100) NOT NULL UNIQUE,  -- clave candidata (R6)
    nombre_completo VARCHAR(100) NOT NULL,
    telefono        VARCHAR(20),                   -- nullable: contacto opcional
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Creamos tabla producto
CREATE TABLE producto (
    id_producto  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria BIGINT NOT NULL REFERENCES categoria (id_categoria) ON DELETE RESTRICT, -- NOT NULL: participacion TOTAL producto-categoria (R1)
    nombre       VARCHAR(100)   NOT NULL,
    precio       NUMERIC(10, 2) NOT NULL CHECK (precio >= 0),   -- R5
    stock        INTEGER        NOT NULL CHECK (stock >= 0),    -- R5
    eliminado    BOOLEAN        NOT NULL DEFAULT FALSE          -- R7
);

CREATE TABLE pedido (
    id_pedido     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    creado_en     TIMESTAMPTZ       NOT NULL DEFAULT now(),
    forma_pago    forma_pago_t      NOT NULL,
    estado_pedido estado_pedido_t   NOT NULL DEFAULT 'PENDIENTE', -- R8: el stock se descuenta recien cuando el pedido pasa a PAGADO
    id_cliente    BIGINT            NOT NULL REFERENCES cliente (id_cliente) ON DELETE RESTRICT -- NOT NULL: participacion TOTAL pedido-cliente (R2)
);

CREATE TABLE detalle_pedido (
    id_detalle_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- clave sustituta justificada en la Parte 2
    id_pedido         BIGINT NOT NULL REFERENCES pedido (id_pedido) ON DELETE RESTRICT,
    id_producto       BIGINT NOT NULL REFERENCES producto (id_producto) ON DELETE RESTRICT, -- ambas NOT NULL: toda linea referencia siempre un pedido y un producto
    nombre            VARCHAR(100)   NOT NULL,  -- nombre congelado al momento de la venta
    precio_unitario   NUMERIC(10, 2) NOT NULL CHECK (precio_unitario >= 0), -- precio historico (R4): independiente del precio de lista actual
    cantidad          INTEGER        NOT NULL CHECK (cantidad > 0),
    eliminado         BOOLEAN        NOT NULL DEFAULT FALSE, -- Clave candidata de la Parte 3: un producto no se repite dentro del mismo pedido
    CONSTRAINT uq_detalle_pedido_producto UNIQUE (id_pedido, id_producto) -- Sin subtotal: se recalcula como cantidad * precio_unitario (decision de la Parte 3)
);


-- ===== Indices =====

-- Acelera: "listar los productos vigentes de una categoria" (indice parcial: excluye bajas logicas)
CREATE INDEX idx_producto_categoria ON producto (id_categoria) WHERE eliminado = FALSE;

-- Acelera: "buscar todos los pedidos de un cliente" (historial de compras)
CREATE INDEX idx_pedido_cliente ON pedido (id_cliente);

-- Acelera: "mostrar el detalle completo de un pedido" (pantalla de pedido/factura)
CREATE INDEX idx_detalle_pedido_pedido ON detalle_pedido (id_pedido);