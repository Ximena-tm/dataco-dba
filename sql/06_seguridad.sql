-- Seguridad con minimo privilegio Ejecutar con el usuario maestro.
-- Las contrasenas NO van en este archivo

-- Paso 1. Quitar lo automatico de PUBLIC
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE dataco FROM PUBLIC;

-- Paso 2. Roles por proposito (sin LOGIN)
CREATE ROLE readonly NOLOGIN;
CREATE ROLE readwrite NOLOGIN;

-- readonly: solo consulta
GRANT CONNECT ON DATABASE dataco TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO readonly;

-- readwrite: consulta y modifica datos (no crea objetos)
GRANT CONNECT ON DATABASE dataco TO readwrite;
GRANT USAGE ON SCHEMA public TO readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO readwrite;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO readwrite;

-- Paso 3. Usuarios finales (sin contrasena aqui)
CREATE USER reporting_user1;
CREATE USER app_user1;
CREATE USER grafana_user;
GRANT readonly  TO reporting_user1;
GRANT readwrite TO app_user1;
GRANT readonly  TO grafana_user;

-- Paso 4. Verificacion de roles
SELECT r.rolname AS usuario,
       COALESCE(string_agg(g.rolname, ', ' ORDER BY g.rolname), '(sin roles)') AS roles
FROM pg_roles r
LEFT JOIN pg_auth_members m ON m.member = r.oid
LEFT JOIN pg_roles g ON g.oid = m.roleid
WHERE r.rolname IN ('reporting_user1', 'app_user1', 'grafana_user')
GROUP BY r.rolname;