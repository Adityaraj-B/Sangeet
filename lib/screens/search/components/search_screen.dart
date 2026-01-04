import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/repositories/search_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/size_config.dart';
import 'package:sangeet/models/song.dart';

class SearchScreen extends StatefulWidget {
  final SearchRepository repository;
  final void Function(Song)? onPlay;

  const SearchScreen({
    Key? key,
    required this.repository,
    this.onPlay,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _kRecentKey = 'recent_searches_v1';

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<Song> _results = [];
  List<String> _suggestions = [];
  List<String> _recent = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _ctrl.addListener(_onChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChange() {
    final text = _ctrl.text;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
          () => _performQuery(text),
    );
    _fetchSuggestions(text);
  }

  Future<void> _performQuery(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final res = await widget.repository.search(query, limit: 200);
    if (!mounted) return;

    setState(() {
      _results = res;
      _loading = false;
    });

    await _addRecent(query);
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    final sug = await widget.repository.suggestions(query, limit: 8);
    if (!mounted) return;

    setState(() => _suggestions = sug);
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recent = prefs.getStringList(_kRecentKey) ?? []);
  }

  Future<void> _addRecent(String item) async {
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_kRecentKey) ?? [];

    list.remove(item);
    list.insert(0, item);
    if (list.length > 12) list = list.sublist(0, 12);

    await prefs.setStringList(_kRecentKey, list);
    if (mounted) setState(() => _recent = list);
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentKey);
    if (mounted) setState(() => _recent = []);
  }

  void _applySuggestion(String suggestion) {
    _ctrl.text = suggestion;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: suggestion.length));
    _focusNode.unfocus();
    _performQuery(suggestion);
  }

  Widget _buildSearchField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding:
          EdgeInsets.symmetric(horizontal: getProportionateScreenWidth(14)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, albums',
                    hintStyle:
                    TextStyle(color: Colors.white.withOpacity(0.7)),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performQuery,
                  cursorColor: kPrimaryColor,
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _ctrl.clear();
                    setState(() {
                      _results = [];
                      _suggestions = [];
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestions
            .map(
              (s) => ActionChip(
            label:
            Text(s, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.white.withOpacity(0.04),
            onPressed: () => _applySuggestion(s),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildRecent() {
    if (_recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent searches',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _clearRecent,
              child: const Text('Clear',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recent.map((r) {
            return InputChip(
              label: Text(r,
                  style: const TextStyle(color: Colors.white)),
              onPressed: () => _applySuggestion(r),
              deleteIcon:
              const Icon(Icons.close, size: 18, color: Colors.white54),
              onDeleted: () async {
                final prefs = await SharedPreferences.getInstance();
                final list =
                    prefs.getStringList(_kRecentKey) ?? [];
                list.remove(r);
                await prefs.setStringList(_kRecentKey, list);
                if (mounted) setState(() => _recent = list);
              },
              backgroundColor: Colors.white.withOpacity(0.03),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Text(
            _ctrl.text.isEmpty
                ? 'Start typing to find songs'
                : 'No results',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final song = _results[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => widget.onPlay?.call(song),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              song.coverUrl,
              height: 56,
              width: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 56,
                width: 56,
                color: kSurfaceColor,
              ),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.65)),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_fill,
                color: Colors.white),
            onPressed: () => widget.onPlay?.call(song),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);

    final bottomInset = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:
        Text('Discover', style: headingStyleBuild(context)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          getProportionateScreenWidth(16),
          getProportionateScreenHeight(12),
          getProportionateScreenWidth(16),
          bottomInset,
        ),
        keyboardDismissBehavior:
        ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchField(),
            _buildSuggestions(),
            const SizedBox(height: 12),
            _buildRecent(),
            const SizedBox(height: 14),
            _buildResults(),
          ],
        ),
      ),
    );
  }
}
