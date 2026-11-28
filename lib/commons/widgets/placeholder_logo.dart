// PestRaksh: the logo shown while an image loads or when it can't be shown,
// in place of the vendor's green SnapBuy placeholder. The website shows the
// PestRaksh logo too (Admin → Web Settings → placeholder image).
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';

class PlaceholderLogo extends StatelessWidget {
  const PlaceholderLogo({super.key});

  /// One small decode, shared by every placeholder on screen.
  static const int _decodeWidth = 300;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Image.asset(
        AssetsConstants.pestrakshLogo,
        fit: BoxFit.contain,
        cacheWidth: _decodeWidth,
        excludeFromSemantics: true,
      ),
    );
  }
}
