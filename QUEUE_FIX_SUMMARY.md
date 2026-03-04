# Queue Fix Summary

## Problem
When playing a song from a playlist or album:
1. If left untouched, all songs in the playlist would play correctly
2. But when pressing "next", the app would play songs **outside** the playlist (similar songs)
3. Users wanted the next button to play the next song **in the playlist**, and only play similar songs after all playlist songs are finished

## Root Cause
The issue was the **order of operations**:

1. When a song was tapped from playlist/album, `onPlaySong(song)` was called FIRST
2. This triggered `playSong()` which checked if there were manual songs in the queue
3. Since `addAllToQueue()` hadn't been called yet, the queue was empty
4. So `playSong()` would immediately load similar songs
5. THEN `addAllToQueue()` was called, adding playlist songs to the queue
6. This resulted in similar songs being mixed with playlist songs

## Solution

The fix was simple: **Add remaining songs to the queue BEFORE playing the song**.

This ensures that when `playSong()` is called, it sees the manual (playlist) songs already in the queue and skips loading similar songs.

### Files Modified

#### 1. `lib/screens/playlist/components/songs.dart`
```dart
void _handleSongTap(Song song) {
  // Find the index FIRST
  final songIndex = songs.indexWhere((s) => s.id == song.id);

  // Add remaining songs to queue BEFORE playing
  if (songIndex >= 0 && songIndex < songs.length - 1) {
    final remainingSongs = songs.sublist(songIndex + 1);
    queueService.addAllToQueue(remainingSongs);
  }
  
  // NOW play the tapped song
  onPlaySong(song);
}
```

#### 2. `lib/screens/playlist/components/actions.dart`
Fixed `_shufflePlaylist()` and `_playAllSongs()` to add songs to queue before playing.

#### 3. `lib/screens/albums/albums_screen.dart`
Fixed `_playAll()` and `_handleSongTap()` to add songs to queue before playing.

#### 4. `lib/screens/artist/artist_screen.dart`
Fixed `_playAll()`, `_shufflePlay()`, and individual song tap handlers in `_PopularSongsTab` and `_LatestSongsTab`.

#### 5. `lib/services/queue.dart`
Modified `playSong()` and `playNext()` methods to check for manual songs in queue before loading similar songs.

## Behavior After Fix

### Playing from a Playlist/Album
1. User taps a song (e.g., song #3 out of 10)
2. Songs #4-10 are added to the queue as "manual" items
3. Song #3 starts playing
4. `playSong()` sees manual songs in queue → skips loading similar songs
5. When user presses "next":
   - Song #4 plays (from the playlist)
   - Then #5, #6, #7, etc.
6. After song #10 finishes (queue is empty):
   - Similar songs are loaded and played
   - This provides continuous playback beyond the playlist

