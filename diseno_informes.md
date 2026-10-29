# Diseño de informes · Análisis de ventas

Módulo de análisis de información empresarial en Odoo 19 · Atlantic Web Consulting S.L.
Tareas 6, 7 y 8

> Los valores entre corchetes `[ ]` dependen de los datos de cada base y se rellenan con los resultados propios.

---

## 1. Componente «Análisis de ventas»

El análisis se publica como una opción de menú en **Ventas › Informes › Análisis de ventas**. Abre una acción de ventana sobre los pedidos de venta (`sale.order`) con cuatro vistas propias: lista, tabla dinámica, gráfico y búsqueda.

| Elemento | Nombre | Tipo | Modelo |
| --- | --- | --- | --- |
| Vista de lista | `x_sale_order.analisis.list` | Lista | `sale.order` |
| Vista de tabla dinámica | `x_sale_order.analisis.pivot` | Pivot | `sale.order` |
| Vista de gráfico | `x_sale_order.analisis.graph` | Gráfico | `sale.order` |
| Vista de búsqueda | `x_sale_order.analisis.search` | Búsqueda | `sale.order` |
| Acción de ventana | Análisis de ventas | `ir.actions.act_window` | `sale.order` |
| Menú | Análisis de ventas | `ir.ui.menu` | Padre: Ventas / Informes |

**Prioridad de las vistas: 99.** Las cuatro son vistas primarias nuevas sobre `sale.order`. Con la prioridad por defecto (16) podrían sustituir a las vistas estándar de Ventas. Con prioridad 99 solo se usan cuando la acción las nombra expresamente.

---

## 2. Diseño de cada vista

### 2.1 Vista de lista

| Aspecto | Diseño |
| --- | --- |
| Finalidad | Consultar los pedidos uno a uno y servir de base para exportar |
| Campos | Pedido, cliente, zona comercial, fecha, comercial, importe sin impuestos, importe total |
| Medidas | Suma de importe sin impuestos y suma de importe total al pie de la lista |
| Particularidades | `create="0"`: desde el análisis no se crean pedidos |

```xml
<list string="Análisis de ventas" create="0">
    <field name="name"/>
    <field name="partner_id"/>
    <field name="x_zona_comercial_id"/>
    <field name="date_order"/>
    <field name="user_id"/>
    <field name="amount_untaxed" sum="Total sin impuestos"/>
    <field name="amount_total" sum="Total" optional="show"/>
</list>
```

### 2.2 Vista de tabla dinámica (pivot)

| Aspecto | Diseño |
| --- | --- |
| Finalidad | Cruzar zona comercial y periodo |
| Filas | Zona comercial (`x_zona_comercial_id`) |
| Columnas | Mes de la fecha del pedido (`date_order`, intervalo mensual) |
| Medida | Importe sin impuestos (`amount_untaxed`) |
| Totales | Por fila, por columna y total general (los añade Odoo) |

```xml
<pivot string="Análisis de ventas">
    <field name="x_zona_comercial_id" type="row"/>
    <field name="date_order" interval="month" type="col"/>
    <field name="amount_untaxed" type="measure"/>
</pivot>
```

### 2.3 Vista de gráfico

| Aspecto | Diseño |
| --- | --- |
| Finalidad | Comparar de un vistazo el importe de cada zona |
| Tipo | Barras (`type="bar"`) |
| Dimensión (eje) | Zona comercial |
| Medida | Importe sin impuestos |

```xml
<graph string="Importe por zona comercial" type="bar">
    <field name="x_zona_comercial_id"/>
    <field name="amount_untaxed" type="measure"/>
</graph>
```

### 2.4 Vista de búsqueda

| Tipo de elemento | Nombre técnico | Etiqueta | Definición |
| --- | --- | --- | --- |
| Criterio de búsqueda | `partner_id` | Cliente | Campo |
| Criterio de búsqueda | `x_zona_comercial_id` | Zona comercial | Campo |
| Filtro | `confirmados` | Pedidos confirmados | `[('state', '=', 'sale')]` · activo por defecto |
| Filtro | `mas_1000` | Más de 1.000 € | `[('amount_untaxed', '>', 1000)]` |
| Agrupación | `agrupar_zona` | Zona comercial | `group_by: x_zona_comercial_id` |
| Agrupación | `agrupar_cliente` | Cliente | `group_by: partner_id` |
| Agrupación | `agrupar_mes` | Mes | `group_by: date_order:month` |

```xml
<search string="Análisis de ventas">
    <field name="partner_id"/>
    <field name="x_zona_comercial_id"/>
    <filter name="confirmados" string="Pedidos confirmados"
            domain="[('state', '=', 'sale')]"/>
    <separator/>
    <filter name="mas_1000" string="Más de 1.000 €"
            domain="[('amount_untaxed', '&gt;', 1000)]"/>
    <group string="Agrupar por">
        <filter name="agrupar_zona" string="Zona comercial"
                context="{'group_by': 'x_zona_comercial_id'}"/>
        <filter name="agrupar_cliente" string="Cliente"
                context="{'group_by': 'partner_id'}"/>
        <filter name="agrupar_mes" string="Mes"
                context="{'group_by': 'date_order:month'}"/>
    </group>
</search>
```

El `<separator/>` coloca los dos filtros en grupos distintos, de modo que se combinan con **Y**. Sin él, dos filtros del mismo grupo se combinan con **O**.

