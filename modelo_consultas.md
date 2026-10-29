# Modelo consultas

### Análisis del modelo y de las fuentes con esquema de relaciones

|Objeto funcional | Modelo en Odoo|Tabla PostgreSQL|Campos para el análisis|PK| Claves ajenas FK|Relaciones de cardinalidad|
|---|---|---|---|---|---|---|
|Cliente| res.partner|res_partner|name, is_company, parent_id, x_zona_comercial| id| parent_id -> res_partner; x_zona_comercial_id -> x_zona_comercial|Many2one a zona (N:1); One2many sale_order_ids(1:N pedidos)|
Pedido de venta|sale.order|sale_order|name, partner_id, date_order, state, user_id, amount_untaxed, amount_total, x_zona_comercial_id| id| partner_id -> res_partner; user_id -> res_user; company_id -> res_company; x_zona_comercial_id -> x_zona_comerecial| Many2one a cliente (N:1); One2many a order_line(1:N líneas)|
Línea de pedido|sale.order.line|sale_order_line|order_id, product_id, product_uom_qty, price_unit, price_subtotal, price_total| id|order_id -> sale_order(borrado en cascada); product_id -> product_product| Many2one a pedido(N:1) y a producto(N:1)|
Servicio (variante)|product.product|product_product|product_tmpl_id, default_code| id| product_tmpl_id -> product_template | Many2one a plantilla (N:1)|
Servicio (plantilla)|product.template|product_template|name, type = "service", list_price| id| --| One2many a product_variant_ids(1:N variantes)|
Zona comercial|x_zona_comercial| x_zona_comercial|x_name, x_codigo, x_descripcion, x_active| id| --| 1:N clientes |
|


## Consulta 1 con el ORM: pedidos confirmados agrupados por zona comercial

**Modelo:** `sale.order`  
**Dominio:** `[('state', '=', 'sale')]`  
**Método:** `search` + recorrido de relaciones

```python
pedidos = env['sale.order'].search([
    ('state', '=', 'sale')
])

totales = {}

for pedido in pedidos:
    zona = pedido.x_zona_comercial_id.x_name or 'Sin zona'
    datos = totales.setdefault(zona, [0, 0.0])
    datos[0] += 1
    datos[1] += pedido.amount_untaxed

lineas = [
    '%s: %d pedidos · %.2f €' % (zona, datos[0], datos[1])
    for zona, datos in sorted(
        totales.items(),
        key=lambda x: x[1][1],
        reverse=True
    )
]

action = {
    'type': 'ir.actions.client',
    'tag': 'display_notification',
    'params': {
        'title': 'Ventas por zona (ORM)',
        'message': ' | '.join(lineas),
        'sticky': True,
        'type': 'info',
    },
}
```