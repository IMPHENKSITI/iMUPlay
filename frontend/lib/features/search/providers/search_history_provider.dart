import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final _box = Hive.box<List>('search_history');
  static const int _maxHistory = 10;

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    final list = _box.get('history', defaultValue: <String>[])?.cast<String>();
    state = list ?? [];
  }

  void addSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final currentHistory = List<String>.from(state);
    
    // Remove if already exists to put it at the top
    currentHistory.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    
    // Add to top
    currentHistory.insert(0, query);
    
    // Limit to _maxHistory
    if (currentHistory.length > _maxHistory) {
      currentHistory.removeLast();
    }
    
    state = currentHistory;
    _box.put('history', state);
  }

  void removeSearch(String query) {
    final currentHistory = List<String>.from(state);
    currentHistory.remove(query);
    
    state = currentHistory;
    _box.put('history', state);
  }

  void clearHistory() {
    state = [];
    _box.put('history', state);
  }
}
