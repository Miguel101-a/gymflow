# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & run

Flutter web app, Dart SDK `^3.11.1`. Common commands:

```bash
flutter pub get              # install dependencies
flutter run -d chrome        # run locally on web
flutter build web            # production build (output in build/web)
flutter analyze              # lint via flutter_lints + analysis_options.yaml
flutter test                 # run unit tests
flutter test test/foo_test.dart  # run a single test file
```

Deploy: Vercel auto-deploys from `main` (see `vercel.json`, builds `flutter build web`). Active dev branch is `claude/review-gymflow-app-YIfJz`. To ship: push to that branch → open PR → merge to `main` → Vercel deploys.

## Branching

When the user asks for a change, **create the branch yourself** with the right prefix based on the kind of work. Use a short kebab-case description after the slash (e.g. `feat/registro-dieta`, `fix/notificaciones-cancelacion`).

Allowed prefixes:

1. **`feat/`** — new functionality (e.g. `feat/mapa-gps`, `feat/buscador-ubicacion`)
2. **`fix/`** — bug fixes, including RLS / silent failures (e.g. `fix/notificaciones-instructor`)
3. **`ui/`** — visual or component changes (e.g. `ui/tarjetas-horizontales`, `ui/ajuste-imagenes`)
4. **`refactor/`** — code cleanup without behavior change (e.g. `refactor/permissions-load`)
5. **`docs/`** — documentation only (e.g. `docs/branching-guide`)
6. **`chore/`** — config, dependencies, tooling (e.g. `chore/pubspec-http`, `chore/claude-settings`)

Pick the closest match — don't invent new prefixes. If a change touches multiple categories, pick the dominant one (e.g. a feature with UI = `feat/`).

The session may already be locked to a specific branch (`claude/...`) by the harness; in that case keep working there. Only create new branches when the harness is not pinning one.

## Backend (Supabase)

Project URL and anon key are hard-coded in `lib/main.dart`. There is no `.env`. Schema lives only in Supabase — **no migration files in this repo**. When the schema needs to change, hand the SQL to the user to run manually in the Supabase SQL editor.

Schema cheat-sheet (only the parts that bite):

- `perfiles` — 1:1 with `auth.users`. Columns to know: `rol` (cliente/admin/instructor), `permisos` (JSONB), `avatar_url`, plus role-specific fields (`peso/talla/edad` for cliente, `especialidad/rating` for instructor, `rango/sede_staff/antiguedad` for admin), `notificaciones_activas`.
- `clases` — has `cancelada bool` + `cancelada_at`. Cancellation does NOT delete; it sets the flag and `activa=false`.
- `comunicaciones` — used as the notifications table for clients. **Two CHECK constraints will silently break inserts if violated:**
  - `tipo IN ('general', 'cambio_horario', 'cancelacion')`
  - `grupo_destinatario IN ('todos', 'profesores', 'clase_especifica')`
  - `autor_id` is `NOT NULL` — every insert must include `auth.currentUser.id`.
- `reservas` — `estado IN ('confirmada', 'lista_de_espera', 'cancelada', 'completada')`.
- `configuracion_gimnasio` — singleton row (`id=1`, CHECK enforces it).

RLS is enabled on every table. Admin actions need both per-row policies (e.g. `perfiles_update_own`) AND admin policies (e.g. `perfiles_update_admin`). When a Supabase `update` returns success but nothing changed, suspect a missing admin policy — see "RLS detection" below.

Storage bucket `avatars` is public-read, write-restricted to the user's own folder (`avatars/{user_id}/...`).

## Architecture

Three roles, each with its own shell + bottom nav:

- **Cliente** — `lib/screens/client/`, root `ClientShell`
- **Instructor** — `lib/screens/instructor/`, root `InstructorShell`
- **Admin** — `lib/screens/admin/`, root `AdminShell`

All routes registered in `lib/main.dart`. Protected routes are wrapped with `RoleGuard(requiredRoles: [...])`. Auth redirects happen in `_GymFlowAppState._navigateByRole` driven by `Supabase.auth.onAuthStateChange`. Instructor routes also accept `admin`.

### Two patterns that come up constantly

1. **`IndexedStack` keeps screens alive.** Each shell uses `IndexedStack` so `initState` runs once per screen, ever. State that depends on DB (permissions, lists) does NOT auto-refresh when you switch tabs. Use `RefreshNotifier` (`lib/utils/refresh_notifier.dart`) — three `ValueNotifier<int>` channels (`adminRefresh`, `clientRefresh`, `instructorRefresh`). Subscribe in `initState`, increment via `RefreshNotifier.notifyAdmin()` (etc.) after any write. The shell calls `notifyInstructor()` on tap of the CLASES tab so permissions reload without re-login.

2. **Permissions are always fetched fresh.** `lib/utils/permissions.dart` `Permissions.load()` always queries Supabase — there is no cache. Admins get all `true` synthetically; everyone else reads from `perfiles.permisos` JSONB. Use the constants on `Permissions` (e.g. `Permissions.crearClases`) to avoid typos. `Permissions.clear()` is a no-op kept for backwards compat.

Permission keys: `puede_crear_clases`, `puede_editar_clases`, `puede_cancelar_clases`, `puede_ver_alumnos`, `puede_ver_reportes`, `puede_enviar_comunicados`, `puede_administrar_usuarios`, `puede_administrar_roles`, `puede_acceder_configuracion`.

### Avatar flow

`lib/utils/avatar_uploader.dart` orchestrates pick → 1:1 crop (`crop_your_image`) → resize/compress to 200–500 KB JPEG (`package:image`) → upload to `avatars/{userId}/profile.jpg`. HEIC is rejected. Reusable widget: `lib/widgets/avatar_picker.dart`. Web-only stack — do NOT swap to `flutter_image_compress` or `image_cropper` (broken on web).

### RLS-failure detection

When updating rows that an admin should be able to edit (e.g. `role_management_screen.dart`), follow with `.select('id').maybeSingle()`:

```dart
final updated = await _supabase.from('perfiles').update({...}).eq('id', id).select('id').maybeSingle();
if (updated == null) { /* RLS blocked silently — show error */ }
```

This is the only way to detect a missing RLS policy without an exception.

### Class cancellation flow

Cancelling a class (admin or instructor with `puede_cancelar_clases`):
1. `update clases set cancelada=true, cancelada_at=now(), activa=false`.
2. Fetch `reservas` JOIN `perfiles(notificaciones_activas)` for that class.
3. For each confirmed reservation where the user opted into notifications, insert into `comunicaciones` with `tipo='cancelacion'`, `grupo_destinatario='clase_especifica'`, `autor_id=currentUser.id`, `usuario_id=<the client>`. Inserting `'clientes'` instead of `'clase_especifica'`, or omitting `autor_id`, will silently abort the insert and no client gets the notification.

## Visual conventions

`lib/theme/app_colors.dart` and `app_theme.dart` are the source of truth. Reusable widgets: `CustomTextField`, `PrimaryButton`, `AvatarPicker`. Don't restyle login/register, class detail, reservations, dashboard, or class list — keep the existing visual language.
