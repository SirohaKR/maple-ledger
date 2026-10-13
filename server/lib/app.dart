// 서버 조립 — 기능 폴더들의 DB 테이블과 API 주소를 모아 하나의 서버로.
// 새 기능을 추가하면: features/<기능>/ 에 schema·repository·routes를 만들고 아래 두 목록에 한 줄씩.
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'core/context.dart';
import 'core/http.dart';
import 'core/schema.dart';
import 'features/admin/admin_routes.dart';
import 'features/auth/auth_middleware.dart';
import 'features/auth/auth_routes.dart';
import 'features/auth/auth_schema.dart';
import 'features/bosses/bosses_routes.dart';
import 'features/bosses/bosses_schema.dart';
import 'features/changelog/changelog_routes.dart';
import 'features/changelog/changelog_schema.dart';
import 'features/characters/characters_routes.dart';
import 'features/characters/characters_schema.dart';
import 'features/growth/growth_routes.dart';
import 'features/growth/growth_schema.dart';
import 'features/hunts/hunts_routes.dart';
import 'features/hunts/hunts_schema.dart';
import 'features/incomes/incomes_routes.dart';
import 'features/incomes/incomes_schema.dart';
import 'features/notices/notices_routes.dart';
import 'features/notices/notices_schema.dart';
import 'features/settings/settings_routes.dart';
import 'features/settings/settings_schema.dart';
import 'features/spend/spend_routes.dart';
import 'features/spend/spend_schema.dart';
import 'features/stats/stats_routes.dart';
import 'features/sync/sync_routes.dart';
import 'features/sync/sync_schema.dart';
import 'features/todo/todo_routes.dart';
import 'features/web/web_routes.dart';
import 'features/week/week_routes.dart';
import 'features/week/week_schema.dart';
import 'nexon/api_cache.dart';

/// 모든 테이블 (참조하는 테이블이 먼저 오게).
final allSchemas = [
  authSchema,
  settingsSchema,
  changelogSchema,
  bossesSchema,
  charactersSchema,
  weekSchema,
  syncSchema,
  huntsSchema,
  incomesSchema,
  spendSchema,
  growthSchema,
  apiCacheSchema,
  noticesSchema,
];

/// DB 준비 + API 주소 등록 → 요청을 처리하는 핸들러.
Handler buildApp(AppContext app) {
  applySchemas(app.db, allSchemas);

  final router = Router();
  for (final routes in [
    AuthRoutes(app).register,
    AdminRoutes(app).register,
    ChangelogRoutes(app).register,
    SettingsRoutes(app).register,
    BossesRoutes(app).register,
    CharactersRoutes(app).register,
    WeekRoutes(app).register,
    SyncRoutes(app).register,
    HuntsRoutes(app).register,
    IncomesRoutes(app).register,
    SpendRoutes(app).register,
    GrowthRoutes(app).register,
    TodoRoutes(app).register,
    NoticesRoutes(app).register,
    StatsRoutes(app).register,
    WebRoutes(app).register,
  ]) {
    routes(router);
  }
  router.all('/api/<rest|.*>', (Request req) => json({'error': '없는 주소예요'}, status: 404));

  return const Pipeline()
      .addMiddleware(errorMiddleware())
      .addMiddleware(authMiddleware(app))
      .addHandler(router.call);
}
