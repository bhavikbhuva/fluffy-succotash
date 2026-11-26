import 'dart:io';

import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/favorite_button.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/services/deep_link_service.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductDetailCircleBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final bool isActive;

  const ProductDetailCircleBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return IconButton(
        onPressed: onTap,
        icon: AppSvgIcon(
          icon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
        ),
        padding: EdgeInsetsDirectional.all(ThemeConstants.paddingS),
        visualDensity: VisualDensity.compact,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        padding: EdgeInsetsDirectional.all(ThemeConstants.paddingS),
        decoration: AppDecorations.box(
          color: context.cs.surface.withValues(alpha: 0.9),
          shape: .circle,
          boxShadow: [
            BoxShadow(
              color: context.cs.scrim.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: AppSvgIcon(
          icon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
        ),
      ),
    );
  }
}

class ProductDetailShareBtn extends StatelessWidget {
  final ProductDetailDataModel product;
  final bool isActive;

  const ProductDetailShareBtn({
    super.key,
    required this.product,
    this.isActive = false,
  });

  Future<void> _onTap() async {
    final name = product.name ?? '';
    final slug = product.slug ?? '';
    final url = DeepLinkService.instance.buildShareUrl(slug, name);
    final file = await _downloadImage(product.imageUrl);
    await SharePlus.instance.share(
      ShareParams(
        text: '$name\n\n$url',
        files: file == null ? null : [XFile(file.path)],
      ),
    );
  }

  /// Returns null on any failure so share falls back to text-only.
  Future<File?> _downloadImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final res = await Dio().get<List<int>>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;
      final dir = await getTemporaryDirectory();
      final ext = imageUrl.split('?').first.split('.').last.toLowerCase();
      final safeExt = const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)
          ? ext
          : 'jpg';
      final file = File('${dir.path}/share_product_${product.id}.$safeExt');
      return await file.writeAsBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return IconButton(
        onPressed: _onTap,
        icon: AppSvgIcon(
          AssetsConstants.shareIcon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
          fit: BoxFit.scaleDown,
        ),
        padding: EdgeInsetsDirectional.zero,
        visualDensity: VisualDensity.compact,
      );
    }
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: AppDecorations.box(
          color: context.cs.surface.withValues(alpha: 0.9),
          shape: .circle,
          boxShadow: [
            BoxShadow(
              color: context.cs.scrim.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: AppSvgIcon(
          AssetsConstants.shareIcon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
          fit: BoxFit.scaleDown,
        ),
      ),
    );
  }
}

class ProductDetailFavBtn extends StatelessWidget {
  final ProductDetailDataModel product;
  final bool isActive;

  const ProductDetailFavBtn({
    super.key,
    required this.product,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteButton(
      productId: product.id?.toString(),
      initialIsFavorite: product.isFavorite ?? false,
      iconSize: 20,
      style: FavoriteButtonStyle.circle,
      isActive: isActive,
    );
  }
}
