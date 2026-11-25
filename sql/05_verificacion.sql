-- Verificacion de la carga

-- A. Conteos (esperados: 11, 51, 122, 23, 4365, 20652, 65752, 180519, 469977, 466728)
SELECT 'departamento' AS tabla, COUNT(*) AS filas FROM departamento
UNION ALL SELECT 'categoria', COUNT(*) FROM categoria
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'region', COUNT(*) FROM region
UNION ALL SELECT 'ubicacion', COUNT(*) FROM ubicacion
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido
UNION ALL SELECT 'visita', COUNT(*) FROM visita
UNION ALL SELECT 'visita_sin_repetidas (vista)', COUNT(*) FROM visita_sin_repetidas;

-- B. Huerfanos (esperado: 0 en todas; las llaves foraneas ya lo garantizan)
SELECT 'detalle sin pedido' AS control, COUNT(*) AS filas FROM detalle_pedido d
  WHERE NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_pedido = d.id_pedido)
UNION ALL SELECT 'detalle sin producto', COUNT(*) FROM detalle_pedido d
  WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_producto = d.id_producto)
UNION ALL SELECT 'pedido sin cliente', COUNT(*) FROM pedido p
  WHERE NOT EXISTS (SELECT 1 FROM cliente c WHERE c.id_cliente = p.id_cliente)
UNION ALL SELECT 'visita sin producto', COUNT(*) FROM visita v
  WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_producto = v.id_producto)
UNION ALL SELECT 'pedido sin detalle', COUNT(*) FROM pedido p
  WHERE NOT EXISTS (SELECT 1 FROM detalle_pedido d WHERE d.id_pedido = p.id_pedido);

-- C. Reconstruir el archivo original uniendo las tablas y compararlo con staging
--    (esperado: 0 y 0 = no se perdio ni cambio ningun dato)
WITH rec AS (
  SELECT d.id_detalle, d.id_pedido, p.id_cliente, d.id_producto, d.cantidad,
         d.precio_unitario, d.descuento, d.ganancia,
         p.fecha_pedido, p.fecha_envio, p.estado, p.tipo_pago, p.modo_envio,
         p.estado_entrega, p.dias_envio_programado, p.riesgo_retraso,
         pr.nombre AS producto, pr.id_categoria,
         c.nombre AS nombre_cliente, c.codigo_postal,
         ub.ciudad AS ciudad_destino, ub.pais AS pais_destino, r.nombre AS region
  FROM detalle_pedido d
  JOIN pedido p     ON p.id_pedido = d.id_pedido
  JOIN producto pr  ON pr.id_producto = d.id_producto
  JOIN cliente c    ON c.id_cliente = p.id_cliente
  JOIN ubicacion ub ON ub.id_ubicacion = p.id_destino
  JOIN region r     ON r.id_region = ub.id_region
),
orig AS (
  SELECT order_item_id, order_id, customer_id, product_card_id, order_item_quantity,
         ROUND(order_item_product_price::numeric, 2),
         ROUND(order_item_discount::numeric, 2),
         ROUND(order_profit_per_order::numeric, 2),
         TO_TIMESTAMP(order_date_dateorders, 'MM/DD/YYYY HH24:MI')::timestamp,
         TO_TIMESTAMP(shipping_date_dateorders, 'MM/DD/YYYY HH24:MI')::timestamp,
         limpiar_texto(order_status), limpiar_texto(type), limpiar_texto(shipping_mode),
         limpiar_texto(delivery_status), days_for_shipment_scheduled, late_delivery_risk,
         limpiar_texto(product_name), category_id,
         limpiar_texto(customer_fname),
         CASE WHEN customer_zipcode IS NULL THEN NULL
              WHEN LENGTH(CAST(customer_zipcode AS BIGINT)::TEXT) < 5
                   THEN LPAD(CAST(customer_zipcode AS BIGINT)::TEXT, 5, '0')
              ELSE CAST(customer_zipcode AS BIGINT)::TEXT END,
         limpiar_texto(order_city), limpiar_texto(order_country), limpiar_texto(order_region)
  FROM staging.ventas
)
SELECT 'en tablas y no en staging' AS comparacion, COUNT(*) AS filas
FROM (SELECT * FROM rec EXCEPT SELECT * FROM orig) a
UNION ALL
SELECT 'en staging y no en tablas', COUNT(*)
FROM (SELECT * FROM orig EXCEPT SELECT * FROM rec) b;

-- D. Las repetidas de visita (esperado: 469977, 466728 y 3249)
SELECT (SELECT COUNT(*) FROM visita) AS todas,
       (SELECT COUNT(*) FROM visita_sin_repetidas) AS sin_repetidas,
       (SELECT COUNT(*) FROM visita) - (SELECT COUNT(*) FROM visita_sin_repetidas) AS repetidas;
