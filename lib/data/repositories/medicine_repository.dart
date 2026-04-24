import '../../models/medicine.dart';
import '../../services/hive_service.dart';
import '../remote/supabase_data_source.dart';

class MedicineRepository {
  MedicineRepository({SupabaseDataSource? remote})
      : _remote = remote ?? SupabaseDataSource();

  final SupabaseDataSource _remote;

  List<Medicine> getAll() => HiveService.getAllMedicines();

  List<Medicine> getActive() => HiveService.getActiveMedicines();

  Medicine? getById(String id) => HiveService.getMedicine(id);

  Future<Medicine> add(Medicine medicine) async {
    final saved = await HiveService.addMedicine(medicine);
    await _remote.upsertMedicine(saved);
    return saved;
  }

  Future<void> update(Medicine medicine) async {
    await HiveService.updateMedicine(medicine);
    await _remote.upsertMedicine(medicine);
  }

  Future<void> delete(String id) async {
    await HiveService.deleteMedicine(id);
    await _remote.deleteMedicine(id);
  }

  Future<void> pushLocalSnapshot() async {
    if (!_remote.isAvailable) {
      return;
    }

    for (final medicine in HiveService.getStoredMedicines()) {
      await _remote.upsertMedicine(medicine);
    }
  }
}