---

## 3. Acción de ventana y menú

**Acción de ventana** (Ajustes › Técnico › Acciones › Acciones de ventana)

| Atributo | Valor |
| --- | --- |
| Nombre de la acción | Análisis de ventas |
| Modelo de objeto | `sale.order` |
| Modo de vista | `list,pivot,graph` |
| Vistas (pestaña Vistas) | lista → `x_sale_order.analisis.list` · pivot → `x_sale_order.analisis.pivot` · gráfico → `x_sale_order.analisis.graph` |
| Vista de búsqueda | `x_sale_order.analisis.search` |
| Dominio | vacío |
| Contexto | `{'search_default_confirmados': 1}` |

El contexto `search_default_confirmados` activa el filtro «Pedidos confirmados» al abrir la acción. El dominio se deja vacío para que el usuario pueda quitar el filtro y ver también los presupuestos.

**Menú** (Ajustes › Técnico › Interfaz de usuario › Elementos de menú)

| Atributo | Valor |
| --- | --- |
| Menú | Análisis de ventas |
| Menú padre | Ventas/Informes |
| Acción | `ir.actions.act_window` · Análisis de ventas |
| Secuencia | 10 |

---

## 4. Pruebas realizadas (tarea 7)

Datos de prueba: [n.º] zonas, [n.º] clientes con zona, [n.º] cliente sin zona y [n.º] pedidos confirmados entre [mes inicial] y [mes final].

| N.º | Prueba | Dato esperado | Dato obtenido | Resultado |
| --- | --- | --- | --- | --- |
| P1 | Celda [zona] × [mes] de la tabla dinámica | [importe] € (consulta A2) | [importe] € | [Correcto / Incorrecto] |
| P2 | Total de la zona [zona] | [importe] € (consulta C1) | [importe] € | [Correcto / Incorrecto] |
| P3 | Fila «Ninguno» del pivot frente a «Sin zona» | [importe] € (consulta C1) | [importe] € | [Correcto / Incorrecto] |
| P4 | El filtro «Pedidos confirmados» está activo al abrir | Filtro marcado, [n.º] pedidos | [n.º] pedidos | [Correcto / Incorrecto] |
| P5 | Quitar el filtro «Pedidos confirmados» | Aparecen también los presupuestos ([n.º] en total) | [n.º] | [Correcto / Incorrecto] |
| P6 | Filtro «Más de 1.000 €» junto con «Confirmados» | [n.º] pedidos, todos > 1.000 € | [n.º] | [Correcto / Incorrecto] |
| P7 | Búsqueda por cliente «[nombre]» | [n.º] pedidos de ese cliente | [n.º] | [Correcto / Incorrecto] |
| P8 | Búsqueda por zona «[zona]» | [n.º] pedidos de esa zona | [n.º] | [Correcto / Incorrecto] |
| P9 | Agrupar por zona comercial | Mismos grupos e importes que C1 | [resultado] | [Correcto / Incorrecto] |
| P10 | Agrupar por cliente | Los cinco primeros coinciden con C3 | [resultado] | [Correcto / Incorrecto] |
| P11 | Agrupar por mes | Mismos meses e importes que C2 | [resultado] | [Correcto / Incorrecto] |
| P12 | Gráfico de barras | Una barra por zona con el importe de C1 | [resultado] | [Correcto / Incorrecto] |
| P13 | Cambiar la zona de [cliente] de [zona A] a [zona B] | El importe del cliente pasa de [zona A] a [zona B] en el pivot | [resultado] | [Correcto / Incorrecto] |

**Por qué funciona la prueba P13.** En el pedido, `x_zona_comercial_id` es un campo relacionado y almacenado con origen `partner_id.x_zona_comercial_id`. Al guardar el cliente con la zona nueva, el ORM recalcula ese campo en todos sus pedidos.

**Diferencias detectadas y explicación:** [describir aquí cualquier diferencia entre el pivot y SQL y su causa; por ejemplo, la zona horaria en la agrupación por mes o los pedidos de otra compañía].

---

## 5. Procedimiento de exportación (tarea 8)

1. Abrir **Ventas › Informes › Análisis de ventas** con el filtro «Pedidos confirmados» activo.
2. Pasar a la vista de **tabla dinámica** y comprobar que tiene zonas en filas, meses en columnas e importe sin impuestos como medida.
3. Desplegar todas las filas y columnas para que la exportación incluya todos los grupos.
4. Pulsar el botón de **descarga (XLSX)** de la barra de la tabla dinámica.
5. Abrir el archivo en la hoja de cálculo y comprobar:
   - que la primera fila contiene los encabezados de los meses;
   - que hay una fila por zona, incluida la fila sin zona;
   - que hay una columna de total y una fila de total;
   - que los importes son números (alineados a la derecha) y no texto.
6. Guardar el archivo como `exportacion_analisis.xlsx` en la carpeta `evidencias/`.

**Alternativa desde la lista:** agrupar la vista de lista por zona comercial, seleccionar todos los registros y usar **Acción › Exportar**. Elegir el formato XLSX, añadir los campos Cliente, Zona comercial, Fecha del pedido, Comercial e Importe sin impuestos y pulsar Exportar.

Comprobación del resultado: el total general del archivo es [importe] €, que coincide con la suma de la consulta C1.