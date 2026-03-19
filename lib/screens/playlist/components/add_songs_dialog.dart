import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../models/playlist.dart';
import '../../../services/playlist_provider.dart';
import '../../../services/like_service.dart';
import '../../../services/recently_played.dart';
import '../../../services/remote_music_service.dart';

class AddSongsDialog extends StatefulWidget {
  final Playlist playlist;

  const AddSongsDialog({
    super.key,
    required this.playlist,
  });

  @override
  State<AddSongsDialog> createState() => _AddSongsDialogState();
}

class _AddSongsDialogState extends State<AddSongsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RemoteMusicService _musicService =
      RemoteMusicService('https://vercelapi-gamma.vercel.app/api');

  List<Song> _suggestedSongs = [];
  List<Song> _trendingSongs = [];
  List<Song> _recentSongs = [];
  List<Song> _likedSongs = [];
  List<Song> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  String _searchQuery = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedSongIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSongs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);

    try {
      final trending = await _musicService.getTrending();
      final recent = await RecentlyPlayedService().getRecentlyPlayed(limit: 50);
      final liked = context.read<LikeService>().likedSongs;

      // Get existing song IDs in the playlist
      final existingSongIds = widget.playlist.songIds.toSet();

      // Fetch suggestions based on songs already in the playlist
      final suggested = await _fetchPlaylistSuggestions(existingSongIds);

      setState(() {
        _suggestedSongs = suggested
            .where((song) => !existingSongIds.contains(song.id))
            .toList();
        // Filter out songs that are already in the playlist
        _trendingSongs = trending
            .where((song) => !existingSongIds.contains(song.id))
            .toList();
        _recentSongs = recent
            .where((song) => !existingSongIds.contains(song.id))
            .toList();
        _likedSongs = liked
            .where((song) => !existingSongIds.contains(song.id))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  /// Fetch song suggestions based on what's already in the playlist.
  /// Uses the Saavn suggestions API for up to 3 existing songs with
  /// diverse artists, then deduplicates and sorts by relevance.
  Future<List<Song>> _fetchPlaylistSuggestions(Set<String> existingIds) async {
    final playlistSongs = widget.playlist.songs;
    if (playlistSongs.isEmpty) return [];

    try {
      // Pick up to 3 diverse seed songs from the playlist
      final seenArtists = <String>{};
      final seeds = <Song>[];
      for (final song in playlistSongs) {
        final artist = song.artist.split(RegExp(r'[,&]')).first.trim().toLowerCase();
        if (seenArtists.add(artist) && song.id.isNotEmpty) {
          seeds.add(song);
          if (seeds.length >= 3) break;
        }
      }

      // If we couldn't get diverse seeds, just take the first few
      if (seeds.isEmpty) {
        seeds.addAll(playlistSongs.take(3));
      }

      // Fetch suggestions for each seed in parallel
      final results = await Future.wait(
        seeds.map((s) => _musicService.getSongSuggestions(s.id)),
      );

      // Merge, deduplicate, exclude existing playlist songs
      final seenIds = <String>{};
      final allSuggestions = <Song>[];
      for (final batch in results) {
        for (final song in batch) {
          if (song.id.isNotEmpty &&
              !existingIds.contains(song.id) &&
              seenIds.add(song.id)) {
            allSuggestions.add(song);
          }
        }
      }

      // Enforce artist diversity: max 3 per artist
      final artistCount = <String, int>{};
      final diverse = <Song>[];
      for (final song in allSuggestions) {
        final artist = song.artist.split(RegExp(r'[,&]')).first.trim().toLowerCase();
        final count = artistCount[artist] ?? 0;
        if (count < 3) {
          diverse.add(song);
          artistCount[artist] = count + 1;
        }
      }

      return diverse.take(20).toList();
    } catch (e) {
      return [];
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _searchQuery = query;
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final existingIds = widget.playlist.songIds.toSet();
      final results = await _musicService.searchSongs(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results
            .where((s) => !existingIds.contains(s.id))
            .toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleSong(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  Future<void> _addSelectedSongs() async {
    if (_selectedSongIds.isEmpty) return;

    final provider = context.read<PlaylistProvider>();

    // Get all selected songs from all tabs
    final allSongs = [..._suggestedSongs, ..._trendingSongs, ..._recentSongs, ..._likedSongs, ..._searchResults];
    final songsToAdd = allSongs
        .where((song) => _selectedSongIds.contains(song.id))
        .toList();

    for (final song in songsToAdd) {
      await provider.addSongToPlaylist(widget.playlist.id, song);
    }

    if (mounted) {
      Navigator.pop(context);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(milliseconds: 2200),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Added ${songsToAdd.length} song${songsToAdd.length > 1 ? 's' : ''} to playlist',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Songs',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Select songs to add',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Suggested'),
                    Tab(text: 'Search'),
                    Tab(text: 'Trending'),
                    Tab(text: 'Recent'),
                    Tab(text: 'Liked'),
                  ],
                ),

                Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),

                // Tab Content
                Flexible(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildSongList(_suggestedSongs, emptyMessage: 'Add songs to get suggestions'),
                            _buildSearchTab(),
                            _buildSongList(_trendingSongs),
                            _buildSongList(_recentSongs),
                            _buildSongList(_likedSongs),
                          ],
                        ),
                ),

                // Footer with Add button
                if (_selectedSongIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addSelectedSongs,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Add ${_selectedSongIds.length} Song${_selectedSongIds.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search for songs...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
        // Results
        Expanded(
          child: _searching
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : _searchQuery.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Search for songs to add',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildSongList(
                      _searchResults,
                      emptyMessage: 'No results for "$_searchQuery"',
                    ),
        ),
      ],
    );
  }

  Widget _buildSongList(List<Song> songs, {String emptyMessage = 'No songs available'}) {
    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isSelected = _selectedSongIds.contains(song.id);

        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: song.coverUrl.isNotEmpty
                ? Image.network(
                    song.coverUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.white.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: Colors.white.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white54,
                    ),
                  ),
          ),
          title: Text(
            song.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song.artist,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleSong(song.id),
            activeColor: Colors.white,
            checkColor: Colors.black,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          onTap: () => _toggleSong(song.id),
        );
      },
    );
  }
}
