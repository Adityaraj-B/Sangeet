import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import '../models/playlist_track_model.dart';
import '../models/song.dart';
import '../services/spotify_playlist_service.dart';
import '../services/remote_music_service.dart';
import '../services/playlist_provider.dart';

class SpotifyImportScreen extends StatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  State<SpotifyImportScreen> createState() => _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends State<SpotifyImportScreen> {
  final _urlController = TextEditingController();
  final _spotifyService = SpotifyPlaylistService();
  final _musicService =
      RemoteMusicService('https://vercelapi-gamma.vercel.app/api');

  List<PlaylistTrack> _tracks = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _error;

  // Tracks matched → Saavn Song objects (filled during save)
  final Map<int, Song?> _matchedSongs = {};
  int _matchProgress = 0;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ── Import ─────────────────────────────────────────────────────

  Future<void> _importPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _tracks = [];
      _isSaved = false;
      _matchedSongs.clear();
      _matchProgress = 0;
    });

    try {
      final tracks = await _spotifyService.importSpotifyPlaylist(url);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on ParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong: $e';
        _isLoading = false;
      });
    }
  }

  // ── Save to Sangeet ────────────────────────────────────────────

  Future<void> _saveToSangeet() async {
    if (_tracks.isEmpty || _isSaving || _isSaved) return;

    setState(() {
      _isSaving = true;
      _matchProgress = 0;
    });

    try {
      final provider = context.read<PlaylistProvider>();

      // Create a new playlist
      final playlist = await provider.createPlaylist(
        'Spotify Import',
        description: 'Imported from Spotify',
      );

      if (playlist == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to create playlist';
          _isSaving = false;
        });
        return;
      }

      // Match each Spotify track to a Saavn song via search
      int matched = 0;
      for (int i = 0; i < _tracks.length; i++) {
        final track = _tracks[i];
        if (!mounted) return;
        setState(() => _matchProgress = i + 1);

        try {
          // Search Saavn: "title artist" gives best results
          final query = '${track.title} ${track.artist.split(",").first.trim()}';
          final results = await _musicService.searchSongs(query);

          if (results.isNotEmpty) {
            // Pick best match — prefer exact title match
            final best = _pickBestMatch(results, track);
            _matchedSongs[i] = best;
            await provider.addSongToPlaylist(playlist.id, best);
            matched++;
          } else {
            _matchedSongs[i] = null;
          }
        } catch (_) {
          _matchedSongs[i] = null;
        }

        // Small delay to avoid rate limiting the API
        if (i < _tracks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });

      _showSnackBar(
        'Imported $matched of ${_tracks.length} songs to "Spotify Import"',
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error saving: $e';
        _isSaving = false;
      });
    }
  }

  /// Pick the best matching Saavn [Song] for a [PlaylistTrack].
  Song _pickBestMatch(List<Song> results, PlaylistTrack track) {
    final targetTitle = track.title.toLowerCase().trim();
    final targetArtist = track.artist.split(',').first.trim().toLowerCase();

    // Score each result
    Song best = results.first;
    int bestScore = -1;

    for (final song in results) {
      int score = 0;
      final songTitle = song.title.toLowerCase().trim();
      final songArtist = song.artist.toLowerCase().trim();

      // Exact title match
      if (songTitle == targetTitle) {
        score += 100;
      } else if (songTitle.contains(targetTitle) ||
          targetTitle.contains(songTitle)) {
        score += 50;
      }

      // Artist match
      if (songArtist.contains(targetArtist) ||
          targetArtist.contains(songArtist)) {
        score += 40;
      }

      // Duration similarity (within 5 seconds = great match)
      if (track.durationMs > 0 && song.duration.inMilliseconds > 0) {
        final diff =
            (song.duration.inMilliseconds - track.durationMs).abs();
        if (diff < 5000) {
          score += 20;
        } else if (diff < 15000) {
          score += 10;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = song;
      }
    }

    return best;
  }

  void _showSnackBar(String message, {IconData icon = Icons.info}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2500),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
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

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildUrlInput(),
            if (_error != null) _buildErrorBanner(),
            if (_isLoading) _buildLoadingIndicator(),
            if (_isSaving) _buildSaveProgress(),
            if (_tracks.isNotEmpty && !_isLoading) Expanded(child: _buildTrackList()),
            if (_tracks.isNotEmpty && !_isLoading && !_isSaving) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Import from Spotify',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Spotify green badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1DB954).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note_rounded,
                    color: const Color(0xFF1DB954), size: 14),
                const SizedBox(width: 4),
                const Text(
                  'Spotify',
                  style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Paste Spotify playlist link...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 15,
                ),
                prefixIcon: Icon(Icons.link_rounded,
                    color: Colors.white.withValues(alpha: 0.45), size: 22),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.45), size: 20),
                        onPressed: () {
                          _urlController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _importPlaylist,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF1DB954).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Import',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.redAccent.withValues(alpha: 0.9), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded,
                  color: Colors.redAccent.withValues(alpha: 0.6), size: 18),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _error = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF1DB954),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 20),
            Text(
              'Fetching playlist...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveProgress() {
    final progress = _tracks.isNotEmpty
        ? _matchProgress / _tracks.length
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFF1DB954),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Matching songs... $_matchProgress / ${_tracks.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                '${_tracks.length} tracks found',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_isSaved)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: const Color(0xFF1DB954), size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      'Saved',
                      style: TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // Track list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _tracks.length,
            itemBuilder: (context, index) {
              final track = _tracks[index];
              final matched = _matchedSongs[index];
              final wasProcessed = _matchedSongs.containsKey(index);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: track.coverUrl.isNotEmpty
                      ? Image.network(
                          track.coverUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderArt(),
                        )
                      : _placeholderArt(),
                ),
                title: Text(
                  track.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${track.artist} • ${track.album}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (wasProcessed)
                      Icon(
                        matched != null
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color: matched != null
                            ? const Color(0xFF1DB954)
                            : Colors.white.withValues(alpha: 0.3),
                        size: 18,
                      ),
                    if (!wasProcessed) ...[
                      Text(
                        track.formattedDuration,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _placeholderArt() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.3), size: 24),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isSaved || _isSaving ? null : _saveToSangeet,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSaved
                ? const Color(0xFF1DB954).withValues(alpha: 0.3)
                : Colors.white,
            foregroundColor: _isSaved ? const Color(0xFF1DB954) : Colors.black,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.15),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            _isSaved
                ? 'Saved to Sangeet  ✓'
                : 'Save to Sangeet  (${_tracks.length} songs)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
    );
  }
}



