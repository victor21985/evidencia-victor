# Informe final · Módulo de análisis de información empresarial

Odoo 19 Community · Atlantic Web Consulting S.L.
Tareas 3, 5, 9 y 10

> Los valores entre corchetes `[ ]` dependen de cada base y se rellenan con los datos propios.

---

## 1. Situación inicial

| Elemento | Situación |
| --- | --- |
| Sistema | Odoo 19 Community, base individual `[nombre de la base]` |
| Aplicaciones instaladas | Ventas, Contactos, `base_automation` (Reglas de automatización) |
| Base de datos | PostgreSQL 16, consulta desde pgAdmin (solo SELECT) |
| Usuario | `[usuario]`, con permisos de administración y modo desarrollador activo |
| Datos de partida | Datos de demostración: [n.º] clientes, [n.º] servicios, [n.º] pedidos confirmados |
| Carencia detectada | Los pedidos no tienen ninguna dimensión geográfica o comercial por la que agrupar las ventas |

---

## 2. Objetos creados y modificados

### 2.1 Modelo nuevo: Zona comercial

| Atributo | Valor |
| --- | --- |
| Descripción | Zona comercial |
| Modelo | `x_zona_comercial` |
| Tabla PostgreSQL | `x_zona_comercial` |
| Clave primaria | `id` (la crea el ORM) |

| Campo | Etiqueta | Tipo | Obligatorio | Indexado | Valor por defecto |
| --- | --- | --- | --- | --- | --- |
| `x_name` | Nombre | Char | Sí | No | — |
| `x_codigo` | Código | Char | Sí | Sí | — |
| `x_descripcion` | Descripción | Text | No | No | — |
| `x_active` | Activo | Boolean | No | No | Verdadero |

`x_active` es el campo de archivado: las zonas con valor falso dejan de mostrarse sin borrarse. Por eso su valor por defecto es Verdadero.

### 2.2 Campo nuevo en el cliente (`res.partner`)

| Atributo | Valor |
| --- | --- |
| Nombre | `x_zona_comercial_id` |
| Etiqueta | Zona comercial |
| Tipo | many2one |
| Modelo relacionado | `x_zona_comercial` |
| Al eliminar | Restringir |
| Almacenado | Sí |

### 2.3 Campo nuevo en el pedido de venta (`sale.order`)

| Atributo | Valor |
| --- | --- |
| Nombre | `x_zona_comercial_id` |
| Etiqueta | Zona comercial |
| Tipo | many2one |
| Modelo relacionado | `x_zona_comercial` |
| Campo relacionado | `partner_id.x_zona_comercial_id` |
| Almacenado | Sí |
| Solo lectura | Sí |

### 2.4 Pantallas de mantenimiento

| Elemento | Nombre | Detalle |
| --- | --- | --- |
| Vista de lista | `x_zona_comercial.list` | Código, nombre, descripción, activo |
| Vista de formulario | `x_zona_comercial.form` | Código y nombre a la izquierda, activo a la derecha, descripción debajo |
| Acción de ventana | Zonas comerciales | Modelo `x_zona_comercial`, modo `list,form` |
| Menú | Zonas comerciales | Padre: Ventas/Configuración |
| Vista heredada | `res.partner.form.zona_comercial` | Extiende `base.view_partner_form` en modo Extensión |

Arquitectura de la vista heredada:

```xml
<data>
    <xpath expr="//field[@name='category_id']" position="after">
        <field name="x_zona_comercial_id" options="{'no_create': True}"/>
    </xpath>
</data>
```

### 2.5 Permisos de acceso

| Nombre | Grupo | Leer | Escribir | Crear | Eliminar |
| --- | --- | --- | --- | --- | --- |
| zona_comercial_usuario | Usuario interno | Sí | No | No | No |
| zona_comercial_responsable | Ventas / Administrador | Sí | Sí | Sí | Sí |
| zona_comercial_ajustes | Administración / Ajustes | Sí | Sí | Sí | Sí |

**Finalidad.** Cualquier usuario interno necesita leer las zonas: si no, al abrir un cliente o un pedido con zona recibiría un error de acceso. 

---

## 3. Relaciones y validaciones

### 3.1 Relación cliente–zona

Muchos clientes pertenecen a una misma zona: es una relación **N:1**. En el ORM se representa con un campo **Many2one** en el lado N, el cliente. El ORM crea la columna `res_partner.x_zona_comercial_id` y una clave ajena hacia `x_zona_comercial(id)`.

La opción **«Al eliminar: Restringir»** genera `ON DELETE RESTRICT`: PostgreSQL rechaza borrar una zona mientras algún cliente la tenga asignada. Las otras dos opciones no cumplen el requisito:
- «Establecer NULL» dejaría a los clientes sin zona;
- «En cascada» borraría los clientes.

