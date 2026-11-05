/// Background treatments for the immersive full player.
enum ImmersiveBackgroundStyle { colorGradient, blurGradient }

extension ImmersiveBackgroundStyleX on ImmersiveBackgroundStyle {
  String get storageValue {
    switch (this) {
      case ImmersiveBackgroundStyle.colorGradient:
        return 'color_gradient';
      case ImmersiveBackgroundStyle.blurGradient:
        return 'blur_gradient';
    }
  }

  static ImmersiveBackgroundStyle fromStorageValue(String? value) {
    switch (value) {
      case 'blur_gradient':
        return ImmersiveBackgroundStyle.blurGradient;
      case 'color_gradient':
      default:
        return ImmersiveBackgroundStyle.colorGradient;
    }
  }
}
