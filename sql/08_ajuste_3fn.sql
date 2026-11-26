-- Ajuste de 3FN en pedido: modo_envio -> dias_programados; riesgo derivable.
BEGIN;

CREATE TABLE modo_envio (
  id_modo_envio    SERIAL PRIMARY KEY,
  nombre           TEXT NOT NULL UNIQUE,
  dias_programados INT NOT NULL      -- sin UNIQUE: el negocio puede repetir plazos
);

INSERT INTO modo_envio (nombre, dias_programados)
SELECT DISTINCT modo_envio, dias_envio_programado
FROM pedido WHERE modo_envio IS NOT NULL;

ALTER TABLE pedido ADD COLUMN id_modo_envio INT REFERENCES modo_envio;

UPDATE pedido p SET id_modo_envio = m.id_modo_envio
FROM modo_envio m WHERE m.nombre = p.modo_envio;

-- Controles: si alguno falla, se detiene y no se borra nada
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pedido
             WHERE modo_envio IS NOT NULL AND id_modo_envio IS NULL) THEN
    RAISE EXCEPTION 'hay pedidos sin modo de envio asignado';
  END IF;
  IF EXISTS (SELECT 1 FROM pedido
             WHERE riesgo_retraso IS DISTINCT FROM
                   (CASE WHEN estado_entrega = 'Late delivery' THEN 1 ELSE 0 END)) THEN
    RAISE EXCEPTION 'riesgo_retraso no coincide con estado_entrega';
  END IF;
END $$;

ALTER TABLE pedido
  DROP COLUMN modo_envio,
  DROP COLUMN dias_envio_programado,
  DROP COLUMN riesgo_retraso;

-- Vista con las mismas columnas que tenia pedido, mas los dias reales calculados
CREATE VIEW pedido_completo AS
SELECT p.id_pedido, p.id_cliente, p.fecha_pedido, p.fecha_envio, p.estado,
       p.tipo_pago, m.nombre AS modo_envio, p.estado_entrega,
       m.dias_programados AS dias_envio_programado,
       CASE WHEN p.estado_entrega = 'Late delivery' THEN 1 ELSE 0 END AS riesgo_retraso,
       p.id_destino,
       (p.fecha_envio::date - p.fecha_pedido::date) AS dias_envio_real
FROM pedido p LEFT JOIN modo_envio m ON m.id_modo_envio = p.id_modo_envio;

COMMIT;