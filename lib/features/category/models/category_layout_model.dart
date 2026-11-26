import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/utils/json_parsers.dart';

/// customer/category_layout — the Categories screen built in the panel's
/// Category Builder. Sections are the same objects as home_layout, so they
/// render through the home SectionWidget as-is.
class CategoryLayoutModel {
  int? status;
  String? message;
  CategoryLayoutDataModel? data;

  CategoryLayoutModel({this.status, this.message, this.data});

  CategoryLayoutModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? CategoryLayoutDataModel.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class CategoryLayoutDataModel {
  CategoryLayoutInfo? layout;
  // Already excludes sections the server dropped for having no categories
  // in this zone/channel — can be lower than what the admin built.
  int? totalSections;
  int? offset;
  int? limit;
  int? zoneId;
  String? layoutMode;

  CategoryLayoutDataModel({
    this.layout,
    this.totalSections,
    this.offset,
    this.limit,
    this.zoneId,
    this.layoutMode,
  });

  CategoryLayoutDataModel.fromJson(Map<String, dynamic> json) {
    layout = json['layout'] is Map<String, dynamic>
        ? CategoryLayoutInfo.fromJson(json['layout'] as Map<String, dynamic>)
        : null;
    totalSections = parseInt(json['total_sections']);
    offset = parseInt(json['offset']);
    limit = parseInt(json['limit']);
    zoneId = parseInt(json['zone_id']);
    layoutMode = parseString(json['layout_mode']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (layout != null) {
      data['layout'] = layout!.toJson();
    }
    data['total_sections'] = totalSections;
    data['offset'] = offset;
    data['limit'] = limit;
    data['zone_id'] = zoneId;
    data['layout_mode'] = layoutMode;
    return data;
  }
}

class CategoryLayoutInfo {
  int? id;
  String? name;
  // true = the non-deletable fallback layout, served when nothing is
  // assigned to the zone/channel.
  bool? isDefault;
  CategoryLayoutHeader? header;
  List<Sections>? sections;

  CategoryLayoutInfo({
    this.id,
    this.name,
    this.isDefault,
    this.header,
    this.sections,
  });

  CategoryLayoutInfo.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    isDefault = parseBool(json['is_default']);
    header = json['header'] is Map<String, dynamic>
        ? CategoryLayoutHeader.fromJson(json['header'] as Map<String, dynamic>)
        : null;
    final rawSections = json['sections'];
    if (rawSections is List) {
      sections = rawSections
          .map((v) => Sections.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['is_default'] = isDefault;
    if (header != null) {
      data['header'] = header!.toJson();
    }
    if (sections != null) {
      data['sections'] = sections!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

/// Top bar of the Categories screen. No title — the app keeps its own.
/// Colours may be 6 or 8 hex digits (parse with parseHomeHexColor).
class CategoryLayoutHeader {
  // "color" or "image" — see BackgroundThemeType.
  String? backgroundTheme;
  String? backgroundColor;
  // Absolute URLs per device; tablet/web already fall back to app
  // server-side.
  Images? backgroundImageUrl;
  // Title and icons on the bar.
  String? textColor;

  CategoryLayoutHeader({
    this.backgroundTheme,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.textColor,
  });

  CategoryLayoutHeader.fromJson(Map<String, dynamic> json) {
    backgroundTheme = parseString(json['background_theme']);
    backgroundColor = parseString(json['background_color']);
    final rawImage = json['background_image_url'];
    backgroundImageUrl = rawImage is Map<String, dynamic>
        ? Images.fromJson(rawImage)
        : (parseString(rawImage)?.isNotEmpty == true
              ? Images(imageUrl: parseString(rawImage))
              : null);
    textColor = parseString(json['text_color']);
  }

  /// This device's image, or null when none is set.
  String? imageUrlFor({required bool isTablet}) {
    final images = backgroundImageUrl;
    if (images == null) return null;
    if (isTablet && images.tablet?.isNotEmpty == true) return images.tablet;
    return images.displayUrl;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['background_theme'] = backgroundTheme;
    data['background_color'] = backgroundColor;
    data['background_image_url'] = backgroundImageUrl?.toJson();
    data['text_color'] = textColor;
    return data;
  }
}
