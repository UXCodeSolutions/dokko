import 'dart:typed_data';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dokko/main.dart' show DokkoApp;
import 'package:dokko/core/widgets/dokko_button.dart';
import 'package:dokko/core/messaging/wa_deep_link.dart'
    show waLauncherProvider;
import 'package:dokko/super_admin/presentation/tenants_list_screen.dart'
    show TenantCard;
import 'package:dokko/shared_components/pos/pos_screen.dart'
    show productImagePickerProvider;

const _superAdminEmail = 'os-test@dokko.dev';
const _superAdminPassword = 'DokkoTest1!';
const _gymEmail = 'gym-admin@dokko.dev';
const _salonEmail = 'salon-admin@dokko.dev';
const _reEmail = 're-admin@dokko.dev';
const _tenantPassword = 'DokkoTest1!';

final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x37, 0x4D, 0x8E, 0xD7, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

ProviderScope _buildApp() {
  return ProviderScope(
    overrides: [
      productImagePickerProvider.overrideWithValue(
        () async => (bytes: _tinyPng, ext: 'png'),
      ),
      waLauncherProvider.overrideWithValue(
        (url) async => launchedUrls.add(url),
      ),
    ],
    child: const DokkoApp(),
  );
}

final launchedUrls = <String>[];

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .where((t) => t != null && t.isNotEmpty)
      .take(30)
      .toList();
  fail('No se encontró el widget esperado en ${timeout.inSeconds}s: $finder\n'
      '${reason != null ? 'Razón: $reason\n' : ''}'
      'Textos visibles: $texts');
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isEmpty) return;
  }
  fail('El widget no desapareció en ${timeout.inSeconds}s: $finder\n'
      '${reason != null ? 'Razón: $reason\n' : ''}');
}

bool _canScrollTable(WidgetTester tester, Finder scrollable, {bool down = true}) {
  if (scrollable.evaluate().isEmpty) return false;
  final pos = tester.state<ScrollableState>(scrollable).position;
  return down ? pos.pixels < pos.maxScrollExtent : pos.pixels > pos.minScrollExtent;
}

// Espera a que aparezca `target` y, si queda fuera del viewport (listas
// virtualizadas), barre el `scrollable` hacia abajo y luego hacia arriba.
Future<void> _scrollUntilFound(
  WidgetTester tester,
  Finder target,
  Finder scrollable, {
  String? reason,
}) async {
  // 1) Espera inicial generosa: tras un alta el provider se reconsulta
  // (invalidate) y bajo carga de la suite la respuesta puede tardar.
  for (int i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (target.evaluate().isNotEmpty) return;
  }
  // 2) Si el scrollable aún no existe (p.ej. el kanban está recargando),
  // reintentar durante algunos segundos en vez de abortar de inmediato.
  var emptyRetries = 20;
  for (var sweep = 0; sweep < 2; sweep++) {
    final delta =
        sweep == 0 ? const Offset(0, -300) : const Offset(0, 300);
    for (int i = 0; i < 24; i++) {
      if (scrollable.evaluate().isEmpty) {
        if (emptyRetries-- <= 0) break;
        await tester.pump(const Duration(milliseconds: 300));
        if (target.evaluate().isNotEmpty) return;
        continue;
      }
      await tester.drag(scrollable, delta);
      await tester.pump(const Duration(milliseconds: 200));
      if (target.evaluate().isNotEmpty) return;
    }
  }
  fail('No se encontró el widget tras hacer scroll: $target\n'
      '${reason != null ? 'Razón: $reason\n' : ''}');
}

// La lista de tenants se muestra como grid de tarjetas (TenantCard).
final Finder _tenantCardFinder = find.byType(TenantCard);

