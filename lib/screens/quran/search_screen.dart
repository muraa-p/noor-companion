import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/quran_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/ayah_tile.dart';
import 'surah_reader_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  // All ayahs (Arabic + English) once loaded, for in-memory search.
  List<Ayah> _corpus = const [];
  List<Ayah> _results = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    final quran = context.read<QuranProvider>();
    quran.ensureLoaded();
    quran.whenLoaded().then((_) {
      if (!mounted) return;
      final corpus = <Ayah>[];
      for (final surah in quran.surahs) {
        corpus.addAll(surah.ayahs);
      }
      setState(() {
        _corpus = corpus;
        if (_query.isNotEmpty) _runSearch(_query);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _searching = true;
      });
      _runSearch(_query);
    });
  }

  void _runSearch(String q) {
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    final lower = q.toLowerCase();
    final qStripped = Arabic.stripTashkeel(lower);
    // Diacritic-insensitive Arabic search plus plain English matching.
    final results = _corpus.where((ayah) {
      final ar = Arabic.stripTashkeel(ayah.arabic).toLowerCase();
      final en = ayah.english.toLowerCase();
      return ar.contains(qStripped) || en.contains(lower);
    }).take(200).toList();
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search the Qur\'an…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
: _query.isEmpty
                        ? _Hints(
                            corpusReady: _corpus.isNotEmpty,
                            onSelect: (s) {
                              _controller.text = s;
                              _controller.selection =
                                  TextSelection.collapsed(offset: s.length);
                              _onChanged(s);
                            },
                          )
                        : _results.isEmpty
                        ? const _Empty()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final ayah = _results[i];
                              final surah = context
                                  .read<QuranProvider>()
                                  .surah(ayah.surahNumber);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(4, 0, 4, 4),
                                      child: Text(
                                        '${ayah.surahNumber}. ${surah?.transliteration ?? ''} · Ayah ${QurNum.arabicDigits(ayah.numberInSurah)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Ui.gold(context),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    AyahTile(
                                      ayah: ayah,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SurahReaderScreen(
                                              surahNumber: ayah.surahNumber,
                                              initialAyah: ayah.numberInSurah,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _Hints extends StatelessWidget {
  final bool corpusReady;
  final void Function(String) onSelect;
  const _Hints({required this.corpusReady, required this.onSelect});

  static const _suggestions = [
    'الرحمن',
    'نور',
    'mercy',
    'patience',
    'forgive',
    'jannah',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Try searching for…', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map(
                (s) => ActionChip(
                  label: Text(s),
                  onPressed: corpusReady ? () => onSelect(s) : null,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 56),
          SizedBox(height: 12),
          Text('No ayahs matched your search.'),
        ],
      ),
    );
  }
}