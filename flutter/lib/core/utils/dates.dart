/// Tiny locale-neutral date formatting. The app has no `intl` dependency;
/// numeric `dd.MM.yyyy` reads the same in RU / KK / EN.
class Dates {
  const Dates._();

  static String short(DateTime d) {
    final local = d.toLocal();
    return '${_pad(local.day)}.${_pad(local.month)}.${local.year}';
  }

  static String shortWithTime(DateTime d) {
    final local = d.toLocal();
    return '${short(local)}, ${_pad(local.hour)}:${_pad(local.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
