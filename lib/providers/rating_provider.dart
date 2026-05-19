import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/services/rating_service.dart';

final ratingServiceProvider = Provider<RatingService>((ref) {
  return RatingService();
});

class RatingNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    Future.microtask(_loadRatings);
    return {};
  }

  Future<void> _loadRatings() async {
    final service = ref.read(ratingServiceProvider);
    final ratings = await service.getAllRatings();
    if (ref.mounted) {
      state = ratings;
    }
  }

  Future<void> setRating(String songId, int rating) async {
    state = Map.from(state)..[songId] = rating.clamp(1, 5);
    final service = ref.read(ratingServiceProvider);
    await service.setRating(songId, rating);
  }

  Future<void> removeRating(String songId) async {
    state = Map.from(state)..remove(songId);
    final service = ref.read(ratingServiceProvider);
    await service.setRating(songId, 0);
  }

  int getRating(String songId) => state[songId] ?? 0;
}

final ratingProvider =
    NotifierProvider<RatingNotifier, Map<String, int>>(
      RatingNotifier.new,
    );