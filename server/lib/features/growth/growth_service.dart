// 성장 — 하루 스냅샷(레벨·경험치·전투력) 저장.
import '../../core/db.dart';
import '../../nexon/nexon_client.dart';
import 'growth_repository.dart';

class GrowthService {
  final GrowthRepository repo;
  GrowthService(Db db) : repo = GrowthRepository(db);

  /// 그날 기준 레벨·경험치·전투력을 받아 저장 (API 2회).
  Future<void> snapshot(NexonClient nexon, int cid, String ocid, String day) async {
    final b = await nexon.characterBasic(ocid, day);
    final cp = await nexon.combatPower(ocid, day);
    repo.saveDaily(cid, day, b['level'], b['exp'], b['exp_rate'], cp);
  }
}
