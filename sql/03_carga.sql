-- Carga de las tablas normalizadas desde staging, en orden de dependencias.
-- Se ejecuta una sola vez sobre tablas vacias.

-- 1. departamento
INSERT INTO departamento (id_departamento, nombre)
SELECT DISTINCT department_id, limpiar_texto(department_name)
FROM staging.ventas;

-- 2. categoria
INSERT INTO categoria (id_categoria, nombre, id_departamento)
SELECT DISTINCT category_id, limpiar_texto(category_name), department_id
FROM staging.ventas;

-- 3a. producto (los 118 de ventas)
INSERT INTO producto (id_producto, nombre, precio, imagen_url, id_categoria, origen)
SELECT DISTINCT product_card_id,
       limpiar_texto(product_name),
       ROUND(product_price::numeric, 2),
       limpiar_texto(product_image),
       category_id,
       'ventas'
FROM staging.ventas;

-- 3b. producto (los que solo aparecen en los logs; ids desde 10001)
WITH nuevos AS (
  SELECT limpiar_texto(product) AS nombre,
         MIN(LOWER(limpiar_texto(category))) AS cat
  FROM staging.visitas
  WHERE LOWER(limpiar_texto(product)) NOT IN (SELECT LOWER(nombre) FROM producto)
  GROUP BY 1
),
cat_unica AS (            -- solo categorias cuyo nombre identifica un unico id
  SELECT LOWER(nombre) AS n, MIN(id_categoria) AS id_categoria
  FROM categoria
  GROUP BY 1
  HAVING COUNT(*) = 1
)
INSERT INTO producto (id_producto, nombre, precio, imagen_url, id_categoria, origen)
SELECT 10000 + ROW_NUMBER() OVER (ORDER BY nuevos.nombre),
       nuevos.nombre, NULL, NULL, cat_unica.id_categoria, 'inferido_logs'
FROM nuevos
LEFT JOIN cat_unica ON cat_unica.n = nuevos.cat;

-- 4. region
INSERT INTO region (nombre, mercado)
SELECT DISTINCT limpiar_texto(order_region), limpiar_texto(market)
FROM staging.ventas;

-- 5a. ubicacion: destinos de los pedidos (con region)
INSERT INTO ubicacion (ciudad, estado, pais, id_region)
SELECT DISTINCT limpiar_texto(v.order_city), limpiar_texto(v.order_state),
       limpiar_texto(v.order_country), r.id_region
FROM staging.ventas v
JOIN region r ON r.nombre = limpiar_texto(v.order_region);

-- 5b. ubicacion: lugares de residencia de los clientes (sin region)
--     "EE. UU." se unifica a "Estados Unidos"
INSERT INTO ubicacion (ciudad, estado, pais)
SELECT DISTINCT limpiar_texto(customer_city), limpiar_texto(customer_state),
       CASE WHEN limpiar_texto(customer_country) = 'EE. UU.'
            THEN 'Estados Unidos' ELSE limpiar_texto(customer_country) END
FROM staging.ventas
ON CONFLICT (ciudad, estado, pais) DO NOTHING;

-- 6. cliente (correo y telefono los llena etl/faker_contacto.py)
INSERT INTO cliente (id_cliente, nombre, apellido, segmento, calle, codigo_postal,
                     latitud, longitud, id_ubicacion)
SELECT DISTINCT ON (v.customer_id)
       v.customer_id,
       limpiar_texto(v.customer_fname),
       limpiar_texto(v.customer_lname),
       limpiar_texto(v.customer_segment),
       limpiar_texto(v.customer_street),
       CASE WHEN v.customer_zipcode IS NULL THEN NULL
            WHEN LENGTH(CAST(v.customer_zipcode AS BIGINT)::TEXT) < 5
                 THEN LPAD(CAST(v.customer_zipcode AS BIGINT)::TEXT, 5, '0')
            ELSE CAST(v.customer_zipcode AS BIGINT)::TEXT END,
       ROUND(v.latitude::numeric, 6),
       ROUND(v.longitude::numeric, 6),
       u.id_ubicacion
FROM staging.ventas v
JOIN ubicacion u
  ON u.ciudad IS NOT DISTINCT FROM limpiar_texto(v.customer_city)
 AND u.estado IS NOT DISTINCT FROM limpiar_texto(v.customer_state)
 AND u.pais   =  CASE WHEN limpiar_texto(v.customer_country) = 'EE. UU.'
                      THEN 'Estados Unidos' ELSE limpiar_texto(v.customer_country) END
ORDER BY v.customer_id;

-- 7. pedido
INSERT INTO pedido (id_pedido, id_cliente, fecha_pedido, fecha_envio, estado, tipo_pago,
                    modo_envio, estado_entrega, dias_envio_programado, riesgo_retraso,
                    id_destino)
SELECT DISTINCT ON (v.order_id)
       v.order_id,
       v.customer_id,
       TO_TIMESTAMP(v.order_date_dateorders, 'MM/DD/YYYY HH24:MI')::timestamp,
       TO_TIMESTAMP(v.shipping_date_dateorders, 'MM/DD/YYYY HH24:MI')::timestamp,
       limpiar_texto(v.order_status),
       limpiar_texto(v.type),
       limpiar_texto(v.shipping_mode),
       limpiar_texto(v.delivery_status),
       v.days_for_shipment_scheduled,
       v.late_delivery_risk,
       u.id_ubicacion
FROM staging.ventas v
JOIN ubicacion u
  ON u.ciudad IS NOT DISTINCT FROM limpiar_texto(v.order_city)
 AND u.estado IS NOT DISTINCT FROM limpiar_texto(v.order_state)
 AND u.pais   =  limpiar_texto(v.order_country)
ORDER BY v.order_id;

-- 8. detalle_pedido
INSERT INTO detalle_pedido (id_detalle, id_pedido, id_producto, cantidad,
                            precio_unitario, descuento, ganancia)
SELECT order_item_id, order_id, product_card_id, order_item_quantity,
       ROUND(order_item_product_price::numeric, 2),
       ROUND(order_item_discount::numeric, 2),
       ROUND(order_profit_per_order::numeric, 2)
FROM staging.ventas;

-- 9. visita (los 469,977 registros; las repetidas se conservan)
INSERT INTO visita (id_producto, fecha_hora, ip, evento)
SELECT p.id_producto,
       TO_TIMESTAMP(l."date", 'MM/DD/YYYY HH24:MI')::timestamp,
       l.ip::inet,
       CASE WHEN l.url LIKE '%/add_to_cart' THEN 'agregar_carrito' ELSE 'vista' END
FROM staging.visitas l
JOIN producto p ON LOWER(p.nombre) = LOWER(limpiar_texto(l.product));
