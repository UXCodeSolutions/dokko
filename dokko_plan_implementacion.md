# Dokko — Plan de Implementación Maestro

**Cómo usar este documento:** cada fase es autocontenida y aprobable de forma independiente. Copia el contenido de una fase completa como prompt para tu agente de código. No avances a la siguiente fase hasta validar los criterios de aceptación de la actual. El orden importa — cada fase asume que las anteriores están terminadas.

---

## 0. Principios no negociables (aplican a TODAS las fases)

1. **Aislamiento de tenant absoluto.** Ninguna query, ninguna pantalla, ningún estado en memoria mezcla datos de dos tenants. Toda tabla de negocio lleva `tenant_id NOT NULL` + política RLS.
2. **El tenant nunca sabe que existen otros módulos.** El código de un módulo no activo no se importa ni se instancia.
3. **Todo dato sensible pasa por el core, nunca se duplica.** Auth, usuarios, tenants, facturación viven en `core`, no en cada módulo.
4. **Ningún módulo importa código de otro módulo directamente.** Solo pueden importar de `core/` y `shared_components/`.
5. **Todo botón que dispare una acción irreversible (eliminar, cancelar, desactivar) exige confirmación en un modal**, nunca ejecuta directo al clic.
6. **Todo estado de carga tiene loading state explícito (skeleton), todo estado vacío tiene empty state diseñado.** Ninguna pantalla se entrega "en blanco" mientras carga o sin datos.
7. **Gestión de estado:** Riverpod en toda la app. Un `Notifier`/`AsyncNotifier` por entidad principal de cada módulo (ej. `MembersNotifier`, `PropertiesNotifier`). Nunca `setState` local para datos que vienen del backend — solo para estado de UI puramente visual (ej. si un acordeón está abierto).
8. **Todas las transiciones de pantalla:** `fadeThrough` de 200ms entre rutas del mismo nivel; `slideFromRight` de 250ms al entrar a un detalle (ej. lista de miembros → detalle de miembro); `slideUp` con `Curves.easeOutCubic` de 300ms para modales/bottom sheets.
9. **Cada fase termina con:** el build corre sin errores, la pantalla es navegable desde el punto de entrada correcto, y los datos mostrados vienen de Supabase real (no hardcodeados), salvo que la fase diga explícitamente "con datos mock".

---

## 1. Sistema de diseño — especificación de componentes base

Esto se construye UNA vez en `core/widgets/` y se reutiliza en todos los módulos. Ninguna pantalla futura debe crear un botón o input distinto a estos.

### Tokens (`core/theme/dokko_tokens.dart`)
```
Colores base (fijos, no cambian por tenant):
  --bg: #0A0A0B
  --surface: #111113
  --surface-2: #0D0D0E
  --line: rgba(255,255,255,0.07)
  --line-strong: rgba(255,255,255,0.13)
  --text: #EDEDEF
  --text-2: #8B8B92
  --text-3: #5C5C63
  --green (éxito): #3ECF8E
  --amber (alerta): #E2A33E
  --red (peligro): #E5484D

Color variable por tenant:
  --accent: viene de tenants.brand_config.primary_color
  --accent-dim: --accent al 14% de opacidad, generado automáticamente

Tipografía:
  Familia única: Inter (pesos 400/500/600/700)
  Escala: 11 / 12 / 13 / 14 (base) / 16 / 19 / 24 / 32
  Todo número monetario/cantidad usa tabular-nums

Espaciado (escala de 4px):
  4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 40 / 56

Radios:
  sm: 5px (badges, chips)
  md: 7px (botones, inputs)
  lg: 10px (paneles, cards)

Elevación: NO se usan sombras. Toda separación es border de 1px (--line) o cambio de --surface.
```

