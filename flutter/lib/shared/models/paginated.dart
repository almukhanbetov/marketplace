import '../../core/api/api_client.dart';

/// A page of list results plus its [ApiListMeta] (limit/offset/total).
/// Feature repositories return this from `GET` endpoints that use the
/// backend's `{ data: [...], meta: {...} }` envelope.
class Paginated<T> {
  const Paginated({required this.items, required this.meta});

  final List<T> items;
  final ApiListMeta meta;

  bool get hasMore => meta.hasMore;
  int get nextOffset => meta.offset + meta.limit;

  const Paginated.empty()
    : items = const [],
      meta = const ApiListMeta(limit: 0, offset: 0, total: 0);
}
