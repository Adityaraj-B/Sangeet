import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/song.dart';
import '../../../models/album.dart';
import '../../../models/artist.dart';
import '../../../services/recently_played.dart';
import '../../../services/remote_music_service.dart';
import '../../../services/taste_profile_service.dart';
import '../../../repositories/artist_repo.dart';
import '../../../screens/artist/artist_screen.dart';
import '../../../screens/albums/albums_screen.dart';
import '../../../components/Song_options.dart';

/// A "For You" section in the home feed that shows personalized
/// recommendations in 3 tabs: Songs, Albums, Artists — all derived
/// from the user's recent listening history.
class ForYouSection extends StatefulWidget {
  final RemoteMusicService musicService;
  final void Function(Song) onPlaySong;

  const ForYouSection({
    super.key,
    required this.musicService,
    required this.onPlaySong,
  });

  @override
  State<ForYouSection> createState() => _ForYouSectionState();
}

class _ForYouSectionState extends State<ForYouSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _recentService = RecentlyPlayedService();
  final _tasteService = TasteProfileService();
  final _artistRepo = ArtistRepository();

  bool _loading = true;
  List<Song> _recSongs = [];
  List<Album> _recAlbums = [];
  List<Artist> _recArtists = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    try {
      final recentSongs = await _recentService.getRecentlyPlayed(limit: 30);
      if (recentSongs.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Extract unique artists from recent plays
      final artistSet = <String>{};
      for (final s in recentSongs) {
        // Take primary artist (before comma/feat)
        final primary = _primaryArtist(s.artist);
        if (primary.isNotEmpty) artistSet.add(primary);
      }
      final topArtists = artistSet.take(5).toList();

      // Also use taste profile for genre-based discovery
      final topGenres = _tasteService.topGenres(2);

      // ── Fetch all in parallel ──
      final songFutures = <Future<List<Song>>>[];
      final albumFutures = <Future<List<Album>>>[];
      final artistFutures = <Future<List<Artist>>>[];

      // Song recommendations: search by top artists + suggestions
      for (final artist in topArtists.take(3)) {
        songFutures.add(widget.musicService.searchSongs('$artist songs'));
      }
      // Add song suggestions from most recent songs
      for (final song in recentSongs.take(2)) {
        if (song.id.isNotEmpty) {
          songFutures.add(widget.musicService.getSongSuggestions(song.id));
        }
      }

      // Album recommendations: search by top artists
      for (final artist in topArtists.take(3)) {
        albumFutures.add(widget.musicService.searchAlbums('$artist album'));
      }
      if (topGenres.isNotEmpty) {
        albumFutures.add(
            widget.musicService.searchAlbums('${topGenres.first} albums'));
      }

      // Artist recommendations: search by top artists + genre
      for (final artist in topArtists.take(3)) {
        artistFutures.add(_artistRepo.searchArtists(artist, limit: 5));
      }
      for (final genre in topGenres.take(2)) {
        artistFutures.add(_artistRepo.searchArtists('$genre singer', limit: 5));
      }

      final songResults = await Future.wait(songFutures);
      final albumResults = await Future.wait(albumFutures);
      final artistResults = await Future.wait(artistFutures);

      // ── Merge & deduplicate songs ──
      final recentIds = recentSongs.map((s) => s.id).toSet();
      final seenSongIds = <String>{};
      final mergedSongs = <Song>[];
      for (final batch in songResults) {
        for (final song in batch) {
          if (song.id.isNotEmpty &&
              !recentIds.contains(song.id) &&
              seenSongIds.add(song.id)) {
            mergedSongs.add(song);
          }
        }
      }
      // Sort by playCount descending
      mergedSongs.sort((a, b) =>
          (b.playCount ?? 0).compareTo(a.playCount ?? 0));
      // Artist diversity: max 2 per artist
      final diverseSongs = _enforceDiversity(mergedSongs, 2);

      // ── Merge & deduplicate albums ──
      final seenAlbumIds = <String>{};
      final mergedAlbums = <Album>[];
      for (final batch in albumResults) {
        for (final album in batch) {
          if (album.id.isNotEmpty && seenAlbumIds.add(album.id)) {
            mergedAlbums.add(album);
          }
        }
      }
      // Album diversity: max 2 per artist
      final diverseAlbums = _enforceAlbumDiversity(mergedAlbums, 2);

      // ── Merge & deduplicate artists ──
      final seenArtistIds = <String>{};
      final mergedArtists = <Artist>[];
      for (final batch in artistResults) {
        for (final artist in batch) {
          if (artist.id.isNotEmpty && seenArtistIds.add(artist.id)) {
            mergedArtists.add(artist);
          }
        }
      }

      if (mounted) {
        setState(() {
          _recSongs = diverseSongs.take(15).toList();
          _recAlbums = diverseAlbums.take(12).toList();
          _recArtists = mergedArtists.take(12).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _primaryArtist(String artistStr) {
    // Take the first artist before commas, "feat.", "ft.", "&"
    return artistStr
        .split(RegExp(r'[,&]|feat\.|ft\.', caseSensitive: false))
        .first
        .trim();
  }

  List<Song> _enforceDiversity(List<Song> songs, int maxPerArtist) {
    final count = <String, int>{};
    final result = <Song>[];
    for (final s in songs) {
      final a = _primaryArtist(s.artist).toLowerCase();
      final c = count[a] ?? 0;
      if (c < maxPerArtist) {
        result.add(s);
        count[a] = c + 1;
      }
    }
    return result;
  }

  List<Album> _enforceAlbumDiversity(List<Album> albums, int maxPerArtist) {
    final count = <String, int>{};
    final result = <Album>[];
    for (final a in albums) {
      final artist = _primaryArtist(a.artist).toLowerCase();
      final c = count[artist] ?? 0;
      if (c < maxPerArtist) {
        result.add(a);
        count[artist] = c + 1;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if still loading or no data
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_recSongs.isEmpty && _recAlbums.isEmpty && _recArtists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Bar
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final horizontalPad = isWide ? 28.0 : 20.0;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE040FB).withValues(alpha: 0.35),
                    const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(text: 'Songs'),
                Tab(text: 'Albums'),
                Tab(text: 'Artists'),
              ],
            ),
          ),
        );
        }),
        const SizedBox(height: 16),

        // Tab Content
        SizedBox(
          height: 210,
          child: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSongsTab(),
              _buildAlbumsTab(),
              _buildArtistsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Songs Tab ──────────────────────────────────────────────────

  Widget _buildSongsTab() {
    if (_recSongs.isEmpty) {
      return _buildEmptyTab('No song recommendations yet', Icons.music_note_rounded);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      final pad = isWide ? 28.0 : 20.0;

      return ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: pad),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recSongs.length,
        separatorBuilder: (_, __) => SizedBox(width: isWide ? 18 : 14),
        itemBuilder: (context, index) {
          final song = _recSongs[index];
          return _ForYouSongCard(
            song: song,
            onTap: () => widget.onPlaySong(song),
          );
        },
      );
    });
  }

  // ── Albums Tab ─────────────────────────────────────────────────

  Widget _buildAlbumsTab() {
    if (_recAlbums.isEmpty) {
      return _buildEmptyTab('No album recommendations yet', Icons.album_rounded);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      final pad = isWide ? 28.0 : 20.0;

      return ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: pad),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recAlbums.length,
        separatorBuilder: (_, __) => SizedBox(width: isWide ? 18 : 14),
      itemBuilder: (context, index) {
        final album = _recAlbums[index];
        return _ForYouAlbumCard(
          album: album,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumScreen(
                  album: album,
                  musicService: widget.musicService,
                  onPlaySong: widget.onPlaySong,
                ),
              ),
            );
          },
        );
      },
    );
    });
  }

  // ── Artists Tab ────────────────────────────────────────────────

  Widget _buildArtistsTab() {
    if (_recArtists.isEmpty) {
      return _buildEmptyTab(
          'No artist recommendations yet', Icons.person_rounded);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      final pad = isWide ? 28.0 : 20.0;

      return ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: pad),
        scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: _recArtists.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final artist = _recArtists[index];
        return _ForYouArtistCard(
          artist: artist,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArtistScreen(
                  artistId: artist.id,
                  musicService: widget.musicService,
                  onPlaySong: widget.onPlaySong,
                ),
              ),
            );
          },
        );
      },
    );
    });
  }

  Widget _buildEmptyTab(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.15), size: 40),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Card Widgets — match existing app glass/card style