### 3.2 Zona en el pedido: relacionado y almacenado

El pedido toma la zona de su cliente. Si el campo **no estuviera almacenado**, se calcularía cada vez que se lee y no existiría en la tabla. En ese caso no se podría:
- agrupar por él en la tabla dinámica, el gráfico o la búsqueda;
- consultarlo desde SQL.

Al almacenarlo se crea la columna `sale_order.x_zona_comercial_id`. El ORM la recalcula sola cuando cambia la zona del cliente o el cliente del pedido.

### 3.3 Código único: regla de automatización

| Atributo | Valor |
| --- | --- |
| Nombre | Código de zona único |
| Modelo | Zona comercial (`x_zona_comercial`) |
| Disparador | Al crear y actualizar |
| Campos que disparan la regla | `x_codigo` |
| Acción | Ejecutar código Python |

```python
# Rechaza un código de zona que ya exista, incluso en zonas archivadas
for record in records:
    if not record.x_codigo:
        continue
    duplicados = env['x_zona_comercial'].with_context(active_test=False).search_count([
        ('x_codigo', '=ilike', record.x_codigo.strip()),
        ('id', '!=', record.id),
    ])
    if duplicados:
        raise UserError("El código de zona «%s» ya existe. Utilice otro código." % record.x_codigo)
```

**Qué problema evita.** Sin la regla podrían existir dos zonas con el mismo código. Entonces el código dejaría de identificar la zona y los informes por código mezclarían datos.

**Diferencia con una restricción UNIQUE**

| | Regla de automatización | Restricción UNIQUE |
| --- | --- | --- |
| Nivel | Aplicación (ORM de Odoo) | Base de datos (PostgreSQL) |
| Cuándo actúa | Al crear o modificar desde Odoo | En cualquier escritura, venga de donde venga |
| Qué puede saltarla | Escrituras directas con SQL, procesos que desactiven las automatizaciones, dos altas simultáneas | Nada |
| Datos ya existentes | No los revisa | No se puede crear si ya hay duplicados |
| Mensaje | Personalizado, en lenguaje de negocio | Error técnico |
| Dónde se ve | Ajustes › Técnico › Reglas de automatización | `pg_constraint` (tipo `u`) |

El modo desarrollador no permite crear restricciones UNIQUE en PostgreSQL. Por eso la unicidad se garantiza con la regla. La consulta V5 lo confirma: el índice sobre `x_codigo` no es único.

---

## 4. Consulta mediante el ORM (tarea 5)

| Atributo | Valor |
| --- | --- |
| Acción de servidor | Ventas por zona (ORM) |
| Modelo | Pedido de venta (`sale.order`) |
| Tipo | Ejecutar código |
| Cómo se lanza | Lista de pedidos › Acción › Ventas por zona (ORM) |

