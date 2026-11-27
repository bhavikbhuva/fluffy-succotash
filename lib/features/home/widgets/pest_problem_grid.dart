import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';

// PestRaksh: the home page's "What pest problem are you facing?" section
// (block type pest_problem_grid). The website draws the same block with
// PestProblemGrid: a centred title and subtitle, then a card holding a grid
// of pest tiles, each an image with the name under it. Service tiles come
// first and open the service (its prices and packages); category tiles
// (e.g. Commercial) follow and open the category. The title and subtitle
// come from the server, so there are no app text keys here.
class PestProblemGrid extends StatelessWidget {
  final List<ProductDataModel> products;
  final List<Categories> categories;
  final String? sectionTitle;
  final String? sectionSubtitle;
  final String? backgroundColor;
  final String? textColor;
  final String? itemTextColor;
  final ValueChanged<ProductDataModel>? onProductTap;
  final ValueChanged<Categories>? onCategoryTap;

  const PestProblemGrid({
    super.key,
    this.products = const [],
    this.categories = const [],
    this.sectionTitle,
    this.sectionSubtitle,
    this.backgroundColor,
    this.textColor,
    this.itemTextColor,
    this.onProductTap,
    this.onCategoryTap,
  });

  // PestRaksh: 4 tiles per row on a phone, 3 on narrow phones so the names
  // stay readable, and 6 on a tablet (the website's widest row).
  int _columns(BuildContext context) {
    if (MediaQuery.sizeOf(context).shortestSide >= 600) return 6;
    if (context.screenWidth < 360) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    // PestRaksh: the app opens services and categories by id, so a tile
    // without one would do nothing when tapped; leave it out.
    final tiles = <_PestTile>[
      for (final p in products)
        if (p.id != null)
          _PestTile(
            name: p.name ?? '',
            imageUrl: p.images?.coverUrl ?? '',
            onTap: onProductTap == null ? null : () => onProductTap!(p),
          ),
      for (final c in categories)
        if (c.id != null)
          _PestTile(
            name: c.name ?? '',
            imageUrl: c.imageUrl ?? '',
            onTap: onCategoryTap == null ? null : () => onCategoryTap!(c),
          ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    // PestRaksh: the block's own colours when the admin sets them,
    // otherwise the theme's.
    final bgColor = backgroundColor.toColor();
    final titleColor = textColor.toColor() ?? context.cs.onSurface;
    final subtitleColor = textColor.toColor() ?? context.cs.onSurfaceVariant;
    final nameColor =
        itemTextColor.toColor() ?? textColor.toColor() ?? context.cs.onSurface;

    final nameStyle = context.tt.labelLarge?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: nameColor,
    );
    // Two lines of the real font at the user's text size, so the cell is
    // always tall enough for a 2-line name and never overflows.
    final nameHeight =
        (TextPainter(
          text: TextSpan(text: 'Ag\nAg', style: nameStyle),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout()).height +
        2;

    final title = sectionTitle;
    final subtitle = sectionSubtitle;
    final columns = _columns(context);
    const gap = ThemeConstants.spaceS;

    Widget content = Padding(
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (title?.isNotEmpty == true)
            AppText(
              title!,
              textAlign: .center,
              style: context.tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          if (subtitle?.isNotEmpty == true) ...[
            const SizedBox(height: ThemeConstants.spaceXS),
            AppText(
              subtitle!,
              textAlign: .center,
              style: context.tt.bodySmall?.copyWith(color: subtitleColor),
            ),
          ],
          if (title?.isNotEmpty == true || subtitle?.isNotEmpty == true)
            const SizedBox(height: ThemeConstants.spaceM),
          Container(
            padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
            decoration: AppDecorations.outlinedCard(
              color: context.cs.surface,
              borderColor: context.cs.outlineVariant,
              borderRadius: 16,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsetsDirectional.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    // Square image + gap + two lines of name.
                    mainAxisExtent:
                        cellWidth + ThemeConstants.spaceXS + nameHeight,
                  ),
                  itemCount: tiles.length,
                  itemBuilder: (context, i) => _PestTileView(
                    tile: tiles[i],
                    imageSize: cellWidth,
                    nameStyle: nameStyle,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (bgColor != null) {
      content = ColoredBox(color: bgColor, child: content);
    }
    return content;
  }
}

class _PestTile {
  final String name;
  final String imageUrl;
  final VoidCallback? onTap;

  const _PestTile({required this.name, required this.imageUrl, this.onTap});
}

class _PestTileView extends StatelessWidget {
  final _PestTile tile;
  final double imageSize;
  final TextStyle? nameStyle;

  const _PestTileView({
    required this.tile,
    required this.imageSize,
    this.nameStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: tile.onTap != null,
      label: tile.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tile.onTap,
        child: Column(
          mainAxisSize: .min,
          spacing: ThemeConstants.spaceXS,
          children: [
            // PestRaksh: a rounded square on a soft fill, the pest picture
            // fitted inside it (contain) as on the website; the app's
            // network image shows its placeholder while loading or when
            // there is no picture.
            Container(
              width: imageSize,
              height: imageSize,
              padding: const EdgeInsetsDirectional.all(
                ThemeConstants.paddingXS,
              ),
              decoration: AppDecorations.box(
                color: context.cs.secondaryFixed,
                borderRadius: AppRadius.r12,
              ),
              child: AppNetworkImage(
                url: tile.imageUrl,
                fit: BoxFit.contain,
                borderRadius: AppRadius.r10,
              ),
            ),
            AppText(
              tile.name,
              style: nameStyle,
              textAlign: .center,
              maxLines: 2,
              overflow: .ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
