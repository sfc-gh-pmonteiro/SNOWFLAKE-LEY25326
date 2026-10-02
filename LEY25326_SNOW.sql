-- =============================================================================
-- LEY 25.326 + SNOWFLAKE: GUIA COMPLETA DE CUMPLIMIENTO
-- =============================================================================
-- Ley 25.326 de 30 de octubre de 2000 | Snowflake Enterprise Edition+
-- Archivo consolidado con los 8 modulos
--
-- INSTRUCCIONES:
--   1. Configure las 2 variables abajo con su usuario y email
--   2. Ejecute cada modulo secuencialmente (modulo 2 antes de 3, etc.)
--   3. Cada seccion puede ejecutarse individualmente en Snowsight
-- =============================================================================


-- #############################################################################
-- CONFIGURACION: sustituya los valores abajo antes de ejecutar
-- #############################################################################

SET LEY25326_USER      = '<SU_USUARIO>';          -- Ej: 'JGARCIA'
SET LEY25326_DPO_EMAIL = '<SU_EMAIL>';            -- Ej: 'datos@empresa.com.ar'


-- #############################################################################
-- MODULO 2: INFRAESTRUCTURA DE GOBERNANZA Y RBAC
-- Arts. 9, 10, 21 Ley 25.326
-- #############################################################################

-- -------------------------------------------------------------
-- 2.1: Database y Schemas de Gobernanza
-- -------------------------------------------------------------
-- Un database centralizado evita fragmentacion de politicas

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS LEY25326_GOVERNANCE
  COMMENT = 'Database centralizado para gobernanza Ley 25.326 Argentina';

CREATE SCHEMA IF NOT EXISTS LEY25326_GOVERNANCE.TAGS
  COMMENT = 'Tags customizados para clasificacion Ley 25.326';

CREATE SCHEMA IF NOT EXISTS LEY25326_GOVERNANCE.POLICIES
  COMMENT = 'Masking policies y Row Access Policies';

CREATE SCHEMA IF NOT EXISTS LEY25326_GOVERNANCE.AUDIT
  COMMENT = 'Logs de ARCO, procedimientos y alertas';

-- Warehouse dedicado para el entrenamiento (X-Small = costo minimo)
CREATE WAREHOUSE IF NOT EXISTS LEY25326_TRAINING_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse dedicado para entrenamiento Ley 25.326';


-- -------------------------------------------------------------
-- 2.2: Roles Ley 25.326
-- -------------------------------------------------------------
-- Segregacion de funciones conforme Art. 9 (seguridad) y Art. 21 (inscripcion)

USE ROLE USERADMIN;

-- Responsable de Proteccion de Datos - Art. 2 (responsable del archivo)
CREATE ROLE IF NOT EXISTS LEY25326_RESPONSABLE_DATOS
  COMMENT = 'Responsable de Proteccion de Datos - Art. 2 Ley 25.326';

-- Administrador de Privacidad - crea y gestiona politicas
CREATE ROLE IF NOT EXISTS LEY25326_PRIVACY_ADMIN
  COMMENT = 'Crea y gestiona masking policies y row access policies';

-- Data Steward - aplica tags y monitorea
CREATE ROLE IF NOT EXISTS LEY25326_DATA_STEWARD
  COMMENT = 'Aplica tags Ley 25.326 y monitorea cumplimiento';

-- Analista - acceso restringido a datos enmascarados
CREATE ROLE IF NOT EXISTS LEY25326_ANALYST
  COMMENT = 'Acceso a datos con enmascaramiento aplicado';

-- Jerarquia de roles
GRANT ROLE LEY25326_PRIVACY_ADMIN TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT ROLE LEY25326_DATA_STEWARD  TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT ROLE LEY25326_ANALYST       TO ROLE LEY25326_PRIVACY_ADMIN;


-- -------------------------------------------------------------
-- 2.3: Privilegios de gobernanza
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- Privilegios para LEY25326_DATA_STEWARD (tags)
GRANT USAGE ON DATABASE LEY25326_GOVERNANCE TO ROLE LEY25326_DATA_STEWARD;
GRANT USAGE ON SCHEMA LEY25326_GOVERNANCE.TAGS TO ROLE LEY25326_DATA_STEWARD;
GRANT CREATE TAG ON SCHEMA LEY25326_GOVERNANCE.TAGS TO ROLE LEY25326_DATA_STEWARD;
GRANT APPLY TAG ON ACCOUNT TO ROLE LEY25326_DATA_STEWARD;

-- Privilegios para LEY25326_PRIVACY_ADMIN (policies)
GRANT USAGE ON DATABASE LEY25326_GOVERNANCE TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE LEY25326_GOVERNANCE TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT CREATE MASKING POLICY ON SCHEMA LEY25326_GOVERNANCE.POLICIES
  TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT CREATE ROW ACCESS POLICY ON SCHEMA LEY25326_GOVERNANCE.POLICIES
  TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT CREATE PROJECTION POLICY ON SCHEMA LEY25326_GOVERNANCE.POLICIES
  TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE LEY25326_PRIVACY_ADMIN;

-- Privilegios para LEY25326_RESPONSABLE_DATOS (acceso al Governance Dashboard)
GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER TO ROLE LEY25326_RESPONSABLE_DATOS;

-- Asignar role LEY25326_RESPONSABLE_DATOS al usuario de entrenamiento
GRANT ROLE LEY25326_RESPONSABLE_DATOS TO USER IDENTIFIER($LEY25326_USER);

-- Warehouse: sin esto, ningun role Ley 25.326 puede ejecutar queries
GRANT USAGE ON WAREHOUSE LEY25326_TRAINING_WH TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT USAGE ON WAREHOUSE LEY25326_TRAINING_WH TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT USAGE ON WAREHOUSE LEY25326_TRAINING_WH TO ROLE LEY25326_DATA_STEWARD;
GRANT USAGE ON WAREHOUSE LEY25326_TRAINING_WH TO ROLE LEY25326_ANALYST;