### DokkoButton — 3 variantes, 4 estados
- **Primary:** fondo `--text` (blanco/casi-blanco), texto `--bg`. Usar solo UNA vez por pantalla — la acción principal.
- **Secondary:** fondo `--surface`, borde `--line-strong`, texto `--text-2`. Para acciones secundarias (filtros, "esta semana").
- **Ghost/Link:** sin fondo ni borde, texto `--text-2`, subrayado solo en hover. Para acciones dentro de filas (ej. "Recordar", "Ver detalle").
- Estados: `default`, `hover` (surface se aclara 4%), `disabled` (opacidad 40%, cursor not-allowed), `loading` (texto reemplazado por spinner de 14px, botón no clickeable).
- Altura fija: 34px. Padding horizontal: 12px. Border-radius: `md`.

### DokkoInput
- Label arriba (12px, `--text-2`), input debajo (36px alto, fondo `--surface`, borde `--line`).
- Estado focus: borde cambia a `--accent`.
- Estado error: borde `--red`, mensaje de error en 11.5px `--red` debajo del input.
- Placeholder siempre en `--text-3`, nunca como reemplazo del label (accesibilidad).

### DokkoCard / Panel
- Igual al patrón ya usado en el mockup v3: `border: 1px solid --line`, `border-radius: lg`, sin sombra.
- Header interno opcional: `padding: 13px 18px`, fondo `--surface-2`, borde inferior `--line`, título en 12.5px semibold MAYÚSCULAS con letter-spacing 0.02em.

### DokkoTable (para listas densas — miembros, propiedades, leads)
- Fila: 44px de alto mínimo, borde superior `--line` (excepto la primera fila).
- Header de tabla: sticky al hacer scroll, fondo `--surface-2`, texto 11px `--text-2` mayúsculas.
- Hover de fila: fondo `--surface` sutil.
- Cada fila clickeable navega al detalle — el cursor cambia a pointer en toda la fila, no solo en un botón.
- Selección múltiple (para acciones masivas): checkbox aparece SOLO al hacer hover sobre la fila o si ya hay una fila seleccionada — no ocupa espacio visual por defecto.
- Paginación: 25 filas por página por defecto, controles abajo a la derecha, nunca scroll infinito (dificulta encontrar datos específicos en software de gestión).

### DokkoModal
- Fondo oscurecido `rgba(0,0,0,0.6)` con blur sutil.
- Modal: `--surface`, `border-radius: lg`, ancho máximo 480px para confirmaciones, 720px para formularios.
- Todo modal de acción destructiva (eliminar, cancelar): título en `--red`, botón primary también en `--red`, botón secondary "Cancelar" a la izquierda.
- Cierre: click fuera del modal O tecla Esc — ambos deben funcionar.

### DokkoBadge/Tag
- Uso exclusivo para estado (vencimiento, prioridad) — nunca decorativo.
- Ámbar = atención/pendiente. Rojo = urgente/vencido. Verde = completado/activo. Gris (`--text-3` sobre `--surface`) = neutral/informativo.

### Empty states (patrón fijo)
- Ícono de línea fina centrado (24px, `--text-3`) + texto de 1 línea explicando por qué está vacío + botón primary con la acción para llenarlo (ej. "Aún no tienes miembros" + botón "Registrar primer miembro").

### Loading states
- Skeleton con el mismo layout exacto de la pantalla final (mismas proporciones de card/fila), relleno `--surface` pulsando opacidad entre 100%-60% cada 1.2s. Nunca un spinner genérico centrado en pantalla en blanco.

**Criterio de aceptación de esta fase:** los 6 componentes existen en `core/widgets/`, documentados con un archivo de preview (`widgetbook` o pantalla de desarrollo interna) que muestra todos los estados de cada uno.

---

## 2. Mapa de navegación (referencia para todas las fases siguientes)

