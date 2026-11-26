-- Verificacion de la carga y de la normalizacion (bloques A a D)

-- A. Conteos  [departamento 11, categoria 51, producto 122, region 23,
--    ubicacion 4365, cliente 20652, pedido 65752, detalle_pedido 180519,
--    visita 469977, modo_envio 4, vistas 65752 y 466728]
SELECT 'departamento' AS tabla, count(*) AS filas FROM departamento
UNION ALL SELECT 'categoria', count(*) FROM categoria
UNION ALL SELECT 'producto', count(*) FROM producto
UNION ALL SELECT 'region', count(*) FROM region
UNION ALL SELECT 'ubicacion', count(*) FROM ubicacion
UNION ALL SELECT 'cliente', count(*) FROM cliente
UNION ALL SELECT 'modo_envio', count(*) FROM modo_envio
UNION ALL SELECT 'pedido', count(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido
UNION ALL SELECT 'visita', count(*) FROM visita
UNION ALL SELECT 'pedido_completo (vista)', count(*) FROM pedido_completo
UNION ALL SELECT 'visita_sin_repetidas (vista)', count(*) FROM visita_sin_repetidas;

-- B. Huerfanos  [0 en las cinco filas]
SELECT 'visita sin producto' AS revision, count(*) AS filas
FROM visita v LEFT JOIN producto p ON p.id_producto = v.id_producto
WHERE p.id_producto IS NULL
UNION ALL SELECT 'pedido sin detalle', count(*)
FROM pedido p LEFT JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE d.id_detalle IS NULL
UNION ALL SELECT 'detalle sin pedido', count(*)
FROM detalle_pedido d LEFT JOIN pedido p ON p.id_pedido = d.id_pedido
WHERE p.id_pedido IS NULL
UNION ALL SELECT 'detalle sin producto', count(*)
FROM detalle_pedido d LEFT JOIN producto pr ON pr.id_producto = d.id_producto
WHERE pr.id_producto IS NULL
UNION ALL SELECT 'pedido sin cliente', count(*)
FROM pedido p LEFT JOIN cliente c ON c.id_cliente = p.id_cliente
WHERE c.id_cliente IS NULL;

-- C. Reconstruccion contra staging.ventas  [0 y 0]
-- Une detalle_pedido con pedido_completo (la vista que devuelve modo de envio,
-- dias programados y riesgo de retraso) y lo compara con el archivo original.
WITH t AS (
  SELECT d.id_detalle, p.id_pedido, p.id_cliente, d.id_producto, d.cantidad,
         d.precio_unitario, d.descuento, d.ganancia,
         p.estado, p.tipo_pago, p.modo_envio, p.estado_entrega,
         p.dias_envio_programado, p.riesgo_retraso,
         p.fecha_pedido, p.fecha_envio
  FROM detalle_pedido d
  JOIN pedido_completo p ON p.id_pedido = d.id_pedido),
s AS (
  SELECT order_item_id, order_id, customer_id, product_card_id, order_item_quantity,
         ROUND(order_item_product_price::numeric, 2),
         ROUND(order_item_discount::numeric, 2),
         ROUND(order_profit_per_order::numeric, 2),
         limpiar_texto(order_status), limpiar_texto(type),
         limpiar_texto(shipping_mode), limpiar_texto(delivery_status),
         days_for_shipment_scheduled, late_delivery_risk,
         TO_TIMESTAMP(order_date_dateorders, 'MM/DD/YYYY HH24:MI')::timestamp,
         TO_TIMESTAMP(shipping_date_dateorders, 'MM/DD/YYYY HH24:MI')::timestamp
  FROM staging.ventas)
SELECT (SELECT count(*) FROM (SELECT * FROM t EXCEPT SELECT * FROM s) x)
         AS en_tablas_y_no_en_staging,
       (SELECT count(*) FROM (SELECT * FROM s EXCEPT SELECT * FROM t) y)
         AS en_staging_y_no_en_tablas;

-- D. Visitas  [469977, 466728 y 3249]
SELECT (SELECT count(*) FROM visita) AS todas,
       (SELECT count(*) FROM visita_sin_repetidas) AS sin_repetidas,
       (SELECT count(*) FROM visita) - (SELECT count(*) FROM visita_sin_repetidas)
         AS repetidas;