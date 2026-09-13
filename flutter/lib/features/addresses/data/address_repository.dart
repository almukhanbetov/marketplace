import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import 'address_models.dart';

class AddressRepository {
  AddressRepository(this._api);

  final ApiClient _api;

  Future<List<AddressModel>> list() async {
    final data = await _api.get('/me/addresses');
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((m) => AddressModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<AddressModel> create(AddressInput input) async {
    final data = await _api.post('/me/addresses', body: input.toJson());
    return AddressModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AddressModel> update(int id, AddressInput input) async {
    final data = await _api.put('/me/addresses/$id', body: input.toJson());
    return AddressModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(int id) => _api.delete('/me/addresses/$id');

  Future<void> setDefault(int id) => _api.patch('/me/addresses/$id/default');
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(ref.watch(apiClientProvider));
});