| Origen | Botón/Acción | Destino | Transición |
|---|---|---|---|
| Login | Submit exitoso | Dashboard del módulo activo | fadeThrough |
| Sidebar item | Click en cualquier ítem | Ruta raíz de esa sección | fadeThrough |
| Dashboard → fila de "vencen esta semana" | Click en fila completa | Detalle del miembro/lead | slideFromRight |
| Detalle → botón "Editar" | Click | Formulario de edición (mismo layout, campos editables) | ninguna (in-place) |
| Detalle → botón "Eliminar"/"Cancelar" | Click | DokkoModal de confirmación | slideUp |
| Modal confirmación → botón primary rojo | Click | Ejecuta acción, cierra modal, toast de confirmación, refresca lista | — |
| Lista (tabla) → botón "+ Nuevo X" | Click | DokkoModal de formulario (720px) o pantalla completa si el formulario es largo (>6 campos) | slideUp / slideFromRight |
| Cualquier formulario → "Guardar" exitoso | Click | Toast de éxito + regresa a la lista/detalle anterior con el dato ya reflejado | — |
| Cualquier formulario → "Cancelar" | Click | Regresa sin guardar, sin confirmación si no hay cambios; CON confirmación si hay cambios sin guardar | — |
| Super-admin → tenant → "Modo soporte" | Click | Banner persistente arriba de toda la pantalla indicando "Estás en modo soporte de [tenant]" + acceso de solo lectura a sus datos | fadeThrough |

**Regla general:** ninguna acción que modifique datos ocurre sin que el usuario reciba feedback visual en menos de 300ms (loading state en el botón mismo, no un spinner aparte).

---

## FASE 0 — Setup del proyecto
**Objetivo:** repositorio, entorno, dependencias base, sin pantallas todavía.
**Incluye:**
- Proyecto Flutter nuevo, target desktop (macOS/Windows/Linux habilitados)
- Dependencias: `riverpod`, `go_router`, `supabase_flutter`, `google_fonts` (o fuente Inter embebida localmente para no depender de red)
- Proyecto FastAPI nuevo, estructura de carpetas según lo definido (`core/`, `modules/`)
- Proyecto Supabase creado, conexión probada desde ambos lados
- `.env` / gestión de secretos (nunca credenciales hardcodeadas)
**Criterio de aceptación:** `flutter run -d macos` (o el OS que uses) abre una ventana en blanco sin errores. FastAPI responde `200` en un endpoint `/health`. Supabase conectado y verificado con una tabla de prueba.

## FASE 1 — Esquema core en Supabase
**Objetivo:** todas las tablas del core, con RLS activo desde el día 1 (nunca se desarrolla sin RLS "para agregarlo después").
**Incluye:** `account_owners`, `tenants` (con `brand_config JSONB`, `module_slug`), `tenant_users`, `subscriptions`, `payments`, `audit_log`, función `auth.tenant_id()`, función `auth.is_super_admin()`.
**Criterio de aceptación:** insertar 2 tenants de prueba, verificar con 2 usuarios distintos que ninguno puede ver filas del otro vía query directa a Supabase (no solo "la app no lo muestra" — la DB debe bloquearlo).

## FASE 2 — Autenticación y sesión
**Incluye:** pantalla de login (email + password, sin registro público — los usuarios los crea el super-admin), manejo de JWT/sesión con Supabase Auth, `authProvider` en Riverpod, redirect automático si no hay sesión.
**Botones de esta pantalla:** "Iniciar sesión" (primary, loading state mientras autentica), "¿Olvidaste tu contraseña?" (link, dispara flujo de reset por email).
**Criterio de aceptación:** login exitoso redirige al dashboard del módulo correcto según el tenant; login fallido muestra error inline bajo el campo de password, no un alert genérico.

## FASE 3 — Sistema de diseño (ver sección 1 completa)
**Criterio de aceptación:** el ya descrito arriba.

## FASE 4 — App shell, router y module registry
**Incluye:** `ModuleDefinition`, `availableModules`, `activeModuleProvider`, `GoRouter` raíz con inyección dinámica de rutas del módulo activo, sidebar que se renderiza según el módulo (ítems de nav definidos por cada `ModuleDefinition`).
**Criterio de aceptación:** cambiar el `module_slug` de un tenant de prueba en la DB y volver a hacer login debe mostrar un sidebar completamente distinto sin tocar código.

