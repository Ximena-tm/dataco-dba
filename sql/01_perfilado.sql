-- Conteos de las tablas de staging
SELECT 'ventas' AS tabla, count(*) AS filas FROM staging.ventas
UNION ALL SELECT 'visitas', count(*) FROM staging.visitas;

-- Dependencias funcionales: 0 violaciones = se cumple
SELECT 'order_id -> type' AS dependencia, count(*) AS violaciones FROM (
  SELECT order_id FROM staging.ventas GROUP BY order_id HAVING count(DISTINCT type) > 1) t
UNION ALL SELECT 'order_id -> delivery_status', count(*) FROM (
  SELECT order_id FROM staging.ventas GROUP BY order_id HAVING count(DISTINCT delivery_status) > 1) t
UNION ALL SELECT 'order_id -> days_for_shipping_real', count(*) FROM (
  SELECT order_id FROM staging.ventas GROUP BY order_id HAVING count(DISTINCT days_for_shipping_real) > 1) t
UNION ALL SELECT 'order_id -> late_delivery_risk', count(*) FROM (
  SELECT order_id FROM staging.ventas GROUP BY order_id HAVING count(DISTINCT late_delivery_risk) > 1) t
UNION ALL SELECT '(order_state, order_country) -> order_region', count(*) FROM (
  SELECT order_state, order_country FROM staging.ventas GROUP BY 1,2 HAVING count(DISTINCT order_region) > 1) t
UNION ALL SELECT 'order_region -> market', count(*) FROM (
  SELECT order_region FROM staging.ventas GROUP BY 1 HAVING count(DISTINCT market) > 1) t
UNION ALL SELECT 'order_country -> order_region (debe fallar)', count(*) FROM (
  SELECT order_country FROM staging.ventas GROUP BY 1 HAVING count(DISTINCT order_region) > 1) t;




SELECT count(*) FROM staging.ventas;