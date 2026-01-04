class Podcast {
  final String id;
  final String title;
  final String author;
  final String imageUrl;
  final String genre;
  final double progress; // 0.0 – 1.0

  const Podcast({
    required this.id,
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.genre,
    this.progress = 0.0,
  });
}