## FASE 5 — Super-admin: tenants y account owners
**Pantallas:** login separado de super-admin (con 2FA), lista de tenants (tabla con filtros por módulo/estado), formulario de creación de tenant (incluye subida de logo + extracción automática de color + preview + ajuste manual), lista de account owners con sus tenants asociados.
**Botones clave:** "+ Nuevo tenant" (primary, abre formulario completo, no modal — es un formulario largo), dentro del formulario: "Generar colores desde el logo" (secondary, dispara la extracción), "Guardar tenant" (primary, deshabilitado hasta que todos los campos requeridos estén completos).
**Criterio de aceptación:** crear un tenant nuevo de principio a fin, con logo subido y color aplicado, y verificar que el login de ese tenant ya usa su color de acento.

## FASE 6 — Super-admin: módulos, planes y facturación
**Pantallas:** catálogo de módulos (lista simple, tú la gestionas), planes por módulo con `custom_price` opcional por tenant, vista de pagos/facturación con estado (al día, vencido, cancelado).
**Criterio de aceptación:** asignar un plan a un tenant y ver reflejado el monto correcto en su perfil.

## FASE 7 — Super-admin: modo soporte y auditoría
**Incluye:** botón "Entrar en modo soporte" desde el detalle de un tenant, banner persistente mientras está activo, registro automático en `audit_log` (quién, cuándo, qué tenant, qué acciones), pantalla de búsqueda del audit log.
**Criterio de aceptación:** activar modo soporte, navegar por datos del tenant, salir del modo, y confirmar que quedó un registro completo y legible en el audit log.

## FASE 8 — Módulo Gym: schema y backend
**Incluye:** schema `gym.*` completo (members, payments, checkins, memberships/plans, products, sales, sale_items, stock_movements), RLS con la función estándar, router FastAPI del módulo, registro en `availableModules`.
**Criterio de aceptación:** CRUD completo probado vía requests directas al backend (Postman/Thunder Client) antes de construir ninguna pantalla.

## FASE 9 — Gym: Dashboard
**Pantalla:** la ya diseñada en el mockup v3 (KPIs + vencimientos + actividad), ahora con datos reales de Supabase, loading skeletons, y empty state si el gym es nuevo.
**Criterio de aceptación:** con 0 datos se ve el empty state correcto; con datos de prueba masivos (50+ registros) el layout no se rompe.

## FASE 10 — Gym: Miembros (lista + detalle + CRUD)
**Pantallas:** tabla de miembros (usa DokkoTable, filtros por estado, búsqueda por nombre), detalle de miembro (datos + historial de pagos + historial de check-ins en tabs), formulario de crear/editar.
**Botón clave:** en el detalle, "Exportar/eliminar datos" (cumplimiento legal) — abre modal con dos opciones claras: "Exportar como PDF" y "Eliminar permanentemente" (esta última con doble confirmación).
**Criterio de aceptación:** flujo completo crear → ver en lista → abrir detalle → editar → confirmar cambios reflejados.

## FASE 11 — Gym: Check-in
**Pantalla:** buscador rápido (por nombre o código), lista de check-ins del día en tiempo real.
**Criterio de aceptación:** hacer check-in de un miembro debe reflejarse en la lista sin recargar la pantalla (Riverpod stream o polling corto).

## FASE 12 — Gym: Membresías y pagos
**Pantallas:** catálogo de planes, asignar/renovar plan a miembro, registrar pago, historial de pagos con filtros.
**Criterio de aceptación:** registrar un pago actualiza automáticamente la fecha de vencimiento del miembro sin acción manual adicional.