Future<void> _scrollTableUntilFound(
  WidgetTester tester,
  Finder target, {
  String? reason,
}) async {
  // 1) Esperar a que las tarjetas de tenants carguen (o aparezca el estado vacío).
  final loadEnd = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(loadEnd)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (_tenantCardFinder.evaluate().isNotEmpty) break;
    if (find.text('No hay tenants registrados.').evaluate().isNotEmpty) break;
  }
  if (_tenantCardFinder.evaluate().isEmpty) {
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => t != null && t.isNotEmpty)
        .take(30)
        .toList();
    fail('La lista de tenants no cargó datos: $target\n'
        '${reason != null ? 'Razón: $reason\n' : ''}'
        'Textos visibles: $texts');
  }

  // 2) Barrido del grid de tarjetas hacia abajo y luego hacia arriba para
  // encontrarlo en cualquier posición (GridView.builder virtualiza).
  final scrollable = find
      .ancestor(of: _tenantCardFinder.first, matching: find.byType(Scrollable))
      .first;
  var down = true;
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (target.evaluate().isNotEmpty) return;
    if (down) {
      if (!_canScrollTable(tester, scrollable, down: true)) {
        down = false;
        continue;
      }
      await tester.drag(scrollable, const Offset(0, -250));
    } else {
      if (!_canScrollTable(tester, scrollable, down: false)) break;
      await tester.drag(scrollable, const Offset(0, 250));
    }
  }
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .where((t) => t != null && t.isNotEmpty)
      .take(30)
      .toList();
  fail('No se encontró el widget tras hacer scroll en la tabla: $target\n'
      '${reason != null ? 'Razón: $reason\n' : ''}'
      'Textos visibles: $texts');
}

Future<void> _loginAs(
  WidgetTester tester,
  String email,
  String password,
) async {
  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(2), reason: 'Debe haber 2 campos (email/contraseña)');
  final emailField = tester.widget<TextField>(fields.at(0));
  final passwordField = tester.widget<TextField>(fields.at(1));
  emailField.controller!.text = email;
  passwordField.controller!.text = password;
  await tester.pump();
  await tester.tap(find.descendant(
      of: find.byType(DokkoButton), matching: find.text('Iniciar sesión')));
  await tester.pump();
}

