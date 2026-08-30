import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_permission_grant.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/plugin_webview_permission_gate.dart';

InstalledPlugin _plugin({List<String> permissions = const []}) =>
    InstalledPlugin(
      pluginId: 'p1',
      name: 'P1',
      version: '1.0.0',
      installPath: '/tmp/p1',
      entrypointPath: 'index.html',
      enabled: true,
      pinned: false,
      manifest: PluginManifest.fromJson({
        'id': 'p1',
        'name': 'P1',
        'version': '1.0.0',
        'entrypoint': 'index.html',
        'permissions': permissions,
      }),
      installedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

PermissionRequest _request(List<PermissionResourceType> resources) =>
    PermissionRequest(
      origin: WebUri('file:///C:/plugins/p1/index.html'),
      resources: resources,
    );

class _FakeRegistry implements PluginRegistryRepository {
  _FakeRegistry({this.grants = const {}, this.throwOnRead = false});

  final Map<String, bool> grants;
  final bool throwOnRead;

  @override
  Future<bool?> getPermission(String pluginId, String permission) async {
    if (throwOnRead) throw StateError('DB unavailable');
    return grants[permission];
  }

  @override
  Future<List<PluginPermissionGrant>> getPluginPermissions(String id) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<PermissionResponseAction?> _ask({
  required List<PermissionResourceType> resources,
  List<String> manifest = const [],
  Map<String, bool> grants = const {},
  bool throwOnRead = false,
}) async {
  final response = await PluginWebViewPermissionGate.respond(
    plugin: _plugin(permissions: manifest),
    request: _request(resources),
    registry: _FakeRegistry(grants: grants, throwOnRead: throwOnRead),
  );
  return response.action;
}

void main() {
  // לא `const`: המחלקה המחוללת של `PermissionResourceType` אינה חושפת
  // מופעים const, ולכן רשימה const שלהם אינה מתקמפלת.
  final clipboard = [PermissionResourceType.CLIPBOARD_READ];

  group('requiredPermissionFor', () {
    test('קריאת לוח דורשת את ההרשאה שהמשתמש מאשר', () {
      expect(
        PluginWebViewPermissionGate.requiredPermissionFor(
          PermissionResourceType.CLIPBOARD_READ,
        ),
        pluginClipboardReadPermission,
      );
    });

    test('יכולת שאינה ממופה אינה נפתחת לתוספים', () {
      for (final resource in [
        PermissionResourceType.CAMERA,
        PermissionResourceType.MICROPHONE,
        PermissionResourceType.GEOLOCATION,
        PermissionResourceType.LOCAL_FONTS,
        PermissionResourceType.FILE_READ_WRITE,
        PermissionResourceType.UNKNOWN,
      ]) {
        expect(
          PluginWebViewPermissionGate.requiredPermissionFor(resource),
          isNull,
          reason: resource.toValue(),
        );
      }
    });

    test('כל הרשאה שהשער ממפה היא הרשאה תקפה — שומר על שגיאת כתיב', () {
      for (final permission
          in PluginWebViewPermissionGate.requirements.values) {
        expect(pluginValidPermissions, contains(permission));
      }
    });
  });

  group('respond', () {
    test('הוצהר במניפסט והוענק בפועל — מאושר', () async {
      expect(
        await _ask(
          resources: clipboard,
          manifest: const [pluginClipboardReadPermission],
          grants: const {pluginClipboardReadPermission: true},
        ),
        PermissionResponseAction.GRANT,
      );
    });

    test('הוצהר אבל המשתמש עוד לא החליט — נדחה', () async {
      // `getPermission` מחזיר `null` כשאין החלטה שמורה. „טרם הוחלט” אינו
      // „אושר”, וזו אותה סמנטיקה שגשר התוסף אוכף על כל קריאת RPC.
      expect(
        await _ask(
          resources: clipboard,
          manifest: const [pluginClipboardReadPermission],
        ),
        PermissionResponseAction.DENY,
      );
    });

    test('הוצהר והמשתמש כיבה — נדחה', () async {
      expect(
        await _ask(
          resources: clipboard,
          manifest: const [pluginClipboardReadPermission],
          grants: const {pluginClipboardReadPermission: false},
        ),
        PermissionResponseAction.DENY,
      );
    });

    test('הוענק אך לא הוצהר במניפסט — נדחה', () async {
      // הענקה ללא הצהרה היא שארית: התוסף הסיר את ההרשאה מהמניפסט והרשומה
      // בבסיס הנתונים נשארה. המניפסט הוא מה שהמשתמש ראה כשאישר.
      expect(
        await _ask(
          resources: clipboard,
          grants: const {pluginClipboardReadPermission: true},
        ),
        PermissionResponseAction.DENY,
      );
    });

    test('יכולת שאינה ממופה נדחית גם לתוסף עם כל ההרשאות', () async {
      expect(
        await _ask(
          resources: [PermissionResourceType.CAMERA],
          manifest: const [pluginClipboardReadPermission],
          grants: const {pluginClipboardReadPermission: true},
        ),
        PermissionResponseAction.DENY,
      );
    });

    test('בקשה בלי משאבים אינה „הכול מותר”', () async {
      expect(
        await _ask(
          resources: [],
          manifest: const [pluginClipboardReadPermission],
          grants: const {pluginClipboardReadPermission: true},
        ),
        PermissionResponseAction.DENY,
      );
    });

    test('בקשה מרובת משאבים נדחית כשמשאב אחד אינו מותר', () async {
      // ב-Windows יש משאב אחד לכל בקשה, אבל ב-Android יש רשימה — ואישור
      // הרשימה כולה בגלל משאב אחד שאושר הוא בדיוק הדליפה שאין לה גדר.
      expect(
        await _ask(
          resources: [
            PermissionResourceType.CLIPBOARD_READ,
            PermissionResourceType.CAMERA,
          ],
          manifest: const [pluginClipboardReadPermission],
          grants: const {pluginClipboardReadPermission: true},
        ),
        PermissionResponseAction.DENY,
      );
    });

    test('כשל בקריאת ההענקה נדחה, ואינו זורק', () async {
      // חריגה כאן הייתה משאירה את ה-deferral של WebView2 פתוח — דף שממתין
      // לתשובה שלא תבוא.
      expect(
        await _ask(
          resources: clipboard,
          manifest: const [pluginClipboardReadPermission],
          throwOnRead: true,
        ),
        PermissionResponseAction.DENY,
      );
    });

    test('התשובה מחזירה את המשאבים שנשאלו — Android נשען עליהם', () async {
      final response = await PluginWebViewPermissionGate.respond(
        plugin: _plugin(permissions: const [pluginClipboardReadPermission]),
        request: _request(clipboard),
        registry: _FakeRegistry(
          grants: const {pluginClipboardReadPermission: true},
        ),
      );
      expect(response.resources, clipboard);
    });
  });

  group('declaresPermission', () {
    test('הרשאת בסיס נחשבת מוצהרת גם בלי רשומה במניפסט', () {
      expect(
        PluginWebViewPermissionGate.declaresPermission(
          _plugin(),
          pluginBaselinePermissions.first,
        ),
        isTrue,
      );
    });

    test('הצהרה ותיקה מכסה הרשאה שפוצלה ממנה', () {
      final legacy = pluginLegacyPermissionAliases.entries.first;
      expect(
        PluginWebViewPermissionGate.declaresPermission(
          _plugin(permissions: [legacy.value]),
          legacy.key,
        ),
        isTrue,
      );
    });
  });
}
