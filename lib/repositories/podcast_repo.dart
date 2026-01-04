import '../models/podcasts.dart';

class PodcastRepository {
  static List<Podcast> getFeatured() {
    return [
      Podcast(
        id: 'f1',
        title: 'Mysteries of The Cosmos',
        author: 'Dr. Orion Vale',
        imageUrl: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
        genre: 'Sci-Fi',
      ),
    ];
  }

  static List<String> getGenres() {
    return [
      'Technology',
      'Motivation',
      'Business',
      'Storytelling',
      'Health',
      'Comedy',
      'Spirituality',
      'Music Talks',
    ];
  }

  static Map<String, List<Podcast>> getByGenre() {
    return {
      "Technology": [
        Podcast(
          id: 't1',
          title: 'Future Byte',
          author: 'ByteCast',
          imageUrl: 'https://images.unsplash.com/photo-1518779578993-ec3579fee39f',
          genre: 'Technology',
        ),Podcast(
          id: 't2',
          title: 'AI Loop',
          author: 'Neural Net',
          imageUrl: 'https://images.unsplash.com/photo-1555949963-aa79dcee981d',
          genre: 'Technology',
        ),
        Podcast(
          id: 't3',
          title: 'DevOps Daily',
          author: 'Ops Crew',
          imageUrl: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c',
          genre: 'Technology',
        ),
        Podcast(
          id: 't4',
          title: 'Quantum Circuit',
          author: 'QBits Lab',
          imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e',
          genre: 'Technology',
        ),
      ],
      "Motivation": [
        Podcast(
          id: 'm1',
          title: 'Rise & Grind',
          author: 'Evelyn Cole',
          imageUrl: 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2',
          genre: 'Motivation',
        ),
        Podcast(
          id: 'm2',
          title: 'Morning Mantras',
          author: 'Liam Hart',
          imageUrl: 'https://images.unsplash.com/photo-1500336624523-d727130c3328',
          genre: 'Motivation',
        ),
        Podcast(
          id: 'm3',
          title: 'Never Settle',
          author: 'Aisha Khan',
          imageUrl: 'https://images.unsplash.com/photo-1496307042754-b4aa456c4a2d',
          genre: 'Motivation',
        ),
        Podcast(
          id: 'm4',
          title: 'Small Wins',
          author: 'Coach Rey',
          imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
          genre: 'Motivation',
        ),
      ],
      "Storytelling": [
        Podcast(
          id: 's1',
          title: 'Midnight Tales',
          author: 'Raven Studio',
          imageUrl: 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429',
          genre: 'Storytelling',
        ),
      ],
    };
  }

  static List<Podcast> getContinueListening() {
    return [
      Podcast(
        id: 'c1',
        title: 'The Ancient Vault',
        author: 'History Echo',
        imageUrl: 'https://images.unsplash.com/photo-1522199710521-72d69614c702',
        progress: 0.46,
        genre: 'History',
      ),
    ];
  }
}