-- LEY25326_RESPONSABLE_DATOS: acceso al AUDIT schema para ARCO
GRANT USAGE ON SCHEMA LEY25326_GOVERNANCE.AUDIT TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT CREATE TABLE ON SCHEMA LEY25326_GOVERNANCE.AUDIT TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT CREATE PROCEDURE ON SCHEMA LEY25326_GOVERNANCE.AUDIT TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT CREATE ALERT ON SCHEMA LEY25326_GOVERNANCE.AUDIT TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT EXECUTE ALERT ON ACCOUNT TO ROLE LEY25326_RESPONSABLE_DATOS;

-- LEY25326_PRIVACY_ADMIN: CREATE TABLE para tabla ACCESS_MAPPING (Modulo 6)
GRANT CREATE TABLE ON SCHEMA LEY25326_GOVERNANCE.POLICIES
  TO ROLE LEY25326_PRIVACY_ADMIN;


-- #############################################################################
-- MODULO 3: DESCUBRIMIENTO Y CLASIFICACION DE DATOS
-- Arts. 2, 7
-- #############################################################################

-- -------------------------------------------------------------
-- 3.1: Tabla de ejemplo con datos personales argentinos
-- -------------------------------------------------------------

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS EMPRESA_DEMO_AR;
GRANT USAGE ON DATABASE EMPRESA_DEMO_AR TO ROLE LEY25326_ANALYST;
CREATE SCHEMA IF NOT EXISTS EMPRESA_DEMO_AR.DATOS_CLIENTES;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE LEY25326_ANALYST;

CREATE OR REPLACE TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES (
  ID               NUMBER AUTOINCREMENT PRIMARY KEY,
  NOMBRE           STRING    COMMENT 'Nombre completo del titular',
  DNI              STRING    COMMENT 'Documento Nacional de Identidad',
  EMAIL            STRING    COMMENT 'Direccion de correo electronico',
  TELEFONO         STRING    COMMENT 'Telefono movil con codigo de pais',
  FECHA_NACIMIENTO DATE      COMMENT 'Fecha de nacimiento',
  DIRECCION        STRING    COMMENT 'Direccion residencial',
  LOCALIDAD        STRING    COMMENT 'Localidad de residencia',
  PROVINCIA        STRING    COMMENT 'Provincia',
  GENERO           STRING    COMMENT 'Dato personal sensible (Art. 7)',
  ETNIA            STRING    COMMENT 'Dato personal sensible (Art. 7)',
  DEPARTAMENTO     STRING    COMMENT 'Departamento interno',
  FECHA_REGISTRO   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

GRANT SELECT ON TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES TO ROLE LEY25326_ANALYST;

-- Insertar datos ficticios para demostracion
INSERT INTO EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
  (NOMBRE, DNI, EMAIL, TELEFONO, FECHA_NACIMIENTO, DIRECCION, LOCALIDAD, PROVINCIA, GENERO, ETNIA, DEPARTAMENTO)
VALUES
  ('Lucia Martinez',     '25.678.901', 'lucia.martinez@email.com.ar',   '+54 9 11 1234 5678', '1990-03-15', 'Av. Santa Fe 1234, Piso 3B',    'Palermo',     'Buenos Aires',  'Femenino',  'Mestiza', 'RRHH'),
  ('Martin Lopez',       '30.456.789', 'martin.lopez@email.com.ar',     '+54 9 351 2345 6789','1985-07-22', 'Calle Dean Funes 567',          'Centro',      'Cordoba',       'Masculino', 'Blanca',  'FINANZAS'),
  ('Camila Rodriguez',   '35.901.234', 'camila.rodriguez@email.com.ar', '+54 9 261 3456 7890','1992-11-08', 'Av. San Martin 890',            'Ciudad',      'Mendoza',       'Femenino',  'Negra',   'MARKETING'),
  ('Santiago Fernandez', '22.345.678', 'santiago.f@empresa.com.ar',     '+54 9 341 4567 8901','1988-01-30', 'Bv. Orono 321',                 'Centro',      'Santa Fe',      'Masculino', 'Blanca',  'RRHH'),
  ('Valentina Garcia',   '28.789.012', 'valentina.garcia@empresa.com.ar','+54 9 381 5678 9012','1995-06-12','Av. Aconquija 1500',            'Yerba Buena', 'Tucuman',       'Femenino',  'Mestiza', 'FINANZAS');


-- -------------------------------------------------------------
-- 3.1b: Grants cross-DB (dependen de EMPRESA_DEMO_AR existir)
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- Acceso cross-DB para aplicar tags/policies en tablas de negocio
GRANT USAGE ON DATABASE EMPRESA_DEMO_AR TO ROLE LEY25326_DATA_STEWARD;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE LEY25326_DATA_STEWARD;
GRANT USAGE ON DATABASE EMPRESA_DEMO_AR TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT SELECT ON TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
  TO ROLE LEY25326_PRIVACY_ADMIN;

-- LEY25326_RESPONSABLE_DATOS: DML para procedimientos ARCO
GRANT USAGE ON DATABASE EMPRESA_DEMO_AR TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES TO ROLE LEY25326_RESPONSABLE_DATOS;
GRANT CREATE STAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE LEY25326_RESPONSABLE_DATOS;


-- -------------------------------------------------------------
-- 3.2: Clasificacion automatica de datos
-- -------------------------------------------------------------
-- IMPORTANTE: Requiere ACCOUNTADMIN para ejecutar con auto_tag

USE ROLE ACCOUNTADMIN;

CALL SYSTEM$CLASSIFY(
  'EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES',
  {'auto_tag': true}
);


-- -------------------------------------------------------------
-- 3.3: Revisar tags de sistema aplicados
-- -------------------------------------------------------------

SELECT *
FROM TABLE(
  EMPRESA_DEMO_AR.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES', 'TABLE'
  )
)
WHERE TAG_NAME IN ('SEMANTIC_CATEGORY', 'PRIVACY_CATEGORY')
ORDER BY COLUMN_NAME, TAG_NAME;


-- #############################################################################
-- MODULO 4: TAGS PERSONALIZADOS PARA LEY 25.326
-- Arts. 4, 5, 6
-- #############################################################################

