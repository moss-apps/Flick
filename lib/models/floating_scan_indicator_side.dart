enum FloatingScanIndicatorSide { left, right }

extension FloatingScanIndicatorSideX on FloatingScanIndicatorSide {
  String get storageValue {
    switch (this) {
      case FloatingScanIndicatorSide.left:
        return 'left';
      case FloatingScanIndicatorSide.right:
        return 'right';
    }
  }

  static FloatingScanIndicatorSide fromStorageValue(String? value) {
    switch (value) {
      case 'left':
        return FloatingScanIndicatorSide.left;
      case 'right':
      default:
        return FloatingScanIndicatorSide.right;
    }
  }
}