// ═══════════════════════════════════════════════════════════════════

class _ForYouSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _ForYouSongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => SongOptionsSheet.show(context, song, onPlay: onTap),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover art
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 1,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    song.coverUrl.isNotEmpty
                        ? Image.network(
                            song.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholder(Icons.music_note_rounded),
                          )
                        : _placeholder(Icons.music_note_rounded),
                    // Glass shine
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Play button
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForYouAlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback onTap;

  const _ForYouAlbumCard({required this.album, required this.onTap});

  @override
  State<_ForYouAlbumCard> createState() => _ForYouAlbumCardState();
}

class _ForYouAlbumCardState extends State<_ForYouAlbumCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.album.coverUrl.isNotEmpty
                          ? Image.network(
                              widget.album.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholder(Icons.album_rounded),
                            )
                          : _placeholder(Icons.album_rounded),
                      // Glass shine
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForYouArtistCard extends StatefulWidget {
  final Artist artist;
  final VoidCallback onTap;

  const _ForYouArtistCard({required this.artist, required this.onTap});

  @override
  State<_ForYouArtistCard> createState() => _ForYouArtistCardState();
}

class _ForYouArtistCardState extends State<_ForYouArtistCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular avatar
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE040FB).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: widget.artist.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.artist.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _circlePlaceholder(),
                        )
                      : _circlePlaceholder(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.artist.type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circlePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE040FB).withValues(alpha: 0.15),
            const Color(0xFF7C4DFF).withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white.withValues(alpha: 0.3),
          size: 36,
        ),
      ),
    );
  }
}

// ── Shared placeholder ──────────────────────────────────────────

Widget _placeholder(IconData icon) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
      ),
    ),
    child: Center(
      child: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.15),
        size: 36,
      ),
    ),
  );
}