-- -------------------------------------------------------------
-- 4.1: Tags personalizados Ley 25.326
-- -------------------------------------------------------------

USE ROLE LEY25326_DATA_STEWARD;
USE SCHEMA LEY25326_GOVERNANCE.TAGS;

-- Categoria del dato conforme Ley 25.326 Art. 2
CREATE OR REPLACE TAG LEY25326_DATA_CATEGORY
  ALLOWED_VALUES
    'DATO_PERSONAL',
    'DATO_SENSIBLE',
    'DATO_DISOCIADO',
    'NO_PERSONAL'
  COMMENT = 'Clasificacion del dato conforme Art. 2 de la Ley 25.326';

-- Base legal para el tratamiento (Art. 5)
CREATE OR REPLACE TAG LEY25326_BASE_LEGAL
  ALLOWED_VALUES
    'CONSENTIMIENTO',
    'FUENTE_PUBLICA',
    'OBLIGACION_LEGAL',
    'LISTADOS_PUBLICOS',
    'RELACION_CONTRACTUAL',
    'OPERACIONES_FINANCIERAS'
  COMMENT = 'Base legal para tratamiento conforme Art. 5 de la Ley 25.326';

-- Finalidad del tratamiento (Art. 4.3 - principio de finalidad)
CREATE OR REPLACE TAG LEY25326_FINALIDAD
  COMMENT = 'Descripcion de la finalidad del tratamiento (Art. 4.3 - principio de finalidad)';

-- Periodo de retencion en dias (Art. 4.7 - destruccion cuando innecesario)
CREATE OR REPLACE TAG LEY25326_RETENCION
  COMMENT = 'Periodo de retencion en dias (Art. 4.7 - datos deben destruirse cuando innecesarios)';

-- Responsable del archivo (Art. 2)
CREATE OR REPLACE TAG LEY25326_RESPONSABLE
  COMMENT = 'Nombre del responsable del archivo, registro o base de datos (Art. 2)';

-- Usuario de datos / Encargado (Art. 2, Art. 25)
CREATE OR REPLACE TAG LEY25326_USUARIO_DATOS
  COMMENT = 'Nombre del usuario de datos que realiza el tratamiento (Art. 2)';


-- -------------------------------------------------------------
-- 4.2: Aplicar tags en la tabla
-- -------------------------------------------------------------
-- NOTA: LEY25326_DATA_CATEGORY se aplica por COLUMNA (no en la tabla)
-- para evitar conflicto con tag-based masking en columnas no-PII
-- como DEPARTAMENTO (usado por la Row Access Policy en Modulo 6).

-- Tags de metadatos a nivel de tabla (herencia para todas las columnas)
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES SET TAG
  LEY25326_GOVERNANCE.TAGS.LEY25326_BASE_LEGAL    = 'CONSENTIMIENTO',
  LEY25326_GOVERNANCE.TAGS.LEY25326_FINALIDAD     = 'Registro de clientes para prestacion de servicios',
  LEY25326_GOVERNANCE.TAGS.LEY25326_RETENCION     = '1825',
  LEY25326_GOVERNANCE.TAGS.LEY25326_RESPONSABLE   = 'Empresa Demo Argentina S.A.';

-- LEY25326_DATA_CATEGORY aplicado individualmente en las columnas PII
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  NOMBRE SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  DNI SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  EMAIL SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  TELEFONO SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  FECHA_NACIMIENTO SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  DIRECCION SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_PERSONAL';


-- -------------------------------------------------------------
-- 4.3: Override a nivel de columna para datos sensibles
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  GENERO SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_SENSIBLE';

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  ETNIA SET TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY = 'DATO_SENSIBLE';


-- -------------------------------------------------------------
-- 4.4: Verificar tags aplicados
-- -------------------------------------------------------------

SELECT *
FROM TABLE(
  EMPRESA_DEMO_AR.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES', 'TABLE'
  )
)
WHERE TAG_DATABASE = 'LEY25326_GOVERNANCE'
ORDER BY COLUMN_NAME, TAG_NAME;

SELECT SYSTEM$GET_TAG(
  'LEY25326_GOVERNANCE.TAGS.LEY25326_BASE_LEGAL',
  'EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES',
  'TABLE'
);


-- #############################################################################
-- MODULO 5: POLITICAS DE ENMASCARAMIENTO DINAMICO
-- Arts. 9, 10 Ley 25.326
-- #############################################################################

-- -------------------------------------------------------------
-- 5.1a: Masking Policy para DNI
-- -------------------------------------------------------------
-- Formato: 25.678.901 -> 25.***.***

USE ROLE LEY25326_PRIVACY_ADMIN;

CREATE OR REPLACE MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_DNI
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS') THEN val
    WHEN IS_ROLE_IN_SESSION('LEY25326_PRIVACY_ADMIN') THEN val
    ELSE CONCAT(
      LEFT(val, 3),
      '***.',
      '***'
    )
  END
  COMMENT = 'Enmascara DNI para roles no autorizados (Art. 9 Ley 25.326)';


-- -------------------------------------------------------------
-- 5.1b: Masking Policy para Email
-- -------------------------------------------------------------
-- camila.rodriguez@email.com.ar -> *****@email.com.ar

