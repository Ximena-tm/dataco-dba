-- Vista con las visitas sin repeticiones exactas (misma IP, producto, minuto y evento)
CREATE VIEW visita_sin_repetidas AS
SELECT DISTINCT ON (id_producto, fecha_hora, ip, evento) *
FROM visita
ORDER BY id_producto, fecha_hora, ip, evento, id_visita;