## FASE 13 — Gym: Productos y POS
**Pantallas:** inventario (lista + alertas de stock bajo), pantalla de venta rápida (POS), historial de ventas.
**Criterio de aceptación:** una venta descuenta stock automáticamente y genera un registro en `stock_movements` con `reason: 'sale'`.

## FASE 14 — Gym: Churn / Revenue Recovery ✅
**Pantalla:** vista de miembros en riesgo (basada en reglas: baja asistencia + vencimiento próximo), botón de recordatorio (dispara notificación/mensaje), métricas de churn histórico con gráfico simple.
**Criterio de aceptación:** la lógica de "en riesgo" corre automáticamente (job/función programada), no requiere cálculo manual.
> **Implementada:** reglas de riesgo automáticas en `GET /gym/churn/overview` (backend, sin cálculo manual); recordatorio persiste en `audit_log` (`churn_reminder`); gráfico histórico 6 meses; pantalla `GymChurnScreen` + test E2E verde.

## FASE 15 — Gym: Reportes y configuración ✅
**Criterio de aceptación:** reportes exportables (PDF/CSV), configuración del módulo (datos del gym, empleados, planes) editable y persistente.
> **Implementada:** exportación CSV y PDF de reportes (ingresos, check-ins, estado de miembros) en `GymReportsScreen`; empleados del gym `${gym_employees}` con CRUD `/gym/employees` y sección editable en configuración; plans y datos del gym ya persistían (006). Migración `014_gym_employees.sql`.

## FASE 16 — Componente compartido: Agenda
**Incluye:** todo lo especificado en la sección de diseño técnico de agenda (availability_slots, exceptions, appointments, prevención de doble-booking, buffer entre citas). Se construye en `shared_components/agenda/` para que salón y futuros módulos lo reutilicen.
**Criterio de aceptación:** intentar crear dos citas superpuestas para el mismo empleado debe fallar con un mensaje claro, no un error técnico crudo.

## FASE 17 — Módulo Inmobiliaria: schema y backend
**Incluye:** schema `realestate.*` (properties, leads, dossiers, commissions, agents), RLS, router FastAPI.
**Criterio de aceptación:** igual que Fase 8, adaptado.

## FASE 18 — Inmobiliaria: Dashboard y Propiedades
**Pantallas:** dashboard (comisiones, propiedades activas, leads nuevos), lista de propiedades, "agregar propiedad rápida" (parsing por regex del texto pegado + fotos), detalle de propiedad.
**Criterio de aceptación:** pegar un texto de ejemplo tipo WhatsApp debe autocompletar al menos el 70% de los campos del formulario antes de que el usuario edite manualmente.

## FASE 19 — Inmobiliaria: Leads y Dossiers
**Pantallas:** pipeline visual de leads (kanban: nuevo → contactado → visita → negociación → cerrado/perdido), detalle de lead, generador de dossier PDF.
**Criterio de aceptación:** mover un lead de columna en el kanban debe persistir el cambio inmediatamente (no requiere botón de "guardar" aparte).

## FASE 20 — Inmobiliaria: Comisiones y agentes
**Criterio de aceptación:** cerrar una venta calcula automáticamente la comisión según el % configurado y la reparte entre agentes si aplica.

## FASE 21 — Módulo Salón/Barbería: schema, agenda y pantallas base
**Incluye:** schema `salon.*` (services, employees adaptado, integración con `shared_components/agenda`), dashboard, vista de agenda por empleado, gestión de clientes con notas/preferencias.
**Criterio de aceptación:** la agenda reutiliza el componente de Fase 16 sin duplicar lógica.

## FASE 22 — Salón: POS, comisiones y reportes ✅
**Criterio de aceptación:** reutiliza POS de Fase 13 (mismo componente, distinto catálogo de productos por tenant).

