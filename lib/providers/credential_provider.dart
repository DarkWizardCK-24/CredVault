import 'package:cred_vault/core/password/password_strength.dart';
import 'package:cred_vault/models/credential_category.dart';
import 'package:cred_vault/models/credential_model.dart';
import 'package:flutter/foundation.dart';

enum CredentialSort {
  recent('Recently updated'),
  name('Name (A-Z)'),
  oldest('Oldest first'),
  weakest('Weakest first');

  final String label;

  const CredentialSort(this.label);
}

/// What the vault list currently shows: search text, category, favourites
/// filter and sort order. (The credentials themselves live in `VaultProvider`.)
class CredentialProvider extends ChangeNotifier {
  String _query = '';
  CredentialCategory? _category;
  bool _favoritesOnly = false;
  CredentialSort _sort = CredentialSort.recent;

  String get query => _query;
  CredentialCategory? get category => _category;
  bool get favoritesOnly => _favoritesOnly;
  CredentialSort get sort => _sort;
  bool get isFiltering =>
      _query.isNotEmpty || _category != null || _favoritesOnly;

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// `null` shows every category.
  void setCategory(CredentialCategory? value) {
    _category = value;
    _favoritesOnly = false;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    _favoritesOnly = value;
    if (value) _category = null;
    notifyListeners();
  }

  void setSort(CredentialSort value) {
    _sort = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _category = null;
    _favoritesOnly = false;
    notifyListeners();
  }

  /// [items] filtered and sorted for display. Favourites always come first
  /// when sorting by recency or name.
  List<Credential> apply(List<Credential> items) {
    final q = _query.trim().toLowerCase();
    final result = items.where((c) {
      if (_favoritesOnly && !c.favorite) return false;
      if (_category != null && c.category != _category) return false;
      if (q.isEmpty) return true;
      return c.displayName.toLowerCase().contains(q) ||
          c.platform.toLowerCase().contains(q) ||
          c.username.toLowerCase().contains(q) ||
          c.url.toLowerCase().contains(q) ||
          c.notes.toLowerCase().contains(q);
    }).toList();

    final scores = _sort == CredentialSort.weakest
        ? {
            for (final c in items)
              c.id: PasswordStrengthEstimator.evaluate(c.password).bits,
          }
        : const <String, double>{};

    int base(Credential a, Credential b) {
      switch (_sort) {
        case CredentialSort.recent:
          return b.updatedAt.compareTo(a.updatedAt);
        case CredentialSort.name:
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        case CredentialSort.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case CredentialSort.weakest:
          return scores[a.id]!.compareTo(scores[b.id]!);
      }
    }

    // Favourites first when sorting by recency or name; one comparator, so
    // the result doesn't depend on the sort being stable.
    final favoritesFirst =
        _sort == CredentialSort.recent || _sort == CredentialSort.name;
    result.sort((a, b) {
      if (favoritesFirst && a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      return base(a, b);
    });
    return result;
  }

  /// How many items are in each category (for the filter chips).
  static Map<CredentialCategory, int> countByCategory(List<Credential> items) {
    final counts = <CredentialCategory, int>{};
    for (final c in items) {
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    return counts;
  }
}