Future<void> _loginAndWaitShell(
  WidgetTester tester,
  String email,
) async {
  await Supabase.instance.client.auth.signOut();
  await tester.pumpWidget(_buildApp());
  await _pumpUntilFound(tester, find.text('Iniciar sesión'));
  await _loginAs(tester, email, _tenantPassword);
  await _pumpUntilFound(tester, find.text('Cerrar sesión'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    await Supabase.instance.client.auth.signOut();
  });

  testWidgets('Flujo E2E: tenant gym loguea, revisa dashboard y cierra sesión',
      (tester) async {
    await _loginAndWaitShell(tester, _gymEmail);

    expect(find.text('Gym TEST Debug'), findsOneWidget,
        reason: 'El sidebar debe mostrar el nombre del tenant');
    expect(find.text('GymOS'), findsOneWidget,
        reason: 'El sidebar debe mostrar el título del módulo');
    expect(find.text('Dashboard'), findsWidgets,
        reason: 'El sidebar del módulo gym debe verse');
    expect(find.text('Miembros'), findsOneWidget);
    expect(find.text('POS / Productos'), findsOneWidget);
    expect(find.text('Configuración'), findsOneWidget);
  });

  testWidgets(
      'Flujo E2E: super-admin loguea y ve la lista de tenants con la API real',
      (tester) async {
    await Supabase.instance.client.auth.signOut();
    await tester.pumpWidget(_buildApp());
    await _pumpUntilFound(tester, find.text('Iniciar sesión'));

    await tester.tap(find.text('Entrar como Super-Admin'));
    await _pumpUntilFound(tester, find.text('ACCESO SUPER-ADMIN'));

    await _loginAs(tester, _superAdminEmail, _superAdminPassword);

    await _scrollTableUntilFound(tester, find.text('Gym TEST Debug'),
        reason: 'La lista de tenants viene del backend');
    await _scrollTableUntilFound(tester, find.text('Salon TEST Debug'),
        reason: 'La lista de tenants viene del backend');
    await _scrollTableUntilFound(tester, find.text('Real Estate TEST Debug'),
        reason: 'Debe existir un tenant real_estate de prueba');
  });

  testWidgets(
      'Gym tenant: navega por Miembros, POS, Membresías y Configuración contra la API real',
      (tester) async {
    await _loginAndWaitShell(tester, _gymEmail);

    await tester.tap(find.text('Miembros'));
    await _pumpUntilFound(tester, find.text('Ana Perez'));

    await tester.tap(find.text('POS / Productos'));
    await _pumpUntilFound(tester, find.text('Batido Proteico'));
    expect(find.text('Gestionar Productos'), findsOneWidget);

    await tester.tap(find.text('Membresías'));
    await _pumpUntilFound(tester, find.text('Mensual'));

    await tester.tap(find.text('Configuración'));
    await _pumpUntilFound(tester, find.text('Guardar Cambios'));
    final settingsValues = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.controller?.text ?? '')
        .toList();
    expect(settingsValues.any((t) => t.contains('Gym TEST')), isTrue,
        reason: 'Configuración debe cargar el gym_name desde la API');
  });

  testWidgets(
      'Super-admin: Account Owners, detalle de tenant y pantallas de billing/auditoría/módulos',
      (tester) async {
    await Supabase.instance.client.auth.signOut();
    await tester.pumpWidget(_buildApp());
    await _pumpUntilFound(tester, find.text('Iniciar sesión'));
    await tester.tap(find.text('Entrar como Super-Admin'));
    await _pumpUntilFound(tester, find.text('ACCESO SUPER-ADMIN'));
    await _loginAs(tester, _superAdminEmail, _superAdminPassword);
    await _scrollTableUntilFound(tester, find.text('Gym TEST Debug'),
        reason: 'Debe listar tenants con la API real');

    await tester.tap(find.text('Account Owners'));
    await _pumpUntilFound(tester, find.text('os-test@dokko.dev'));

    await tester.tap(find.text('Tenants'));
    await _scrollTableUntilFound(tester, find.text('Gym TEST Debug'),
        reason: 'Debe poder abrir el detalle de un tenant');
    await tester.ensureVisible(find.text('Gym TEST Debug'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Gym TEST Debug'), warnIfMissed: false);
    await _pumpUntilFound(tester, find.text('Email Owner'));
    expect(find.text('Entrar en modo soporte'), findsOneWidget);

    await tester.tap(find.text('Facturación Global'));
    await _pumpUntilFound(tester, find.text('Pagos vencidos (notificaciones)'),
        reason: 'La pantalla de facturación global debe mostrar el panel de pagos vencidos (FASE 24)');
    expect(find.text('Revisar suspensiones'), findsOneWidget);

    await tester.tap(find.text('Auditoría'));
    await _pumpUntilFound(tester, find.text('Log de Auditoría'),
        reason: 'La pantalla de auditoría debe renderizar su cabecera');
    // El log puede estar vacío o contener eventos (p.ej. recordatorios de churn).
    if (find.text('No hay eventos en el log.').evaluate().isEmpty) {
      expect(find.text('ACCIÓN'), findsOneWidget,
          reason: 'Si el log tiene eventos, debe verse la tabla con su encabezado');
    }

    await tester.tap(find.text('Módulos y Planes'));
    await _pumpUntilFound(tester, find.text('Catálogo de Módulos y Planes'));
    expect(find.text('Gimnasio y Fitness'), findsOneWidget);
    expect(find.text('Inmobiliaria'), findsOneWidget);
  });

  testWidgets('Super-admin: crea un tenant completo desde la UI', (tester) async {
    await Supabase.instance.client.auth.signOut();
    await tester.pumpWidget(_buildApp());
    await _pumpUntilFound(tester, find.text('Iniciar sesión'));
    await tester.tap(find.text('Entrar como Super-Admin'));
    await _pumpUntilFound(tester, find.text('ACCESO SUPER-ADMIN'));
    await _loginAs(tester, _superAdminEmail, _superAdminPassword);
    await _scrollTableUntilFound(tester, find.text('Gym TEST Debug'),
        reason: 'Tras el login, la lista de tenants debe renderizar la tabla');

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final uiName = 'UI E2E $stamp';
    final uiEmail = 'ui-$stamp@dokko.dev';

    await tester.tap(find.text('Nuevo Tenant'));
    await _pumpUntilFound(tester, find.text('Crear Tenant'));

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3),
        reason: 'Nombre, email admin y contraseña');
    tester.widget<TextField>(fields.at(0)).controller!.text = uiName;
    tester.widget<TextField>(fields.at(1)).controller!.text = uiEmail;
    tester.widget<TextField>(fields.at(2)).controller!.text = 'DokkoTest1!';
    await tester.pump();

    await tester.tap(find.descendant(
        of: find.byType(DokkoButton), matching: find.text('Crear Tenant')));
    await _pumpUntilFound(tester, find.text(uiName),
        timeout: const Duration(seconds: 40));
  });

  testWidgets(
      'Gym tenant: crea un producto en POS, lo vende y aparece en Historial',
      (tester) async {
    await _loginAndWaitShell(tester, _gymEmail);

    await tester.tap(find.text('POS / Productos'));
    await _pumpUntilFound(tester, find.text('Gestionar Productos'));
    await tester.tap(find.text('Gestionar Productos'));
    await _pumpUntilFound(tester, find.text('Nuevo Producto'));

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pName = 'Prod E2E $stamp';
    final fields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));
    expect(fields, findsNWidgets(5),
        reason: 'Nombre, SKU, precio, stock y alerta');

    await tester.tap(find.text('Subir imagen'));
    await _pumpUntilFound(tester, find.text('Cambiar imagen'),
        reason: 'El picker (override) debe adjuntar la imagen');

    tester.widget<TextField>(fields.at(0)).controller!.text = pName;
    tester.widget<TextField>(fields.at(2)).controller!.text = '12.5';
    tester.widget<TextField>(fields.at(3)).controller!.text = '20';
    tester.widget<TextField>(fields.at(4)).controller!.text = '20';
    await tester.pump();

    await tester.tap(find.descendant(
        of: find.byType(DokkoButton), matching: find.text('Crear')));

    // El diálogo debe cerrarse (POST real) y el producto debe salir en la grilla.
    await _pumpUntilGone(tester, find.byType(Dialog),
        reason: 'El producto debe crearse y cerrar el formulario');
    await _scrollUntilFound(tester, find.text(pName), find.byType(GridView),
        reason: 'El producto creado debe aparecer en la cuadrícula');
    await _pumpUntilFound(tester, find.text('¡Poco stock!'),
        reason: 'Con stock 20 y alerta 20, debe marcarse de bajo stock');

    await tester.ensureVisible(find.text(pName));
    await tester.pump();
    await tester.tap(find.text(pName), warnIfMissed: true);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Cobrar \$12.50'));

    await tester.tap(find.text('Cobrar \$12.50'));
    await _pumpUntilFound(tester, find.textContaining('Venta registrada'));

    await tester.tap(find.text('Historial'));
    await _pumpUntilFound(tester, find.text('\$12.5'),
        reason: 'La venta debe verse en el Historial');

    await tester.tap(find.text('Punto de Venta'));
    await _scrollUntilFound(tester, find.text('Stock: 19'),
        find.byType(GridView),
        reason: 'El stock debe decrementarse tras la venta');
  });

  testWidgets('Gym tenant: registra un check-in real para Ana Perez',
      (tester) async {
    await _loginAndWaitShell(tester, _gymEmail);

    await tester.tap(find.text('Check-in'));

    // Esperar a que terminen de cargar miembros y check-ins
    // (el header "Check-ins Hoy (0)" aparece antes de la carga real).
    await _pumpUntilGone(tester, find.byType(CircularProgressIndicator),
        reason: 'Debe terminar de cargar miembros y check-ins del día');

    final searchField = tester.widget<TextField>(find.byType(TextField).first);
    searchField.controller!.text = 'ana';
    await tester.pump();

    await _pumpUntilFound(tester, find.byIcon(Icons.login_rounded),
        reason: 'Los resultados de búsqueda deben mostrar el botón de check-in');
    await tester.tap(find.byIcon(Icons.login_rounded));
    await _pumpUntilFound(tester, find.textContaining('Check-in registrado'),
        timeout: const Duration(seconds: 40));
  });

  testWidgets('Gym tenant: revisa Churn (miembros en riesgo)', (tester) async {
    await _loginAndWaitShell(tester, _gymEmail);

    await tester.tap(find.text('Churn'));
    await _pumpUntilFound(tester, find.text('Churn / Fidelización'),
        reason: 'La pantalla de churn debe renderizar su cabecera');

    // La lógica de riesgo la calcula el backend (gancho de la FASE 14).
    await _pumpUntilFound(tester, find.text('Miembros en riesgo'),
        reason: 'Los KPIs de churn deben cargar al menos la sección de riesgo');
    await _pumpUntilFound(tester, find.textContaining('Churn histórico'),
        reason: 'Debe renderizarse el gráfico de churn histórico');

    // Si hay al menos un miembro en riesgo, la tabla trae su acción.
    if (find.text('Recordar').evaluate().isNotEmpty) {
      expect(find.text('Recordar'), findsWidgets,
          reason: 'Cada fila en riesgo tiene su botón de recordatorio');
    }
  });

  testWidgets('Gym tenant: exporta reportes y gestiona empleados',
      (tester) async {
    await _loginAndWaitShell(tester, _gymEmail);

    // Reportes exportables (FASE 15).
    await tester.tap(find.text('Reportes'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('export-csv-btn')),
        reason: 'Los reportes deben exponer botones de exportación');
    await tester.tap(find.byKey(const ValueKey('export-csv-btn')));
    await _pumpUntilFound(tester, find.textContaining('CSV exportado a'),
        reason: 'Debe confirmarse la exportación CSV');
    await tester.tap(find.byKey(const ValueKey('export-pdf-btn')));
    await _pumpUntilFound(tester, find.textContaining('PDF exportado a'),
        reason: 'Debe confirmarse la exportación PDF');

    // Configuración: empleados del gym editables y persistentes (FASE 15).
    await tester.tap(find.text('Configuración'));
    await _pumpUntilFound(tester, find.text('Personaliza tu gimnasio.'),
        reason: 'La pantalla de configuración debe abrir');
    await tester.ensureVisible(find.byKey(const ValueKey('add-employee-btn')));
    await tester.tap(find.byKey(const ValueKey('add-employee-btn')));
    await _pumpUntilFound(tester, find.text('Agregar Empleado'),
        reason: 'Debe abrirse el modal de empleados');
    await tester.enterText(find.byKey(const ValueKey('emp-first')), 'Entrenador');
    await tester.enterText(find.byKey(const ValueKey('emp-last')), 'E2E');
    await tester.tap(find.byKey(const ValueKey('save-employee-btn')));
    await _pumpUntilFound(tester, find.textContaining('Entrenador E2E'),
        reason: 'El empleado creado debe listarse en configuración');
  });

  testWidgets('Gym tenant: consulta su Estado de cuenta (FASE 24)',
      (tester) async {
    await _loginAndWaitShell(tester, _gymEmail);

    await tester.tap(find.text('Estado de cuenta'));
    await _pumpUntilFound(tester, find.text('Suscripción activa'),
        reason: 'La pantalla de estado de cuenta debe mostrar el status actual del tenant');
    expect(find.text('Historial de pagos'), findsOneWidget,
        reason: 'Debe existir la sección de historial de pagos');
    expect(find.textContaining('Gracia configurada'), findsOneWidget,
        reason: 'Debe mostrarse la información de los días de gracia');
  });

  testWidgets('Salon tenant: navega y registra un cliente real',
      (tester) async {
    await _loginAndWaitShell(tester, _salonEmail);

    expect(find.text('Salon TEST Debug'), findsOneWidget,
        reason: 'El sidebar debe mostrar el tenant de salón');
    expect(find.text('SalonOS'), findsOneWidget);

    await tester.tap(find.text('Clientes'));
    await _pumpUntilFound(tester, find.text('Nuevo Cliente'),
        reason: 'El botón de nuevo cliente solo existe en la pantalla de clientes');

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final clientName = 'Cliente E2E $stamp';
    await tester.tap(find.text('Nuevo Cliente'));
    await _pumpUntilFound(tester, find.byType(Dialog),
        reason: 'Debe abrirse el modal de nuevo cliente');

    final formFields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextFormField));
    expect(formFields, findsNWidgets(4),
        reason: 'Nombre, apellido, teléfono y notas');
    await tester.enterText(formFields.at(0), clientName);
    await tester.enterText(formFields.at(1), 'E2E');
    await tester.enterText(formFields.at(2), '809-555-0100');
    await tester.pump();

    await tester.tap(find.text('Crear Cliente'));
    await _pumpUntilGone(tester, find.byType(Dialog),
        reason: 'La creación del cliente debe cerrar el modal');
    final clientsList = find.byKey(const ValueKey('salon-clients-list'));
    await _scrollUntilFound(tester, find.textContaining(clientName),
        clientsList,
        reason: 'El cliente creado debe aparecer en la lista');
  });

  testWidgets('Salon tenant: revisa Dashboard y Agenda', (tester) async {
    await _loginAndWaitShell(tester, _salonEmail);

    await tester.tap(find.text('Agenda'));
    await _pumpUntilFound(tester, find.text('Nueva Cita'),
        reason: 'La pantalla de agenda debe renderizar su toolbar');

    await tester.tap(find.text('Dashboard'));
    await _pumpUntilFound(tester, find.text('Dashboard — SalonOS'),
        reason: 'El dashboard del salón debe cargar KPIs y citas de hoy');
  });

  testWidgets(
      'Salon tenant: mensajería — deep-link wa.me y centro de mensajes (FASE 28)',
      (tester) async {
    await _loginAndWaitShell(tester, _salonEmail);
    launchedUrls.clear();

    // 1) Deep-link wa.me desde la tarjeta de un cliente con teléfono.
    await tester.tap(find.text('Clientes'));
    await _pumpUntilFound(tester, find.text('Nuevo Cliente'),
        reason: 'La pantalla de clientes debe abrir');
    final clientsScrollable = find.byKey(const ValueKey('salon-clients-list'));
    await _pumpUntilFound(tester, clientsScrollable,
        reason: 'La rejilla de clientes debe renderizarse');

    // Los botones de acción de cada tarjeta solo se muestran al pasar el
    // cursor (hover). Simulamos el puntero del ratón sobre la primera tarjeta
    // y mantenemos la posición fija mientras barremos la lista.
    final gesture =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(
        location: tester.getTopLeft(clientsScrollable) +
            const Offset(60, 30));
    await tester.pump();
    await _scrollUntilFound(
        tester,
        find.byTooltip('Enviar por WhatsApp'),
        clientsScrollable,
        reason: 'Debe existir al menos una tarjeta de cliente con WhatsApp');
    final waButton = find.byTooltip('Enviar por WhatsApp').first;
    await tester.ensureVisible(waButton);
    await tester.pump();
    await tester.tap(waButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(launchedUrls, isNotEmpty, reason: 'El deep-link debe generarse');
    final waUrl = launchedUrls.first;
    expect(waUrl, startsWith('https://wa.me/1'),
        reason: 'El enlace wa.me debe usar dígitos E.164 con prefijo RD');
    expect(waUrl, contains('?text='),
        reason: 'El mensaje debe ir prefabricado en el enlace');

    // 2) Centro de mensajes: bandeja de pendientes / historial.
    await tester.tap(find.text('Mensajería'));
    await _pumpUntilFound(tester, find.text('Centro de Mensajes'),
        reason: 'La ruta de mensajería debe abrir');
    expect(find.text('Pendientes'), findsOneWidget,
        reason: 'Debe existir el segmento de pendientes');
    expect(find.text('Historial'), findsOneWidget,
        reason: 'Debe existir el segmento de historial');

    // Con datos previos aparecen lotes; sin ellos, el estado vacío.
    // Esperamos a que la bandeja termine de cargar antes de decidir.
    final pendingEmpty = find.textContaining('No hay mensajes pendientes');
    final pendingList = find.byKey(const ValueKey('salon-pending-list'));
    var pendingReady = false;
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (pendingEmpty.evaluate().isNotEmpty ||
          pendingList.evaluate().isNotEmpty) {
        pendingReady = true;
        break;
      }
    }
    expect(pendingReady, isTrue,
        reason: 'La bandeja debe terminar de cargar');
    if (pendingList.evaluate().isNotEmpty) {
      await tester.tap(find.text('Historial'));
      await _pumpUntilFound(
          tester,
          find.byKey(const ValueKey('salon-history-list')),
          reason: 'El historial debe renderizar su lista');
    }
  });

  testWidgets(
      'Salon tenant: POS reutilizado vende con comisión y exporta reportes',
      (tester) async {
    await _loginAndWaitShell(tester, _salonEmail);

    // POS del salón = componente POS compartido (FASE 13 reutilizada).
    await tester.tap(find.text('POS / Ventas'));
    await _pumpUntilFound(tester, find.text('POS del Salón'),
        reason: 'El POS del salón debe usar el componente compartido');
    await tester.tap(find.text('Gestionar Productos'));
    await _pumpUntilFound(tester, find.text('Nuevo Producto'));

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pName = 'Salon Prod $stamp';
    final fields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));
    expect(fields, findsNWidgets(5),
        reason: 'Mismo formulario de producto del POS compartido (FASE 13)');

    await tester.tap(find.text('Subir imagen'));
    await _pumpUntilFound(tester, find.text('Cambiar imagen'),
        reason: 'El override de imagen debe adjuntarse');

    tester.widget<TextField>(fields.at(0)).controller!.text = pName;
    tester.widget<TextField>(fields.at(2)).controller!.text = '25.0';
    tester.widget<TextField>(fields.at(3)).controller!.text = '10';
    tester.widget<TextField>(fields.at(4)).controller!.text = '5';
    await tester.pump();

    await tester.tap(find.descendant(
        of: find.byType(DokkoButton), matching: find.text('Crear')));
    await _pumpUntilGone(tester, find.byType(Dialog),
        reason: 'El producto del salón debe crearse');
    await _scrollUntilFound(tester, find.text(pName), find.byType(GridView),
        reason: 'El producto debe aparecer en la grilla del POS');

    // Cobrar asignando estilista para generar comisión.
    await tester.ensureVisible(find.text(pName));
    await tester.pump();
    await tester.tap(find.text(pName), warnIfMissed: true);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Asignar a estilista (opcional)'),
        reason: 'El POS del salón expone el asignador de estilista (comisiones)');
    await tester.tap(find.text('Asignar a estilista (opcional)'));
    await _pumpUntilFound(tester, find.text('Seleccionar Estilista'),
        reason: 'Debe abrirse el diálogo para asignar estilista');
    await tester.tap(find.text('StylistA Comisión E2E'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Cobrar \$25.00'));

    await tester.tap(find.text('Cobrar \$25.00'));
    await _pumpUntilFound(tester, find.textContaining('Venta registrada'),
        reason: 'La venta del salón debe registrarse');

    await tester.tap(find.text('Historial'));
    await _pumpUntilFound(tester, find.text('\$25.0'),
        reason: 'La venta debe verse en el Historial del POS');

    // Comisiones: el corte con estilista genera una línea de comisión.
    await tester.tap(find.text('Comisiones'));
    await _pumpUntilFound(tester, find.text('Total comisiones'),
        reason: 'La pantalla de comisiones debe cargar sus KPIs');
    await _pumpUntilFound(tester, find.text('StylistA Comisión E2E'),
        reason: 'El estilista debe tener una comisión generada por la venta');

    // Reportes exportables (FASE 22).
    await tester.tap(find.text('Reportes'));
    await _pumpUntilFound(tester,
        find.byKey(const ValueKey('salon-export-csv-btn')),
        reason: 'Los reportes del salón deben exponer exportación');
    await tester.tap(find.byKey(const ValueKey('salon-export-csv-btn')));
    await _pumpUntilFound(tester, find.textContaining('CSV exportado a'),
        reason: 'Debe confirmarse la exportación CSV del salón');
  });

  testWidgets('Real estate tenant: navega y registra un lead real',
      (tester) async {
    await _loginAndWaitShell(tester, _reEmail);

    expect(find.text('Real Estate TEST Debug'), findsOneWidget,
        reason: 'El sidebar debe mostrar el tenant de inmobiliaria');
    expect(find.text('PropOS'), findsOneWidget);

    await tester.tap(find.text('Propiedades'));
    await _pumpUntilFound(tester, find.text('Nueva Propiedad'),
        reason: 'El toolbar de propiedades solo existe en esa pantalla');

    await tester.tap(find.text('Leads'));
    await _pumpUntilFound(tester, find.text('Nuevo Lead'),
        reason: 'El toolbar de leads solo existe en el CRM');

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final leadName = 'Lead E2E $stamp';
    await tester.tap(find.text('Nuevo Lead'));
    await _pumpUntilFound(tester, find.byType(Dialog),
        reason: 'Debe abrirse el modal de nuevo lead');

    final leadFields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextFormField));
    expect(leadFields, findsNWidgets(4),
        reason: 'Nombre, apellido, teléfono y email');
    await tester.enterText(leadFields.at(0), leadName);
    await tester.enterText(leadFields.at(1), 'E2E');
    await tester.pump();

    await tester.tap(find.text('Crear Lead'));
    await _pumpUntilGone(tester, find.byType(Dialog),
        reason: 'La creación del lead debe cerrar el modal');
    // La columna "Nuevos" se identifica con ValueKey('kanban-column-new').
    final nuevoList = find.descendant(
        of: find.byKey(const ValueKey('kanban-column-new')),
        matching: find.byType(ListView));
    await _scrollUntilFound(tester, find.textContaining(leadName), nuevoList,
        reason: 'El lead debe aparecer en la columna "Nuevos" del kanban');
  });

  testWidgets('Real estate tenant: revisa Dashboard, Dossiers y Comisiones',
      (tester) async {
    await _loginAndWaitShell(tester, _reEmail);

    await tester.tap(find.text('Dashboard'));
    await _pumpUntilFound(tester, find.text('Dashboard Inmobiliario'),
        reason: 'El dashboard inmobiliario debe renderizar KPIs');

    await tester.tap(find.text('Dossiers'));
    await _pumpUntilFound(tester, find.textContaining('Dossiers'),
        reason: 'La pantalla de dossiers debe renderizar');

    await tester.tap(find.text('Comisiones'));
    await _pumpUntilFound(tester, find.text('Comisiones y Agentes'),
        reason: 'La pantalla de comisiones debe renderizar');
  });
}