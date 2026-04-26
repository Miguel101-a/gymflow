import 'package:supabase_flutter/supabase_flutter.dart';

class Permissions {
  static const String crearClases = 'puede_crear_clases';
  static const String editarClases = 'puede_editar_clases';
  static const String cancelarClases = 'puede_cancelar_clases';
  static const String verAlumnos = 'puede_ver_alumnos';
  static const String verReportes = 'puede_ver_reportes';
  static const String enviarComunicados = 'puede_enviar_comunicados';
  static const String administrarUsuarios = 'puede_administrar_usuarios';
  static const String administrarRoles = 'puede_administrar_roles';
  static const String accederConfiguracion = 'puede_acceder_configuracion';

  static Map<String, bool>? _cache;

  static Future<Map<String, bool>> load() async {
    if (_cache != null) return _cache!;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      _cache = {};
      return _cache!;
    }
    try {
      final profile = await supabase
          .from('perfiles')
          .select('rol, permisos')
          .eq('id', user.id)
          .single();
      final rol = profile['rol'] as String? ?? 'cliente';
      if (rol == 'admin') {
        _cache = {
          crearClases: true,
          editarClases: true,
          cancelarClases: true,
          verAlumnos: true,
          verReportes: true,
          enviarComunicados: true,
          administrarUsuarios: true,
          administrarRoles: true,
          accederConfiguracion: true,
        };
      } else {
        final permisos = profile['permisos'];
        if (permisos is Map) {
          _cache = Map<String, bool>.from(
            permisos.map((k, v) => MapEntry(k.toString(), v == true)),
          );
        } else {
          _cache = {};
        }
      }
      return _cache!;
    } catch (_) {
      _cache = {};
      return _cache!;
    }
  }

  static bool can(String key) => _cache?[key] ?? false;

  static void clear() => _cache = null;
}