```python
# Consulta 1 con el ORM: pedidos confirmados agrupados por zona comercial
# Modelo: sale.order · Dominio: [('state', '=', 'sale')] · Método: search
pedidos = env['sale.order'].search([('state', '=', 'sale')])
totales = {}
for pedido in pedidos:
    zona = pedido.x_zona_comercial_id.x_name or 'Sin zona'
    datos = totales.setdefault(zona, [0, 0.0])
    datos[0] += 1
    datos[1] += pedido.amount_untaxed
lineas = [
    '%s: %d pedidos · %.2f €' % (zona, datos[0], datos[1])
    for zona, datos in sorted(totales.items(), key=lambda x: x[1][1], reverse=True)
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

| Elemento | SQL (consulta C1) | ORM (acción de servidor) |
| --- | --- | --- |
| Origen | `sale_order` JOIN `res_partner` LEFT JOIN `x_zona_comercial` | Modelo `sale.order` |
| Filtro | `WHERE so.state = 'sale'` | Dominio `[('state', '=', 'sale')]` |
| Relación con la zona | JOIN explícitos | `pedido.x_zona_comercial_id.x_name` |
| Agrupación | `GROUP BY` | Diccionario en Python |
| Resultado de [zona] | [n.º] pedidos · [importe] € | [n.º] pedidos · [importe] € |
| ¿Coinciden? | | [Sí / No, porque…] |

---

## 5. Procedimiento seguido

1. Activar el modo desarrollador: Ajustes › Activar el modo desarrollador.
2. Comprobar que `base_automation` está instalado: Aplicaciones, quitar el filtro «Aplicaciones», buscar «Automation».
3. Crear el modelo `x_zona_comercial` y sus campos: Ajustes › Técnico › Estructura de la base de datos › Modelos.
4. Fijar Verdadero como valor por defecto de `x_active`.
5. Crear los derechos de acceso del modelo: Ajustes › Técnico › Seguridad › Derechos de acceso.
6. Crear el campo `x_zona_comercial_id` en `res.partner`, con «Al eliminar: Restringir»: Ajustes › Técnico › Estructura de la base de datos › Campos.
7. Crear la regla de automatización del código único: Ajustes › Técnico › Automatización › Reglas de automatización.
8. Crear el campo relacionado y almacenado `x_zona_comercial_id` en `sale.order`.
9. Crear las vistas de lista y formulario de la zona: Ajustes › Técnico › Interfaz de usuario › Vistas.
10. Crear la acción de ventana «Zonas comerciales» y su menú bajo Ventas/Configuración.
11. Crear la vista heredada del formulario de contacto.
12. Recargar el navegador con Ctrl+F5 y comprobar las pantallas.
13. Crear tres zonas y asignarlas a clientes con pedidos confirmados.
14. Hacer las pruebas de integridad (apartado 6).
15. Verificar en pgAdmin con las consultas V1 a V5 (archivo `consultas_sql.sql`).
16. Crear y ejecutar la acción de servidor ORM y contrastarla con C1.
17. Crear las vistas de análisis, su acción y su menú (ver `diseno_informes.md`).

---

## 6. Pruebas de integridad

| N.º | Prueba | Resultado esperado | Resultado obtenido | Captura |
| --- | --- | --- | --- | --- |
| I1 | Crear una zona con el código «[código existente]» | Mensaje «El código de zona … ya existe»; la zona no se guarda | [resultado] | `capturas/[archivo]` |
| I2 | Crear una zona con el mismo código en minúsculas | Mismo mensaje | [resultado] | `capturas/[archivo]` |
| I3 | Cambiar el código de una zona por uno existente | Mismo mensaje; el cambio no se guarda | [resultado] | `capturas/[archivo]` |
| I4 | Eliminar la zona «[zona]», que tiene clientes | Error: otro registro depende de ella; la zona sigue existiendo | [resultado] | `capturas/[archivo]` |
| I5 | Eliminar una zona sin clientes (control) | Se elimina sin error | [resultado] | `capturas/[archivo]` |

**Verificación en PostgreSQL**

| Consulta | Resultado obtenido |
| --- | --- |
| V1 · Tabla | [resultado] |
| V2 · Columnas | [resultado] |
| V3 · Columnas en cliente y pedido | [resultado] |
| V4 · Claves ajenas y regla de borrado | `res_partner_x_zona_comercial_id_fkey` · regla `[r]` |
| V5 · Índices | `x_zona_comercial_pkey` y `[nombre del índice sobre x_codigo]` (no único) |

---

## 7. Documentación consultada

| Fuente | Apartado | Para qué se utilizó |
| --- | --- | --- |
| Documentación de Odoo 19 (inglés) · Developer › Reference › Backend › ORM API | Fields: Many2one, related, store, ondelete | Definir la relación y el campo relacionado (pasos 3.2 y 3.4) |
| Documentación de Odoo 19 · ORM API | Search domains; Model methods: search | Escribir el dominio y la búsqueda de la acción de servidor (tarea 5) |
| Documentación de Odoo 19 · User interface › View architectures | List, Pivot, Graph, Search | Diseñar las vistas de análisis (tarea 6) |
| Documentación de Odoo 19 · User interface › View records | Inheritance, xpath, priority | Vista heredada del cliente y prioridad de las vistas |
| Documentación de Odoo 19 · Backend › Actions | Window actions, Server actions | Contexto `search_default_*` y variables `env`, `records` y `action` |
| Documentación de PostgreSQL 16 · System Catalogs | pg_constraint, pg_indexes | Consultas V4 y V5 |
| Documentación de PostgreSQL 16 · The Information Schema | tables, columns | Consultas V1 a V3 |
| Documentación de PostgreSQL 16 · Functions and Operators | date_trunc, AT TIME ZONE, ILIKE | Consultas C2 y C4 |



---

## 8. Incidencias y soluciones

| N.º | Incidencia | Causa | Solución aplicada | Comprobación |
| --- | --- | --- | --- | --- |
| 1 | [Ej.: las zonas creadas no aparecían en la lista] | [`x_active` vacío: Odoo las trataba como archivadas] | [Valor por defecto Verdadero y reactivación desde el filtro «Archivado»] | [Las tres zonas se ven en la lista] |
| 2 | [Ej.: el menú Zonas comerciales no aparecía] | [El modelo no tenía derechos de acceso] | [Crear las líneas de acceso y recargar con Ctrl+F5] | [El menú aparece en Ventas › Configuración] |
|