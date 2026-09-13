import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/localized_text.dart';
import '../../application/product_query.dart';
import '../../data/catalog_models.dart';

/// Mobile filter bottom sheet: category, brand, price range, rating.
/// Returns the new [ProductQuery] (page reset) or null if dismissed.
/// Scrollable + keyboard-safe (§19).
Future<ProductQuery?> showFilterSheet(
  BuildContext context, {
  required ProductQuery query,
  required List<CategoryModel> categories,
  required List<String> brands,
  bool lockCategory = false,
}) {
  return showModalBottomSheet<ProductQuery>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _FilterSheet(
        query: query,
        categories: categories,
        brands: brands,
        lockCategory: lockCategory,
      ),
    ),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({
    required this.query,
    required this.categories,
    required this.brands,
    required this.lockCategory,
  });

  final ProductQuery query;
  final List<CategoryModel> categories;
  final List<String> brands;
  final bool lockCategory;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String? _category = widget.query.categorySlug;
  late String? _brand = widget.query.brand;
  late int? _rating = widget.query.minRating;
  late final _minCtl = TextEditingController(text: widget.query.minPrice ?? '');
  late final _maxCtl = TextEditingController(text: widget.query.maxPrice ?? '');
  String? _priceError;

  @override
  void dispose() {
    _minCtl.dispose();
    _maxCtl.dispose();
    super.dispose();
  }

  bool _validatePrice(AppStrings s) {
    final min = int.tryParse(_minCtl.text.trim());
    final max = int.tryParse(_maxCtl.text.trim());
    if (min != null && max != null && min > max) {
      setState(() => _priceError = s('filter.priceError'));
      return false;
    }
    setState(() => _priceError = null);
    return true;
  }

  void _apply(AppStrings s) {
    if (!_validatePrice(s)) return;
    final q = widget.query.copyWith(
      categorySlug: _category,
      brand: _brand,
      minPrice: _minCtl.text.trim().isEmpty ? null : _minCtl.text.trim(),
      maxPrice: _maxCtl.text.trim().isEmpty ? null : _maxCtl.text.trim(),
      minRating: _rating,
      offset: 0,
    );
    Navigator.pop(context, q);
  }

  void _reset() {
    setState(() {
      if (!widget.lockCategory) _category = null;
      _brand = null;
      _rating = null;
      _minCtl.clear();
      _maxCtl.clear();
      _priceError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final c = context.nova;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  Text(
                    s('filter.title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _reset, child: Text(s('filter.reset'))),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  if (!widget.lockCategory && widget.categories.isNotEmpty) ...[
                    _label(s('filter.category')),
                    _Dropdown<String?>(
                      value: _category,
                      hint: s('filter.allCategories'),
                      items: [
                        _DropItem(null, s('filter.allCategories')),
                        for (final cat in widget.categories)
                          _DropItem(cat.slug, s.pick(cat.name)),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _label(s('filter.brand')),
                  if (widget.brands.isEmpty)
                    Text(
                      s('filter.brandsUnavailable'),
                      style: TextStyle(color: c.text3, fontSize: 12.5),
                    )
                  else
                    _Dropdown<String?>(
                      value: _brand,
                      hint: s('filter.allBrands'),
                      items: [
                        _DropItem(null, s('filter.allBrands')),
                        for (final b in widget.brands) _DropItem(b, b),
                      ],
                      onChanged: (v) => setState(() => _brand = v),
                    ),
                  const SizedBox(height: 16),

                  _label(s('filter.price')),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceField(
                          controller: _minCtl,
                          hint: s('filter.priceFrom'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PriceField(
                          controller: _maxCtl,
                          hint: s('filter.priceTo'),
                        ),
                      ),
                    ],
                  ),
                  if (_priceError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _priceError!,
                        style: TextStyle(color: c.danger, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),

                  _label(s('filter.rating')),
                  Wrap(
                    spacing: 8,
                    children: [
                      _RatingChip(
                        label: s('filter.ratingAny'),
                        selected: _rating == null,
                        onTap: () => setState(() => _rating = null),
                      ),
                      for (final r in [5, 4, 3])
                        _RatingChip(
                          label: s('filter.ratingN').replaceFirst('{n}', '$r'),
                          selected: _rating == r,
                          onTap: () => setState(() => _rating = r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _apply(s),
                  child: Text(s('filter.apply')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
  );
}

class _DropItem<T> {
  const _DropItem(this.value, this.label);
  final T value;
  final String label;
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String hint;
  final List<_DropItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: c.text3)),
          items: [
            for (final it in items)
              DropdownMenuItem<T>(
                value: it.value,
                child: Text(it.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(hintText: hint),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nova;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: c.accentSoft,
      side: BorderSide(color: selected ? c.accent : c.border),
      labelStyle: TextStyle(
        color: selected ? c.accent : c.text2,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }
}