> **Implementada:** POS compartido `shared_components/pos/` (un solo componente `PosScreen` + `PosDataSource`; gym y salón son wrappers delgados). Backend: migración `015_salon_pos.sql` (salon_products, salon_sales, salon_sale_items, salon_commissions, trigger stock, RLS), endpoints `/salon/products`, `/salon/sales`, `/salon/reports/revenue`, `/salon/reports/commissions`. Comisiones calculadas al vender si hay estilista asignado (commission_rate). Pantallas: `SalonPosScreen`, `SalonCommissionsScreen`, `SalonReportsScreen` (export CSV/PDF). Suite E2E 14/14 verde.

## FASE 23 — Sistema de branding completo
**Incluye:** extracción de color desde logo (backend Python), validación de contraste automática, aplicación dinámica del `ThemeData` según `brand_config`.
**Criterio de aceptación:** probar con 3 logos de paletas muy distintas (uno muy saturado, uno pastel claro, uno oscuro) y confirmar que el texto sigue siendo legible en los 3 casos sin ajuste manual.

## FASE 24 — Facturación y ciclo de vida del tenant
**Incluye:** lógica de suspensión por falta de pago (días de gracia configurables), notificaciones al super-admin de pagos vencidos, pantalla de estado de cuenta visible para el tenant (solo lectura).
**Criterio de aceptación:** un tenant con pago vencido más allá del período de gracia pierde acceso automáticamente, con mensaje claro en el login (no un error genérico).

## FASE 25 — Cumplimiento legal (Ley 172-13)
**Incluye:** función de exportar/eliminar datos de una persona específica en cada módulo, checkbox de consentimiento en flujos de captura (leads, registro de miembros), política de retención tras cancelación de tenant.
**Criterio de aceptación:** solicitar la eliminación de un miembro/lead borra sus datos personales de todas las tablas relacionadas, no solo de la tabla principal.

> **Implementada:** migración `017_legal_consent.sql` (aplicada vía Management API): `consent_granted_at` en `gym_members`, `realestate_leads`, `salon_clients` y `tenants.retention_days` (default 90). Backend: `consent_granted_at` en schemas create/update de gym/RE/salón; `GET .../{id}/export-data` en gym/RE/salón (Ley 172-13, JSON portátil + log en `audit_log`); DELETE que desvincula FKs antes de borrar (gym_sales.member_id, realestate_dossiers/comissions.lead_id, citas de salón) y audita; `POST /billing/apply-retention` (super-admin, ejecutable agendado: borra personas sin consentimiento con más de `retention_days`). Frontend: checkbox de consentimiento Ley 172-13 en registro de miembro gym, modal de lead RE y cliente de salón; botones Exportar/Eliminar en detalle de miembro gym, tarjeta de lead (kanban) y tarjeta de cliente de salón con diálogo de confirmación y vista JSON del export. `flutter analyze` limpio; tests backend 51/51 + suite E2E 15/15.

## FASE 26 — QA y auditoría de seguridad
**Incluye:** suite de tests automatizados de RLS (cada tabla, cada policy, verificado con al menos 2 tenants de prueba), pruebas de carga básicas, revisión manual de que ningún módulo importa código de otro.
**Criterio de aceptación:** 100% de las tablas con `tenant_id` tienen al menos un test que confirma que el aislamiento funciona.

> **Implementada:** `tests/test_rls.py` verifica las 31 tablas con `tenant_id` (consulta `information_schema.columns`) probando escape cross-tenant (anon key + JWT de un tenant contra `tenant_id=eq.<otro>` → `[]`) y propagación de `tenant_id` vía JWT; `tests/test_load.py` con 40 peticiones concurrentes (health y kpis) con p95 < 2000ms; `test/module_isolation_test.dart` comprueba que gym/real_estate/salon no se importan entre sí. Resultado: backend 51 passed, Dart 3 passed. Suite E2E completa (15/15).

## FASE 27 — Despliegue
**Incluye:** Dockerfile del backend FastAPI, despliegue en el VPS de Hostinger, configuración de dominio/subdominio, build de producción de Flutter desktop, proceso de distribución a los primeros clientes (instalador o similar).
**Criterio de aceptación:** un tenant de prueba completo (desde super-admin hasta uso diario) funcionando en el entorno de producción real, no local.

