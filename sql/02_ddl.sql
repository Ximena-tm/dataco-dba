-- DDL final de la base normalizada (3FN). Ejecutar en la base dataco, esquema public.

-- Funcion de limpieza: quita espacios de mas y pasa vacios a NULL
CREATE FUNCTION limpiar_texto(t TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS
$$ SELECT NULLIF(TRIM(REGEXP_REPLACE(t, '\s+', ' ', 'g')), '') $$;

CREATE TABLE departamento (
  id_departamento INT PRIMARY KEY,
  nombre          TEXT NOT NULL
);

CREATE TABLE categoria (
  id_categoria    INT PRIMARY KEY,
  nombre          TEXT NOT NULL,   -- sin UNIQUE: "Electronics" existe con 2 ids
  id_departamento INT NOT NULL REFERENCES departamento
);

CREATE TABLE producto (
  id_producto  INT PRIMARY KEY,
  nombre       TEXT NOT NULL UNIQUE,
  precio       NUMERIC(10,2),      -- precio de catalogo; NULL en productos inferidos de logs
  imagen_url   TEXT,
  id_categoria INT REFERENCES categoria,
  origen       TEXT NOT NULL CHECK (origen IN ('ventas','inferido_logs'))
);

CREATE TABLE region (
  id_region SERIAL PRIMARY KEY,
  nombre    TEXT NOT NULL UNIQUE,
  mercado   TEXT NOT NULL
);

CREATE TABLE ubicacion (
  id_ubicacion SERIAL PRIMARY KEY,
  ciudad       TEXT,
  estado       TEXT,
  pais         TEXT NOT NULL,
  id_region    INT REFERENCES region,
  UNIQUE (ciudad, estado, pais)
);

CREATE TABLE cliente (
  id_cliente    INT PRIMARY KEY,
  nombre        TEXT,
  apellido      TEXT,              -- 8 filas vacias en el origen
  segmento      TEXT,
  calle         TEXT,
  codigo_postal TEXT,              -- 3 filas vacias en el origen
  latitud       NUMERIC(9,6),
  longitud      NUMERIC(9,6),
  correo        TEXT,              -- sintetico (Faker): el origen trae XXXXXXXXX en todas las filas
  telefono      TEXT,              -- sintetico (Faker)
  id_ubicacion  INT REFERENCES ubicacion
);

CREATE TABLE pedido (
  id_pedido             INT PRIMARY KEY,
  id_cliente            INT NOT NULL REFERENCES cliente,
  fecha_pedido          TIMESTAMP NOT NULL,
  fecha_envio           TIMESTAMP,
  estado                TEXT NOT NULL,
  tipo_pago             TEXT,
  modo_envio            TEXT,
  estado_entrega        TEXT,
  dias_envio_programado INT,
  riesgo_retraso        INT CHECK (riesgo_retraso IN (0,1)),
  id_destino            INT REFERENCES ubicacion
  -- dias_envio_real se calcula: fecha_envio::date - fecha_pedido::date
);

CREATE TABLE detalle_pedido (
  id_detalle      INT PRIMARY KEY,   -- order_item_id
  id_pedido       INT NOT NULL REFERENCES pedido,
  id_producto     INT NOT NULL REFERENCES producto,
  cantidad        INT NOT NULL CHECK (cantidad > 0),
  precio_unitario NUMERIC(10,2),     -- precio al momento de la compra
  descuento       NUMERIC(10,2) DEFAULT 0,
  ganancia        NUMERIC(12,2)      -- 18.7 % son negativas: se conservan
);

CREATE TABLE visita (
  id_visita   BIGSERIAL PRIMARY KEY,
  id_producto INT NOT NULL REFERENCES producto,
  fecha_hora  TIMESTAMP NOT NULL,
  ip          INET,
  evento      TEXT NOT NULL DEFAULT 'vista'
              CHECK (evento IN ('vista','agregar_carrito'))
);
