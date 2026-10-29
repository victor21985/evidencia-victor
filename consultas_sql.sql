-- =====================================================================
-- consultas_sql.sql
-- Módulo de análisis de información empresarial en Odoo 19
-- Atlantic Web Consulting S.L. · UF1888
-- =====================================================================


-- =====================================================================
-- BLOQUE A · VERIFICACIÓN DEL CATÁLOGO (tarea 3.7)
-- =====================================================================

-- V1 · La tabla del nuevo modelo existe

SELECT table_name
FROM information_schema.tables
WHERE table_name = 'x_zona_comercial';


-- V2 · Columnas de la tabla nueva

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'x_zona_comercial'
ORDER BY ordinal_position;


-- V3 · Columnas nuevas en cliente y pedido

SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE column_name = 'x_zona_comercial_id'
  AND table_name IN ('res_partner', 'sale_order');


-- V4 · Claves ajenas que apuntan a la zona y su regla de borrado

SELECT conname                    AS restriccion,
       conrelid::regclass         AS tabla,
       confrelid::regclass        AS referencia,
       confdeltype                AS regla_borrado,
       pg_get_constraintdef(oid)  AS definicion
FROM pg_constraint
WHERE contype = 'f'
  AND confrelid = 'x_zona_comercial'::regclass;


-- V5 · Índices de la tabla nueva

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'x_zona_comercial';


-- =====================================================================
-- BLOQUE B · CONSULTAS DE ANÁLISIS (tarea 4)
-- Todas sobre pedidos confirmados (state = 'sale')
-- =====================================================================

-- C1 · Ventas por zona comercial
-- Objetivo: número de pedidos e importe sin impuestos por zona;
--           los clientes sin zona se agrupan como «Sin zona»
-- Tablas:   sale_order → res_partner → x_zona_comercial
-- Clave:    LEFT JOIN con la zona para no perder los clientes sin zona
SELECT COALESCE(z.x_name, 'Sin zona') AS zona,
       COUNT(so.id)                   AS num_pedidos,
       SUM(so.amount_untaxed)         AS importe_sin_impuestos
FROM sale_order so
JOIN res_partner rp          ON rp.id = so.partner_id
LEFT JOIN x_zona_comercial z ON z.id  = rp.x_zona_comercial_id
WHERE so.state = 'sale'
GROUP BY COALESCE(z.x_name, 'Sin zona')
ORDER BY importe_sin_impuestos DESC;


-- C2 · Evolución mensual de las ventas
-- Objetivo: número de pedidos e importe por mes, en orden cronológico
-- Tablas:   sale_order
-- Clave:    date_order se guarda en UTC; se convierte a la hora de
--           Canarias para que el mes coincida con el de Odoo
SELECT TO_CHAR(DATE_TRUNC('month',
         so.date_order AT TIME ZONE 'UTC' AT TIME ZONE 'Atlantic/Canary'),
         'YYYY-MM')            AS mes,
       COUNT(so.id)            AS num_pedidos,
       SUM(so.amount_untaxed)  AS importe_sin_impuestos,
       SUM(so.amount_total)    AS importe_total
FROM sale_order so
WHERE so.state = 'sale'
GROUP BY 1
ORDER BY 1;


-- C3 · Los cinco clientes con mayor importe de compra
-- Objetivo: cliente, zona comercial e importe sin impuestos acumulado
-- Tablas:   sale_order → res_partner → x_zona_comercial
-- Clave:    agrupar por rp.id (no solo por nombre) y limitar a 5 filas
SELECT rp.name                        AS cliente,
       COALESCE(z.x_name, 'Sin zona') AS zona,
       COUNT(so.id)                   AS num_pedidos,
       SUM(so.amount_untaxed)         AS importe_sin_impuestos
FROM sale_order so
JOIN res_partner rp          ON rp.id = so.partner_id
LEFT JOIN x_zona_comercial z ON z.id  = rp.x_zona_comercial_id
WHERE so.state = 'sale'
GROUP BY rp.id, rp.name, z.x_name
ORDER BY importe_sin_impuestos DESC
LIMIT 5;


-- C4 · Búsqueda combinada
-- Objetivo: clientes cuyo nombre contiene una cadena (sin distinguir
--           mayúsculas) y cuyo importe total supera una cifra
-- Parámetros de ejemplo: cadena 'web', importe 1000
-- Tablas:   sale_order → res_partner → x_zona_comercial
-- Clave:    ILIKE para la cadena; HAVING para el total (en WHERE filtraría
--           pedidos sueltos, no el total del cliente)
SELECT rp.name                        AS cliente,
       COALESCE(z.x_name, 'Sin zona') AS zona,
       SUM(so.amount_untaxed)         AS importe_sin_impuestos
FROM sale_order so
JOIN res_partner rp          ON rp.id = so.partner_id
LEFT JOIN x_zona_comercial z ON z.id  = rp.x_zona_comercial_id
WHERE so.state = 'sale'
  AND rp.name ILIKE '%' || 'web' || '%'
GROUP BY rp.id, rp.name, z.x_name
HAVING SUM(so.amount_untaxed) > 1000
ORDER BY importe_sin_impuestos DESC;
