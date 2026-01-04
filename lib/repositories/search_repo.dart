import 'dart:async';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/data/dummy_data.dart';

/// Abstract repository so UI doesn't depend on where songs come from.
/// Later you can create a DB/REST implementation that implements this.
abstract class SearchRepository {
  /// Return songs that match the [query]. Case-insensitive.
  Future<List<Song>> search(String query, {int limit = 50});

  /// Optional: return suggestions (short list).
  Future<List<String>> suggestions(String query, {int limit = 8});

  /// Optional: full list (for local features)
  Future<List<Song>> allSongs();
}

/// Local in-memory implementation using DummyData.
/// This is simple and fast for development; replace with DB or API later.
class LocalSearchRepository implements SearchRepository {
  final List<Song> _all = [
    ...DummyData.recommendedSongs,
    ...DummyData.recentSongs,
    ...DummyData.trendingSongs,
    // add any other lists you maintain
  ];

  @override
  Future<List<Song>> search(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    final results = _all.where((s) =>
    s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q)).toList();
    return results.take(limit).toList();
  }

  @override
  Future<List<String>> suggestions(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    final titles = _all.where((s) =>
    s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q)).map((s) => s.title).toSet().toList();
    return titles.take(limit).toList();
  }

  @override
  Future<List<Song>> allSongs() async => _all;
}