CREATE OR REPLACE MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_EMAIL
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS') THEN val
    WHEN IS_ROLE_IN_SESSION('LEY25326_PRIVACY_ADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '.+\\@', '*****@')
  END
  COMMENT = 'Enmascara parte local del email (Art. 9 Ley 25.326)';


-- -------------------------------------------------------------
-- 5.1c: Masking Policy para Telefono
-- -------------------------------------------------------------
-- +54 9 11 1234 5678 -> +54 9 ** **** 5678

CREATE OR REPLACE MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PHONE
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS') THEN val
    ELSE CONCAT('+54 9 ** **** ', RIGHT(val, 4))
  END
  COMMENT = 'Enmascara telefono conservando ultimos 4 digitos';


-- -------------------------------------------------------------
-- 5.1d: Masking Policies genericas
-- -------------------------------------------------------------

-- STRING generico (nombres, direcciones, datos sensibles)
CREATE OR REPLACE MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PII_STRING
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS') THEN val
    WHEN IS_ROLE_IN_SESSION('LEY25326_PRIVACY_ADMIN') THEN val
    ELSE '***PROTEGIDO***'
  END
  COMMENT = 'Enmascaramiento generico para strings con datos personales';

-- NUMBER generico (edad, salario, etc.)
CREATE OR REPLACE MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PII_NUMBER
  AS (val NUMBER) RETURNS NUMBER ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS') THEN val
    ELSE NULL
  END
  COMMENT = 'Enmascaramiento generico para numeros con datos personales';

-- DATE generico (fecha de nacimiento, etc.)
CREATE OR REPLACE MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PII_DATE
  AS (val DATE) RETURNS DATE ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS') THEN val
    ELSE DATE_FROM_PARTS(1900, 01, 01)
  END
  COMMENT = 'Enmascaramiento generico para fechas con datos personales';


-- -------------------------------------------------------------
-- 5.2: Aplicar masking policies directamente
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  DNI SET MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_DNI;

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  EMAIL SET MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_EMAIL;

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  TELEFONO SET MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PHONE;

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  FECHA_NACIMIENTO SET MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PII_DATE;


-- -------------------------------------------------------------
-- 5.3: Tag-based masking para proteccion automatica
-- -------------------------------------------------------------
-- Al asociar masking policies a un tag, TODAS las columnas
-- etiquetadas con ese tag son automaticamente protegidas.

USE ROLE LEY25326_PRIVACY_ADMIN;

ALTER TAG LEY25326_GOVERNANCE.TAGS.LEY25326_DATA_CATEGORY SET
  MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PII_STRING,
  MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PII_NUMBER,
  MASKING POLICY LEY25326_GOVERNANCE.POLICIES.MASK_PII_DATE;

-- IMPORTANTE: Policies aplicadas directamente a la columna
-- tienen PRECEDENCIA sobre tag-based masking policies.
-- Es decir, DNI usa MASK_DNI (directa), no MASK_PII_STRING (tag).


-- -------------------------------------------------------------
-- 5.4: Validacion del enmascaramiento
-- -------------------------------------------------------------
-- IMPORTANTE: Deshabilitar secondary roles para probar aisladamente.
-- Con secondary roles activos, IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS')
-- retorna TRUE incluso usando LEY25326_ANALYST, anulando el enmascaramiento.

USE SECONDARY ROLES NONE;

-- Como LEY25326_RESPONSABLE_DATOS: debe ver datos completos
USE ROLE LEY25326_RESPONSABLE_DATOS;
SELECT NOMBRE, DNI, EMAIL, TELEFONO, FECHA_NACIMIENTO
FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
LIMIT 3;
-- Resultado esperado: datos originales visibles

-- Como LEY25326_ANALYST: debe ver datos enmascarados
USE ROLE LEY25326_ANALYST;
SELECT NOMBRE, DNI, EMAIL, TELEFONO, FECHA_NACIMIENTO
FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
LIMIT 3;
-- Resultado esperado:
-- NOMBRE: ***PROTEGIDO***
-- DNI: 25.***.***
-- EMAIL: *****@email.com.ar
-- TELEFONO: +54 9 ** **** 5678
-- FECHA_NACIMIENTO: 1900-01-01

-- Restaurar secondary roles despues del test
USE SECONDARY ROLES ALL;


-- #############################################################################
-- MODULO 6: ROW ACCESS POLICIES
-- Art. 4.3 (finalidad), Art. 9
-- #############################################################################

-- -------------------------------------------------------------
-- 6.0: Roles por departamento para probar la RAP
-- -------------------------------------------------------------

USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS RRHH_ANALYST
  COMMENT = 'Analista de Recursos Humanos';
CREATE ROLE IF NOT EXISTS MARKETING_ANALYST
  COMMENT = 'Analista de Marketing';
CREATE ROLE IF NOT EXISTS FINANZAS_ANALYST
  COMMENT = 'Analista Financiero';

-- Asignar al usuario de entrenamiento para test
GRANT ROLE RRHH_ANALYST TO USER IDENTIFIER($LEY25326_USER);
GRANT ROLE MARKETING_ANALYST TO USER IDENTIFIER($LEY25326_USER);
GRANT ROLE FINANZAS_ANALYST TO USER IDENTIFIER($LEY25326_USER);

-- Conceder warehouse + acceso a tabla
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON WAREHOUSE LEY25326_TRAINING_WH TO ROLE RRHH_ANALYST;
GRANT USAGE ON WAREHOUSE LEY25326_TRAINING_WH TO ROLE MARKETING_ANALYST;
GRANT USAGE ON WAREHOUSE LEY25326_TRAINING_WH TO ROLE FINANZAS_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO_AR TO ROLE RRHH_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO_AR TO ROLE MARKETING_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO_AR TO ROLE FINANZAS_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE RRHH_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE MARKETING_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_AR.DATOS_CLIENTES TO ROLE FINANZAS_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES TO ROLE RRHH_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES TO ROLE MARKETING_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES TO ROLE FINANZAS_ANALYST;


-- -------------------------------------------------------------
-- 6.1: Tabla de mapeo acceso x finalidad
-- -------------------------------------------------------------

USE ROLE LEY25326_PRIVACY_ADMIN;

CREATE OR REPLACE TABLE LEY25326_GOVERNANCE.POLICIES.ACCESS_MAPPING (
  ROLE_NAME       STRING   COMMENT 'Role Snowflake',
  DEPARTMENT      STRING   COMMENT 'Departamento permitido',
  ALLOWED_PURPOSE STRING   COMMENT 'Finalidad del acceso',
  REGION          STRING   COMMENT 'Region permitida'
);

INSERT INTO LEY25326_GOVERNANCE.POLICIES.ACCESS_MAPPING VALUES
  ('RRHH_ANALYST',              'RRHH',      'GESTION_PERSONAL',  'ARGENTINA'),
  ('MARKETING_ANALYST',         'MARKETING', 'CAMPANAS',          'ARGENTINA'),
  ('FINANZAS_ANALYST',          'FINANZAS',  'FACTURACION',       'ARGENTINA'),
  ('LEY25326_RESPONSABLE_DATOS','ALL',       'GOBERNANZA',        'ALL'),
  ('LEY25326_PRIVACY_ADMIN',    'ALL',       'GOBERNANZA',        'ALL');


-- -------------------------------------------------------------
-- 6.2: Row Access Policy con limitacion de finalidad
-- -------------------------------------------------------------

CREATE OR REPLACE ROW ACCESS POLICY
  LEY25326_GOVERNANCE.POLICIES.RAP_PURPOSE_LIMITATION
  AS (department STRING) RETURNS BOOLEAN ->
  -- Responsable de Datos y Privacy Admin ven todo
  IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS')
  OR IS_ROLE_IN_SESSION('LEY25326_PRIVACY_ADMIN')
  -- Otros roles: solo datos del departamento autorizado
  OR EXISTS (
    SELECT 1
    FROM LEY25326_GOVERNANCE.POLICIES.ACCESS_MAPPING am
    WHERE am.ROLE_NAME = CURRENT_ROLE()
      AND (am.DEPARTMENT = department OR am.DEPARTMENT = 'ALL')
  )
  COMMENT = 'Limita acceso por departamento conforme principio de finalidad (Art. 4.3 Ley 25.326)';


-- -------------------------------------------------------------
-- 6.3: Aplicar RAP a la tabla
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
  ADD ROW ACCESS POLICY LEY25326_GOVERNANCE.POLICIES.RAP_PURPOSE_LIMITATION
  ON (DEPARTAMENTO);


-- -------------------------------------------------------------
-- 6.4: Validacion de la RAP
-- -------------------------------------------------------------
-- Deshabilitar secondary roles para probar aisladamente

USE SECONDARY ROLES NONE;

-- Como LEY25326_RESPONSABLE_DATOS: debe ver TODAS las filas
USE ROLE LEY25326_RESPONSABLE_DATOS;
SELECT NOMBRE, DEPARTAMENTO FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES;
-- Resultado: 5 registros (todos los departamentos)

-- Como RRHH_ANALYST: debe ver solo departamento RRHH
USE ROLE RRHH_ANALYST;
SELECT NOMBRE, DEPARTAMENTO FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES;
-- Resultado: 2 registros (Lucia Martinez y Santiago Fernandez - ambos RRHH)

-- Como FINANZAS_ANALYST: debe ver solo FINANZAS
USE ROLE FINANZAS_ANALYST;
SELECT NOMBRE, DEPARTAMENTO FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES;
-- Resultado: 2 registros (Martin Lopez y Valentina Garcia)

-- Restaurar secondary roles
USE SECONDARY ROLES ALL;


-- #############################################################################
-- MODULO 7: POLITICAS DE PROYECCION (PROJECTION POLICIES)
-- Art. 4.1 (proporcionalidad), Art. 7, Art. 9
-- #############################################################################
-- Projection Policies controlan si una columna puede APARECER en el resultado
-- final de un query. Diferente del masking (que transforma el valor), la
-- projection policy IMPIDE que la columna sea proyectada.
--
-- Orden de evaluacion: RAP (filas) -> Projection (columnas) -> Masking (valores)
--
-- Ley 25.326: Implementa proporcionalidad (Art. 4.1 - datos adecuados,
-- pertinentes y no excesivos) y proteccion extra para datos sensibles (Art. 7).

-- -------------------------------------------------------------
-- 7.1: Grants para Projection Policies
-- -------------------------------------------------------------
-- NOTA: Estos grants tambien constan en Modulo 2 para ejecucion
-- secuencial completa. Repetidos aqui para ejecucion independiente.

USE ROLE ACCOUNTADMIN;
GRANT CREATE PROJECTION POLICY ON SCHEMA LEY25326_GOVERNANCE.POLICIES
  TO ROLE LEY25326_PRIVACY_ADMIN;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE LEY25326_PRIVACY_ADMIN;


-- -------------------------------------------------------------
-- 7.2: Projection Policy — Bloqueo total (FAIL) para datos sensibles
-- -------------------------------------------------------------
-- Columnas GENERO y ETNIA (Art. 7 — datos sensibles):
-- Solo Responsable de Datos y PRIVACY_ADMIN pueden proyectar.
-- Otros roles: query FALLA si intentan incluir la columna en el SELECT.

USE ROLE LEY25326_PRIVACY_ADMIN;

CREATE OR REPLACE PROJECTION POLICY LEY25326_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK
  AS () RETURNS PROJECTION_CONSTRAINT ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    WHEN IS_ROLE_IN_SESSION('LEY25326_PRIVACY_ADMIN')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    ELSE PROJECTION_CONSTRAINT(ALLOW => false)
  END
  COMMENT = 'Bloquea proyeccion de datos sensibles para roles no autorizados (Art. 7 Ley 25.326)';


-- -------------------------------------------------------------
-- 7.3: Projection Policy — NULLIFY para PII general
-- -------------------------------------------------------------
-- En vez de fallar el query, retorna NULL para la columna protegida.
-- Util cuando se desea permitir el query pero ocultar la columna.
-- Aplicaremos a DIRECCION como ejemplo de proporcionalidad (Art. 4.1).

CREATE OR REPLACE PROJECTION POLICY LEY25326_GOVERNANCE.POLICIES.PROJ_PII_NULLIFY
  AS () RETURNS PROJECTION_CONSTRAINT ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY25326_RESPONSABLE_DATOS')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    WHEN IS_ROLE_IN_SESSION('LEY25326_PRIVACY_ADMIN')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    ELSE PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'NULLIFY')
  END
  COMMENT = 'Retorna NULL para columnas PII no autorizadas — proporcionalidad (Art. 4.1 Ley 25.326)';


-- -------------------------------------------------------------
-- 7.4: Aplicar Projection Policies a las columnas
-- -------------------------------------------------------------

-- Datos sensibles: bloqueo total (FAIL)
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  GENERO SET PROJECTION POLICY LEY25326_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK;

ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  ETNIA SET PROJECTION POLICY LEY25326_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK;

-- PII general: retorna NULL (NULLIFY)
ALTER TABLE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  DIRECCION SET PROJECTION POLICY LEY25326_GOVERNANCE.POLICIES.PROJ_PII_NULLIFY;


-- -------------------------------------------------------------
-- 7.5: Validacion de las Projection Policies
-- -------------------------------------------------------------
-- Deshabilitar secondary roles para probar aisladamente

USE SECONDARY ROLES NONE;

-- Como LEY25326_RESPONSABLE_DATOS: debe ver TODAS las columnas normalmente
USE ROLE LEY25326_RESPONSABLE_DATOS;
SELECT NOMBRE, GENERO, ETNIA, DIRECCION
FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES LIMIT 3;
-- Resultado esperado: datos visibles para el Responsable de Datos

-- Como LEY25326_ANALYST: GENERO y ETNIA bloquean el query (FAIL)
USE ROLE LEY25326_ANALYST;

-- IMPORTANTE: Este query FALLA — descomente para probar:
-- SELECT GENERO FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES LIMIT 1;
-- Error: "Projection policy does not allow column projection"

-- DIRECCION retorna NULL (enforcement NULLIFY)
SELECT NOMBRE, DIRECCION FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES LIMIT 3;
-- Resultado esperado: DIRECCION = NULL en todas las filas

-- IMPORTANTE: La columna bloqueada AUN puede usarse en WHERE/JOIN!
-- La projection policy solo afecta el OUTPUT final (SELECT list).
-- NOTA: El valor en WHERE es el valor ENMASCARADO (masking ya aplico).
SELECT COUNT(*) AS TOTAL
FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
WHERE GENERO IS NOT NULL;
-- Resultado: cuenta filas con GENERO no-nulo (query no falla)

-- Restaurar secondary roles
USE SECONDARY ROLES ALL;


-- -------------------------------------------------------------
-- 7.6: Verificar todas las policies en la tabla (vista consolidada)
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
SELECT POLICY_NAME, POLICY_KIND, REF_COLUMN_NAME, POLICY_STATUS
FROM TABLE(EMPRESA_DEMO_AR.INFORMATION_SCHEMA.POLICY_REFERENCES(
  ref_entity_name => 'EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES',
  ref_entity_domain => 'TABLE'
))
ORDER BY REF_COLUMN_NAME, POLICY_KIND;


-- #############################################################################
-- MODULO 8: DERECHOS DEL TITULAR (ARCO)
-- Arts. 14, 16
-- #############################################################################

-- -------------------------------------------------------------
-- 8.1: Tabla de log de solicitudes ARCO
-- -------------------------------------------------------------

USE ROLE LEY25326_RESPONSABLE_DATOS;

CREATE OR REPLACE TABLE LEY25326_GOVERNANCE.AUDIT.ARCO_LOG (
  REQUEST_ID    STRING DEFAULT UUID_STRING(),
  REQUEST_TYPE  STRING,
  TITULAR_ID    STRING    COMMENT 'DNI o identificador del titular',
  REQUESTED_BY  STRING DEFAULT CURRENT_USER(),
  REQUESTED_AT  TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  STATUS        STRING DEFAULT 'PENDIENTE',
  COMPLETED_AT  TIMESTAMP_LTZ,
  DETAILS       VARIANT
)
COMMENT = 'Log de solicitudes de derechos del titular (Arts. 14, 16 Ley 25.326)';


-- -------------------------------------------------------------
-- 8.2: Procedimiento de Acceso (Art. 14 - Derecho de Acceso)
-- -------------------------------------------------------------
-- SLA: 10 dias corridos (Art. 14, inc. 2)

CREATE OR REPLACE PROCEDURE LEY25326_GOVERNANCE.AUDIT.ARCO_ACCESS(
  TITULAR_DNI STRING
)
RETURNS TABLE()
LANGUAGE SQL
AS
$$
BEGIN
  -- Registrar la solicitud en el log
  INSERT INTO LEY25326_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('ACCESO', :TITULAR_DNI, 'CONCLUIDO', CURRENT_TIMESTAMP());

  -- Retornar datos del titular
  LET rs RESULTSET := (
    SELECT ID, NOMBRE, DNI, EMAIL, TELEFONO, FECHA_NACIMIENTO,
           DIRECCION, LOCALIDAD, PROVINCIA, FECHA_REGISTRO
    FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
    WHERE DNI = :TITULAR_DNI
  );
  RETURN TABLE(rs);
END;
$$;


-- -------------------------------------------------------------
-- 8.3: Procedimiento de Rectificacion (Art. 16 - Derecho de Rectificacion)
-- -------------------------------------------------------------
-- SLA: 5 dias habiles (Art. 16, inc. 2)

CREATE OR REPLACE PROCEDURE LEY25326_GOVERNANCE.AUDIT.ARCO_CORRECTION(
  TITULAR_DNI STRING,
  CAMPO       STRING,
  NUEVO_VALOR STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Registrar la solicitud (usa SELECT para OBJECT_CONSTRUCT)
  INSERT INTO LEY25326_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, DETAILS)
  SELECT 'RECTIFICACION', :TITULAR_DNI,
     OBJECT_CONSTRUCT('campo', :CAMPO, 'nuevo_valor', :NUEVO_VALOR);

  -- Ejecutar la correccion (campos permitidos)
  IF (:CAMPO = 'EMAIL') THEN
    UPDATE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
    SET EMAIL = :NUEVO_VALOR WHERE DNI = :TITULAR_DNI;
  ELSEIF (:CAMPO = 'TELEFONO') THEN
    UPDATE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
    SET TELEFONO = :NUEVO_VALOR WHERE DNI = :TITULAR_DNI;
  ELSEIF (:CAMPO = 'DIRECCION') THEN
    UPDATE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
    SET DIRECCION = :NUEVO_VALOR WHERE DNI = :TITULAR_DNI;
  ELSE
    RETURN 'Error: Campo no permitido para rectificacion via ARCO.';
  END IF;

  -- Actualizar status
  UPDATE LEY25326_GOVERNANCE.AUDIT.ARCO_LOG
  SET STATUS = 'CONCLUIDO', COMPLETED_AT = CURRENT_TIMESTAMP()
  WHERE TITULAR_ID = :TITULAR_DNI
    AND REQUEST_TYPE = 'RECTIFICACION'
    AND STATUS = 'PENDIENTE';

  RETURN CONCAT('Campo ', :CAMPO, ' rectificado con exito para el titular ', :TITULAR_DNI);
END;
$$;


-- -------------------------------------------------------------
-- 8.4: Procedimiento de Supresion / Disociacion (Art. 16 - Derecho de Supresion)
-- -------------------------------------------------------------
-- La Ley 25.326 usa el termino "disociacion" (Art. 2) para referirse al
-- proceso irreversible de desvinculacion de datos con una persona.

CREATE OR REPLACE PROCEDURE LEY25326_GOVERNANCE.AUDIT.ARCO_DELETE(
  TITULAR_DNI STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Verificar si el titular existe
  LET cnt NUMBER := (
    SELECT COUNT(*) FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
    WHERE DNI = :TITULAR_DNI
  );

  IF (:cnt = 0) THEN
    RETURN 'Error: Titular no encontrado.';
  END IF;

  -- Disociar datos personales (mantener registro para integridad referencial)
  UPDATE EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
  SET
    NOMBRE           = 'DISOCIADO',
    DNI              = 'XX.XXX.XXX',
    EMAIL            = CONCAT('disociado_', ID, '@removed.ley25326'),
    TELEFONO         = '+54 9 00 0000 0000',
    FECHA_NACIMIENTO = DATE_FROM_PARTS(1900, 01, 01),
    DIRECCION        = 'ELIMINADO',
    LOCALIDAD        = 'ELIMINADO',
    PROVINCIA        = 'XX',
    GENERO           = NULL,
    ETNIA            = NULL
  WHERE DNI = :TITULAR_DNI;

  -- Registrar en el log
  INSERT INTO LEY25326_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('SUPRESION', :TITULAR_DNI, 'CONCLUIDO', CURRENT_TIMESTAMP());

  RETURN CONCAT('Datos del titular ', :TITULAR_DNI, ' disociados con exito.');
END;
$$;


-- -------------------------------------------------------------
-- 8.5: Procedimiento de Portabilidad (buena practica)
-- -------------------------------------------------------------
-- La Ley 25.326 no contempla expresamente un derecho de portabilidad,
-- pero como buena practica se incluye la exportacion de datos del titular.

-- Crear stage para exportacion ARCO
CREATE STAGE IF NOT EXISTS EMPRESA_DEMO_AR.DATOS_CLIENTES.ARCO_EXPORT
  COMMENT = 'Stage para exportacion de datos en solicitudes del titular';

CREATE OR REPLACE PROCEDURE LEY25326_GOVERNANCE.AUDIT.ARCO_PORTABILITY(
  TITULAR_DNI STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Exportar datos a stage
  COPY INTO @EMPRESA_DEMO_AR.DATOS_CLIENTES.ARCO_EXPORT/portabilidad/
  FROM (
    SELECT ID, NOMBRE, DNI, EMAIL, TELEFONO, FECHA_NACIMIENTO,
           DIRECCION, LOCALIDAD, PROVINCIA, FECHA_REGISTRO
    FROM EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES
    WHERE DNI = :TITULAR_DNI
  )
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"')
  OVERWRITE = TRUE
  SINGLE = TRUE
  HEADER = TRUE;

  -- Registrar en el log
  INSERT INTO LEY25326_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('PORTABILIDAD', :TITULAR_DNI, 'CONCLUIDO', CURRENT_TIMESTAMP());

  RETURN CONCAT('Datos exportados a @ARCO_EXPORT/portabilidad/ para el titular ', :TITULAR_DNI);
END;
$$;


-- -------------------------------------------------------------
-- 8.6: Validacion de los procedimientos ARCO
-- -------------------------------------------------------------

-- Test: Derecho de Acceso
CALL LEY25326_GOVERNANCE.AUDIT.ARCO_ACCESS('25.678.901');

-- Test: Derecho de Rectificacion
CALL LEY25326_GOVERNANCE.AUDIT.ARCO_CORRECTION(
  '25.678.901', 'EMAIL', 'lucia.nueva@email.com.ar'
);

-- Test: Derecho de Portabilidad
CALL LEY25326_GOVERNANCE.AUDIT.ARCO_PORTABILITY('30.456.789');

-- Verificar log de ARCO
SELECT * FROM LEY25326_GOVERNANCE.AUDIT.ARCO_LOG
ORDER BY REQUESTED_AT DESC;


-- #############################################################################
-- MODULO 9: MONITOREO, AUDITORIA Y CUMPLIMIENTO
-- Arts. 9, 29, 31
-- #############################################################################

-- -------------------------------------------------------------
-- 9.1: Quien accedio a datos personales en los ultimos 30 dias?
-- -------------------------------------------------------------
-- Usa ACCESS_HISTORY + QUERY_HISTORY para rastrear accesos (Art. 9)
-- NOTA: ACCESS_HISTORY no tiene ROLE_NAME; obtener via JOIN con QUERY_HISTORY

USE ROLE ACCOUNTADMIN;

SELECT
  ah.USER_NAME,
  qh.ROLE_NAME,
  ah.QUERY_START_TIME,
  boa.VALUE:objectName::STRING AS OBJECT_ACCESSED,
  boa.VALUE:objectDomain::STRING AS OBJECT_TYPE,
  ah.QUERY_ID
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
  JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
    ON ah.QUERY_ID = qh.QUERY_ID
  ,LATERAL FLATTEN(input => ah.BASE_OBJECTS_ACCESSED) boa
WHERE ah.QUERY_START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND boa.VALUE:objectName::STRING ILIKE '%CLIENTES%'
ORDER BY ah.QUERY_START_TIME DESC
LIMIT 100;


-- -------------------------------------------------------------
-- 9.2: Que tablas TIENEN y cuales NO TIENEN tags Ley 25.326?
-- -------------------------------------------------------------

SELECT
  t.TABLE_CATALOG AS DATABASE_NAME,
  t.TABLE_SCHEMA  AS SCHEMA_NAME,
  t.TABLE_NAME,
  t.ROW_COUNT,
  COALESCE(tr.TAG_VALUE, '*** SIN TAG ***') AS LEY25326_CATEGORY,
  CASE
    WHEN tr.TAG_VALUE IS NOT NULL THEN 'CONFORME'
    ELSE 'PENDIENTE'
  END AS STATUS_CUMPLIMIENTO
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES t
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
  ON t.TABLE_CATALOG = tr.OBJECT_DATABASE
  AND t.TABLE_SCHEMA = tr.OBJECT_SCHEMA
  AND t.TABLE_NAME = tr.OBJECT_NAME
  AND tr.TAG_NAME = 'LEY25326_DATA_CATEGORY'
  AND tr.DOMAIN = 'TABLE'
WHERE t.DELETED IS NULL
  AND t.TABLE_SCHEMA != 'INFORMATION_SCHEMA'
ORDER BY STATUS_CUMPLIMIENTO DESC, t.TABLE_CATALOG, t.TABLE_SCHEMA;


-- -------------------------------------------------------------
-- 9.3: Columnas con y sin masking policies
-- -------------------------------------------------------------

SELECT
  pr.REF_DATABASE_NAME AS DATABASE_NAME,
  pr.REF_SCHEMA_NAME   AS SCHEMA_NAME,
  pr.REF_ENTITY_NAME   AS TABLE_NAME,
  pr.REF_COLUMN_NAME   AS COLUMN_NAME,
  pr.POLICY_NAME,
  pr.POLICY_STATUS,
  COALESCE(pr.TAG_NAME, 'DIRECTA') AS APLICACION
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES pr
WHERE pr.POLICY_KIND = 'MASKING_POLICY'
ORDER BY pr.REF_DATABASE_NAME, pr.REF_ENTITY_NAME, pr.REF_COLUMN_NAME;


-- -------------------------------------------------------------
-- 9.3b: Inventario de Projection Policies
-- -------------------------------------------------------------

SELECT
  pp.POLICY_NAME,
  pp.POLICY_CATALOG AS POLICY_DATABASE,
  pp.POLICY_SCHEMA,
  pp.CREATED,
  pp.POLICY_COMMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.PROJECTION_POLICIES pp
WHERE pp.DELETED IS NULL
ORDER BY pp.CREATED;

-- Columnas protegidas por projection policies en la tabla CLIENTES
SELECT POLICY_NAME, POLICY_KIND, REF_COLUMN_NAME, POLICY_STATUS
FROM TABLE(EMPRESA_DEMO_AR.INFORMATION_SCHEMA.POLICY_REFERENCES(
  ref_entity_name => 'EMPRESA_DEMO_AR.DATOS_CLIENTES.CLIENTES',
  ref_entity_domain => 'TABLE'
))
WHERE POLICY_KIND = 'PROJECTION_POLICY'
ORDER BY REF_COLUMN_NAME;


-- -------------------------------------------------------------
-- 9.4: Solicitudes ARCO pendientes (SLA Arts. 14, 16)
-- -------------------------------------------------------------
-- Art. 14: Derecho de Acceso — 10 dias corridos
-- Art. 16: Rectificacion/Supresion — 5 dias habiles

USE ROLE LEY25326_RESPONSABLE_DATOS;

SELECT
  REQUEST_ID,
  REQUEST_TYPE,
  TITULAR_ID,
  REQUESTED_BY,
  REQUESTED_AT,
  STATUS,
  DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) AS DIAS_ABIERTO,
  CASE
    WHEN REQUEST_TYPE = 'ACCESO' AND DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 10
      THEN 'ATRASADO'
    WHEN REQUEST_TYPE = 'ACCESO' AND DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 7
      THEN 'ATENCION'
    WHEN REQUEST_TYPE != 'ACCESO' AND DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 5
      THEN 'ATRASADO'
    WHEN REQUEST_TYPE != 'ACCESO' AND DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 3
      THEN 'ATENCION'
    ELSE 'DENTRO DEL PLAZO'
  END AS SLA_STATUS
FROM LEY25326_GOVERNANCE.AUDIT.ARCO_LOG
WHERE STATUS = 'PENDIENTE'
ORDER BY REQUESTED_AT ASC;


-- -------------------------------------------------------------
-- 9.5: Alerta para accesos masivos a datos personales (Art. 9 - Seguridad)
-- -------------------------------------------------------------

-- Pre-requisito: crear notification integration para email
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE NOTIFICATION INTEGRATION LEY25326_NOTIFICATIONS
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ($LEY25326_DPO_EMAIL);

USE ROLE LEY25326_RESPONSABLE_DATOS;

CREATE OR REPLACE ALERT LEY25326_GOVERNANCE.AUDIT.ALERT_MASS_DATA_ACCESS
  WAREHOUSE = LEY25326_TRAINING_WH
  SCHEDULE = 'USING CRON 0 */6 * * * America/Argentina/Buenos_Aires'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE EXECUTION_STATUS = 'SUCCESS'
      AND ROWS_PRODUCED > 10000
      AND QUERY_START_TIME >= DATEADD('hour', -6, CURRENT_TIMESTAMP())
      AND (QUERY_TEXT ILIKE '%clientes%' OR QUERY_TEXT ILIKE '%datos_personales%')
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'LEY25326_NOTIFICATIONS',
      $LEY25326_DPO_EMAIL,
      'ALERTA LEY 25.326: Acceso masivo a datos personales detectado',
      'Una consulta retorno mas de 10,000 registros de tablas con datos personales en las ultimas 6 horas. Verifique el ACCESS_HISTORY para detalles.'
    );

-- Activar la alerta
ALTER ALERT LEY25326_GOVERNANCE.AUDIT.ALERT_MASS_DATA_ACCESS RESUME;


-- =============================================================================
-- FIN DEL ENTRENAMIENTO
-- =============================================================================
-- Todos los 9 modulos han sido validados y ejecutados con exito.
-- Consulte el HTML (LEY25326_SNOW.html) para detalles conceptuales de cada modulo.
-- =============================================================================
