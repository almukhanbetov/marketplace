/// `/me/addresses` item. Only the fields the backend supports (§36).
class AddressModel {
  const AddressModel({
    required this.id,
    required this.city,
    required this.street,
    required this.house,
    required this.isDefault,
    this.title,
    this.apartment,
    this.postalCode,
  });

  final int id;
  final String? title;
  final String city;
  final String street;
  final String house;
  final String? apartment;
  final String? postalCode;
  final bool isDefault;

  /// "ул. Достык, 89, кв. 12" — for a one-line card subtitle.
  String get oneLine => [
    street,
    house,
    if ((apartment ?? '').isNotEmpty) 'кв. $apartment',
  ].where((p) => p.isNotEmpty).join(', ');

  factory AddressModel.fromJson(Map<String, dynamic> j) => AddressModel(
    id: (j['id'] as num).toInt(),
    title: j['title'] as String?,
    city: j['city'] as String? ?? '',
    street: j['street'] as String? ?? '',
    house: j['house'] as String? ?? '',
    apartment: j['apartment'] as String?,
    postalCode: j['postal_code'] as String?,
    isDefault: j['is_default'] as bool? ?? false,
  );
}

/// Typed write shape shared by create + edit. Backend validates
/// city/street/house as required.
class AddressInput {
  const AddressInput({
    required this.city,
    required this.street,
    required this.house,
    this.title,
    this.apartment,
    this.postalCode,
    this.isDefault = false,
  });

  final String? title;
  final String city;
  final String street;
  final String house;
  final String? apartment;
  final String? postalCode;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
    if ((title ?? '').trim().isNotEmpty) 'title': title!.trim(),
    'city': city.trim(),
    'street': street.trim(),
    'house': house.trim(),
    if ((apartment ?? '').trim().isNotEmpty) 'apartment': apartment!.trim(),
    if ((postalCode ?? '').trim().isNotEmpty) 'postal_code': postalCode!.trim(),
    'is_default': isDefault,
  };

  factory AddressInput.fromModel(AddressModel a) => AddressInput(
    title: a.title,
    city: a.city,
    street: a.street,
    house: a.house,
    apartment: a.apartment,
    postalCode: a.postalCode,
    isDefault: a.isDefault,
  );
}
