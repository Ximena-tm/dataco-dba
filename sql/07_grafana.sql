-- Consultas de los paneles de Grafana (Capitulo 10).
-- Es un archivo de referencia: se copia cada consulta a su panel.
-- No se ejecuta completo con Alt+X (usa macros de Grafana).
-- Primero, solo esta linea, con el usuario maestro (Ctrl+Enter):
GRANT pg_monitor TO grafana_user;

-- ===== NEGOCIO =====
-- N1 Ventas y ganancia por mes (Time series)
SELECT date_trunc('month', p.fecha_pedido) AS time,
       SUM(d.precio_unitario * d.cantidad - d.descuento) AS ventas,
       SUM(d.ganancia) AS ganancia
FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.estado NOT IN ('CANCELED','SUSPECTED_FRAUD') AND $__timeFilter(p.fecha_pedido)
GROUP BY 1 ORDER BY 1;

-- N2 Rentabilidad por categoria (Table)
SELECT c.nombre AS categoria,
       SUM(d.precio_unitario * d.cantidad - d.descuento) AS ventas,
       SUM(d.ganancia) AS ganancia,
       ROUND(100.0 * SUM(d.ganancia) /
             NULLIF(SUM(d.precio_unitario * d.cantidad - d.descuento), 0), 1) AS margen_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE d.ganancia < 0) / COUNT(*), 1) AS pct_articulos_con_perdida
FROM detalle_pedido d
JOIN pedido p ON p.id_pedido = d.id_pedido
JOIN producto pr ON pr.id_producto = d.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
WHERE p.estado NOT IN ('CANCELED','SUSPECTED_FRAUD')
GROUP BY c.id_categoria, c.nombre ORDER BY ganancia DESC LIMIT 10;

-- N3 Entregas por modo de envio (Table o Bar chart)
SELECT modo_envio, COUNT(*) AS pedidos,
       ROUND(100.0 * AVG(riesgo_retraso), 1) AS pct_riesgo_retraso,
       ROUND(AVG(dias_envio_programado), 1) AS dias_programados,
       ROUND(AVG(dias_envio_real), 1) AS dias_reales
FROM pedido_completo WHERE estado <> 'CANCELED'
GROUP BY modo_envio ORDER BY pct_riesgo_retraso DESC;

-- N4 Estado de entrega (Pie chart)
SELECT estado_entrega, COUNT(*) AS pedidos
FROM pedido GROUP BY 1 ORDER BY 2 DESC;

-- N5 Ventas y ganancia por mercado (Bar chart)
SELECT COALESCE(r.mercado, 'Sin region') AS mercado,
       SUM(d.precio_unitario * d.cantidad - d.descuento) AS ventas,
       SUM(d.ganancia) AS ganancia
FROM pedido p
JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
LEFT JOIN ubicacion u ON u.id_ubicacion = p.id_destino
LEFT JOIN region r ON r.id_region = u.id_region
WHERE p.estado NOT IN ('CANCELED','SUSPECTED_FRAUD')
GROUP BY 1 ORDER BY ventas DESC;

-- N6 Segmentos de cliente (Table)
SELECT c.segmento,
       COUNT(DISTINCT p.id_cliente) AS clientes,
       COUNT(DISTINCT p.id_pedido) AS pedidos,
       SUM(d.precio_unitario * d.cantidad - d.descuento) AS ventas,
       ROUND(SUM(d.precio_unitario * d.cantidad - d.descuento)
             / COUNT(DISTINCT p.id_pedido), 2) AS ticket_promedio
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id_cliente
JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.estado NOT IN ('CANCELED','SUSPECTED_FRAUD')
GROUP BY c.segmento ORDER BY ventas DESC;

-- N7 Visitas frente a ventas por producto, sep 2017 - ene 2018 (Table)
WITH v AS (
  SELECT id_producto,
         COUNT(*) FILTER (WHERE evento = 'vista') AS vistas,
         COUNT(*) FILTER (WHERE evento = 'agregar_carrito') AS carritos
  FROM visita_sin_repetidas GROUP BY id_producto),
s AS (
  SELECT d.id_producto, SUM(d.cantidad) AS unidades
  FROM detalle_pedido d JOIN pedido p ON p.id_pedido = d.id_pedido
  WHERE p.fecha_pedido >= '2017-09-01' AND p.estado NOT IN ('CANCELED','SUSPECTED_FRAUD')
  GROUP BY d.id_producto)
SELECT pr.nombre, v.vistas, v.carritos, COALESCE(s.unidades, 0) AS unidades_vendidas
FROM v JOIN producto pr ON pr.id_producto = v.id_producto
LEFT JOIN s ON s.id_producto = v.id_producto
ORDER BY v.vistas DESC LIMIT 10;

-- N8 Ventas por tipo de pago (Pie chart)
SELECT p.tipo_pago, COUNT(DISTINCT p.id_pedido) AS pedidos,
       SUM(d.precio_unitario * d.cantidad - d.descuento) AS ventas
FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.estado NOT IN ('CANCELED','SUSPECTED_FRAUD')
GROUP BY 1 ORDER BY ventas DESC;

-- ===== BASE DE DATOS =====
-- M1 Uso de conexiones (Gauge, 0 a 100)
SELECT COUNT(*) AS conexiones,
       current_setting('max_connections')::int AS maximo,
       ROUND(100.0 * COUNT(*) / current_setting('max_connections')::int, 2) AS porcentaje
FROM pg_stat_activity;

-- M2 Tamano de la base (Stat, unidad bytes IEC)
SELECT pg_database_size(current_database()) AS bytes;

-- M3 Consultas de larga duracion (Table)
SELECT pid, usename, state, now() - query_start AS duracion,
       LEFT(query, 80) AS consulta
FROM pg_stat_activity
WHERE state <> 'idle' AND now() - query_start > interval '1 minute'
ORDER BY duracion DESC;

-- M4 Sesiones bloqueadas (Stat)
SELECT COUNT(*) AS sesiones_bloqueadas FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;

-- M5 Tuplas muertas por tabla (Bar chart)
SELECT relname AS tabla, n_dead_tup AS tuplas_muertas, n_live_tup AS tuplas_vivas,
       ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS pct_muertas
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 5;