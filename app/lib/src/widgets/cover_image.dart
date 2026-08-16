import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CoverImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  const CoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: AppGradient.hero(),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.movie_filter_outlined,
        color: Colors.white.withValues(alpha: 0.7),
        size: 40,
      ),
    );

    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
        errorBuilder: (context, error, stack) => placeholder,
      ),
    );
  }
}
