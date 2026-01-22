import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/models/song.dart';
import '../../components/song_options.dart';
import '../../services/recently_played.dart';

class RecentlyPlayedScreen extends StatefulWidget {
  final void Function(Song) onPlaySong;

  const RecentlyPlayedScreen({
    super.key,
    required this.onPlaySong,
  });

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  final RecentlyPlayedService _recentService = RecentlyPlayedService();
  Map<String, List<Song>> _groupedSongs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentlyPlayed();
  }

  Future<void> _loadRecentlyPlayed() async {
    setState(() => _loading = true);
    final grouped = await _recentService.getRecentGroupedByDate();
    if (!mounted) return;
    setState(() {
      _groupedSongs = grouped;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => _PremiumAlertDialog(
        title: 'Clear History?',
        content: 'This will remove all songs from your recently played history.',
        confirmText: 'Clear All',
        isDestructive: true,
      ),
    );

    if (confirm == true) {
      await _recentService.clearAll();
      _loadRecentlyPlayed();
    }
  }

  Song? get _mostRecentSong {
    if (_groupedSongs.isEmpty) return null;

    for (final key in const [
      'Just Now',
      'Today',
      'Yesterday',
      'This Week',
      'This Month',
      'Older',
    ]) {
      final songs = _groupedSongs[key];
      if (songs != null && songs.isNotEmpty) {
        return songs.first;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final heroSong = _mostRecentSong;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (heroSong != null && heroSong.coverUrl.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(heroSong.coverUrl),
                      fit: BoxFit.cover,
                      opacity: 0.5,
                    ),
                  ),
                ),
              ),
            ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    kBackgroundColor.withValues(alpha: 0.8),
                    kBackgroundColor,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (_groupedSongs.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: _clearAll,
                    ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final collapsed =
                        constraints.maxHeight <= kToolbarHeight + 10;

                    return FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
                      title: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: collapsed ? 1 : 0,
                        child: const Text(
                          'Recently Played',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      background: const Padding(
                        padding: EdgeInsets.fromLTRB(20, 80, 20, 16),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            'Recently Played',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

              if (!_loading && _groupedSongs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No History Yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_loading && _groupedSongs.isNotEmpty)
                ...const [
                  'Just Now',
                  'Today',
                  'Yesterday',
                  'This Week',
                  'This Month',
                  'Older',
                ]
                    .where((key) => _groupedSongs.containsKey(key))
                    .expand((key) {
                  final songs = _groupedSongs[key]!;
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                        child: Text(
                          key.toUpperCase(),
                          style: const TextStyle(
                            color: kAccentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = songs[index];
                          return _buildGlassSongTile(song);
                        },
                        childCount: songs.length,
                      ),
                    ),
                  ];
                }).toList(),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSongTile(Song song) {
    return Dismissible(
      key: ValueKey(song.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _recentService.removeSong(song.id);
        _loadRecentlyPlayed();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => widget.onPlaySong(song),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.coverUrl.isNotEmpty
                        ? Image.network(
                            song.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderImage(),
                          )
                        : _placeholderImage(),
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  color: Colors.grey[400],
                  onPressed: () {
                    SongOptionsSheet.show(
                      context,
                      song,
                      onPlay: () => widget.onPlaySong(song),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: const Color(0xFF2C2C2C),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 20),
      ),
    );
  }
}

class _PremiumAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final bool isDestructive;

  const _PremiumAlertDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDestructive ? Colors.redAccent : Colors.white,
                        foregroundColor:
                            isDestructive ? Colors.white : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
