/// Extension on [Iterable] to safely return the first element matching [test], or null if none found.
extension IterableExtensions<E> on Iterable<E> {
  /// Returns the first element that satisfies the [test], or `null` if no such element is found.
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
