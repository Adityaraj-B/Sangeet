class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final String bio;
  final String type; // e.g., 'Singer', 'Composer'

  Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.bio = '',
    this.type = 'Artist',
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    String image = '';
    if (json['image'] is List && (json['image'] as List).isNotEmpty) {
      final img = (json['image'] as List).last;
      image = img['link']?.toString() ?? img['url']?.toString() ?? '';
    }

    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Artist',
      imageUrl: image,
      bio: json['bio'] is List
          ? (json['bio'] as List).isEmpty ? '' : json['bio'][0]['text'] ?? ''
          : json['bio']?.toString() ?? '',
      type: json['role']?.toString() ?? 'Artist',
    );
  }
}