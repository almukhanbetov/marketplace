import 'package:flutter_test/flutter_test.dart';
import 'package:nova_marketplace/features/catalog/application/product_query.dart';

void main() {
  test('toParams omits empty values and includes limit/offset', () {
    const q = ProductQuery();
    expect(q.toParams(), {'limit': 20, 'offset': 0});

    const full = ProductQuery(
      search: ' iphone ',
      categorySlug: 'electronics',
      brand: 'Apple',
      minPrice: '100000',
      maxPrice: '500000',
      minRating: 4,
      sort: ProductSort.discountDesc,
      offset: 40,
    );
    expect(full.toParams(), {
      'search': 'iphone',
      'category': 'electronics',
      'brand': 'Apple',
      'min_price': '100000',
      'max_price': '500000',
      'rating': 4,
      'sort': 'discount_desc',
      'limit': 20,
      'offset': 40,
    });
  });

  test('relevance sort omits the sort param', () {
    expect(
      const ProductQuery(
        sort: ProductSort.relevance,
      ).toParams().containsKey('sort'),
      isFalse,
    );
  });

  test('copyWith keeps unset fields, nulls explicit nulls', () {
    const q = ProductQuery(categorySlug: 'a', brand: 'B', minRating: 5);
    expect(q.copyWith(search: 'x').categorySlug, 'a'); // kept
    expect(q.copyWith(categorySlug: null).categorySlug, isNull); // cleared
    expect(q.copyWith(categorySlug: null).brand, 'B'); // untouched
  });

  test('identity ignores offset (stale-response key)', () {
    const a = ProductQuery(search: 'x', offset: 0);
    const b = ProductQuery(search: 'x', offset: 20);
    const c = ProductQuery(search: 'y', offset: 0);
    expect(a.identity, b.identity);
    expect(a.identity, isNot(c.identity));
  });

  test('hasActiveFilters / activeFilterCount', () {
    expect(const ProductQuery(search: 'x').hasActiveFilters, isFalse);
    expect(
      const ProductQuery(categorySlug: 'a', minRating: 4).activeFilterCount,
      2,
    );
  });

  test('cleared() drops filters but keeps search + sort', () {
    const q = ProductQuery(
      search: 'x',
      sort: ProductSort.priceAsc,
      categorySlug: 'a',
      brand: 'b',
      minRating: 4,
    );
    final cleared = q.cleared();
    expect(cleared.search, 'x');
    expect(cleared.sort, ProductSort.priceAsc);
    expect(cleared.hasActiveFilters, isFalse);
  });

  test('ProductSort.fromApi round-trips', () {
    for (final s in ProductSort.values) {
      expect(ProductSort.fromApi(s.apiValue.isEmpty ? null : s.apiValue), s);
    }
  });
}
