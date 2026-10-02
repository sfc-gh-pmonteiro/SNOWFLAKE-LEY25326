# Ley 25.326 + Snowflake: Guia Completa de Cumplimiento

Entrenamiento paso a paso para implementar cumplimiento con la **Ley 25.326 de 30 de octubre de 2000** (Proteccion de los Datos Personales de Argentina / Ley de Habeas Data) usando recursos nativos de Snowflake. Cubre desde fundamentos legales hasta operacion completa con 9 modulos ejecutables.

---

## Que esta incluido

| Archivo | Descripcion |
|---------|-------------|
| `LEY25326_SNOW.html` | Guia interactiva con teoria, SQL ejecutable y sidebar navegable (dark mode) |
| `LEY25326_SNOW.sql` | SQL consolidado (1100+ lineas) para ejecucion directa en Snowsight |

## Modulos

| # | Modulo | Articulos Ley 25.326 | Recursos Snowflake |
|---|--------|----------------------|-------------------|
| 1 | Fundamentos de la Ley 25.326 | Arts. 1-4 | Vision general de la arquitectura |
| 2 | Gobernanza y RBAC | Arts. 9, 10, 21 | Roles, grants, segregacion de funciones |
| 3 | Clasificacion de Datos | Arts. 2, 7 | `SYSTEM$CLASSIFY`, tags de sistema |
| 4 | Tags Personalizados | Arts. 4, 5, 6 | Object tagging, herencia, bases legales |
| 5 | Enmascaramiento Dinamico | Arts. 9, 10 | Masking policies, tag-based masking |
| 6 | Row Access Policies | Art. 4.3 (finalidad), Art. 9 | RAP, limitacion de finalidad |
| 7 | Projection Policies | Art. 4.1 (proporcionalidad), Art. 7 | Projection policies (FAIL/NULLIFY), proporcionalidad |
| 8 | Derechos del Titular (ARCO) | Arts. 14, 16 | Stored procedures, portabilidad, disociacion |
| 9 | Auditoria y Cumplimiento | Arts. 9, 29, 31 | ACCESS_HISTORY, alertas, reportes |

## Defensa en Profundidad

El entrenamiento implementa tres capas independientes de proteccion en la misma tabla:

```
Capa 1: Row Access Policy    -> filtra FILAS (quien ve cuales registros)
Capa 2: Projection Policy    -> bloquea COLUMNAS en el output (quien ve cuales campos)
Capa 3: Masking Policy        -> transforma VALORES visibles (como aparecen los datos)
```

## Pre-requisitos

- Snowflake Enterprise Edition (o superior)
- Role `ACCOUNTADMIN` o `SYSADMIN` para configuracion inicial
- Snowsight (interfaz web) para ejecucion interactiva

## Como usar

1. **Configure las variables** al inicio del archivo SQL:
   ```sql
   SET LEY25326_USER      = '<SU_USUARIO>';
   SET LEY25326_DPO_EMAIL = '<SU_EMAIL>';
   ```

2. **Ejecute secuencialmente** cada modulo en Snowsight (Modulo 2 antes de 3, etc.)

3. **O abra el HTML** (`LEY25326_SNOW.html`) en el navegador para la guia interactiva con teoria y SQL lado a lado

## Limpieza

Para eliminar todos los objetos creados por el entrenamiento:

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS LEY25326_GOVERNANCE;
DROP DATABASE IF EXISTS EMPRESA_DEMO_AR;
DROP WAREHOUSE IF EXISTS LEY25326_TRAINING_WH;
DROP ROLE IF EXISTS LEY25326_RESPONSABLE_DATOS;
DROP ROLE IF EXISTS LEY25326_PRIVACY_ADMIN;
DROP ROLE IF EXISTS LEY25326_DATA_STEWARD;
DROP ROLE IF EXISTS LEY25326_ANALYST;
DROP ROLE IF EXISTS RRHH_ANALYST;
DROP ROLE IF EXISTS MARKETING_ANALYST;
DROP ROLE IF EXISTS FINANZAS_ANALYST;
DROP NOTIFICATION INTEGRATION IF EXISTS LEY25326_NOTIFICATIONS;
```

## Licencia

[MIT](LICENSE)
