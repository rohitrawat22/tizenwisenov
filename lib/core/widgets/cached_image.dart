import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// PERF: shimmer import removed — Shimmer drove a shared animation tick
// on every frame for every visible placeholder. Static container instead.

class CachedImage extends StatelessWidget {
  final imageUrl;
  final double height;
  final double width;
  final Widget errorWidgets;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  
  const CachedImage({
    super.key,
    required this.imageUrl,
    required this.height,
    required this.width,
    this.errorWidgets = const Icon(Icons.error),
    this.fit = BoxFit.cover,
    this.memCacheWidth = 300,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    // If URL is empty or null, show a premium default placeholder immediately
    if (imageUrl == null || imageUrl.toString().trim().isEmpty) {
      return _buildPremiumPlaceholder();
    }

    return CachedNetworkImage(
      httpHeaders: const {"User-Agent": "Mozilla/5.0"},
      height: height,
      width: width,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      // PERF: replaced Shimmer with a static container. Shimmer's shared
      // AnimationController triggered GPU repaints on every frame for every
      // visible placeholder card — very costly on low-end TV GPUs.
      placeholder: (context, url) => Container(
        height: height,
        width: width,
        color: const Color(0xFF1A1A2E),
      ),
      errorWidget: (context, url, error) {
        log("Error loading image: $error");
        return _buildPremiumPlaceholder();
      },
      imageUrl: imageUrl,
    );
  }

  Widget _buildPremiumPlaceholder() {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: Colors.white.withOpacity(0.3),
          size: (height > 0 && height < 50) ? height * 0.5 : 30,
        ),
      ),
    );
  }
}