> **Implementada (parcial):** artefactos de despliegue listos: `requirements.txt`, `Dockerfile` (python:3.11-slim + uvicorn), `dokko-compose.yml` (servicio `api`, env_file `./dokko-backend/.env`, healthcheck) y `scripts/deploy.sh` (rsync/scp + Caddy con auto-HTTPS). **Pendiente:** validar `docker build` en el VPS (Docker no está instalado en esta Mac) y ejecutar el despliegue real con el on-boarding de un tenant piloto (FASE 29).

## FASE 28 — Mensajería y notificaciones (innovación, piloto salón)
**Decisión de arquitectura:** NO se usa WhatsApp Cloud API en este ciclo. Se implementa **deep-link `wa.me` + automatización**: Dokko compone y agenda los mensajes (recordatorios, lista de espera, feedback), el personal los revisa en una bandeja por lotes y pulsa "Abrir en WhatsApp" para enviarlos con el texto prefabricado. Costo $0 por mensaje, sin cuenta Meta ni plantillas a aprobar. La interfaz `MessageProvider` queda lista para migrar a WhatsApp Cloud API si un cliente la exige (costos estimados entonces: Utility/Auth ≈ €0.018, Marketing ≈ €0.117 vía BSP; oct‑2026: service en ventana 24h facturado tras 1.000 gratis/mes por número).

**Modelo de envío:** bandeja por lotes + confirmación por lote (un solo tap de confirmación tras enviar la tanda; se descartaron clientes de WhatsApp no oficiales por riesgo de baneo).

**Criterio de aceptación:** el personal del salón recibe recordatorios de cita (con consentimiento Ley 172‑13), libera la lista de espera cuando se cancela una cita y solicita feedback tras completar la cita; todo con una vuelta manual por lote en WhatsApp.

> **Implementada:** migración `supabase_migrations/018_messaging.sql` (aplicada en Supabase): `messaging_settings`, `messaging_templates`, `message_batches`, `outbound_messages`, `salon_waitlist` + RLS. Backend `app/modules/messaging/` (provider/templates/service/schemas/router, prefix `/messaging`): settings, plantillas, scheduling, `materialize_due`, confirmar/descartar lote, historial; hooks en `salon/router.py` (recordatorio al crear cita, aviso de waitlist + feedback al cancelar/completar, re-agenda al reprogramar); endpoints de waitlist. Frontend: `url_launcher`, `core/messaging/wa_deep_link.dart` (launcher inyectable para E2E), modelos/API, pantalla **Centro de Mensajes** (`/salon/messages`), botón "Enviar por WhatsApp" + indicador de consentimiento en la tarjeta de cliente. Validación: `flutter analyze` sin issues, suite backend 68 passed (`tests/test_messaging.py` 12 tests + RLS actualizado), E2E de mensajería (deep-link `https://wa.me/1…?text=…` + navegación del centro de mensajes) OK. **Pendiente:** los flujos E2E completos muestran flakiness puntual del harness bajo carga (reintentar el lote completo en una máquina ociosa); extensión futura a gym (amenidades/retención) y real-estate (seguimiento de leads).

## FASE 29 — Checklist de lanzamiento
- [ ] Términos de servicio y política de privacidad publicados
- [ ] Precios y setup fee confirmados en el flujo de venta
- [ ] Al menos 1 tenant piloto probando en producción por 1-2 semanas antes del primer cliente pagador
- [ ] Plan de soporte definido (¿cómo te contactan si algo falla?)
- [ ] Backup automático de Supabase verificado y probado (restaurar, no solo que exista)

---

## Nota final
Este documento es la fuente de verdad del proyecto. Cuando surja una decisión nueva durante la construcción que no esté aquí contemplada, resuélvela y actualiza este documento — no dejes que el conocimiento viva solo en el código o en tu memoria.
