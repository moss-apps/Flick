/// Background treatment for portrait orbit song cards.
enum OrbitCardBackgroundStyle {
  blurGradient,
  blackGradient,
  albumColorGradient,
}

extension OrbitCardBackgroundStyleX on OrbitCardBackgroundStyle {
  String get storageValue {
    switch (this) {
      case OrbitCardBackgroundStyle.blurGradient:
        return 'blur_gradient';
      case OrbitCardBackgroundStyle.blackGradient:
        return 'black_gradient';
      case OrbitCardBackgroundStyle.albumColorGradient:
        return 'album_color_gradient';
    }
  }

  static OrbitCardBackgroundStyle fromStorageValue(String? value) {
    switch (value) {
      case 'black_gradient':
        return OrbitCardBackgroundStyle.blackGradient;
      case 'album_color_gradient':
        return OrbitCardBackgroundStyle.albumColorGradient;
      case 'blur_gradient':
        return OrbitCardBackgroundStyle.blurGradient;
      default:
        return OrbitCardBackgroundStyle.blackGradient;
    }
  }
}
