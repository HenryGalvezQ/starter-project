import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ArticleTileShimmer extends StatelessWidget {
  const ArticleTileShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 14, end: 14, bottom: 7, top: 7),
      height: MediaQuery.of(context).size.width / 2.1,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Row(
          children: [
            // 1. IMAGEN FAKE
            Container(
              width: MediaQuery.of(context).size.width / 3,
              height: double.maxFinite,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
              ),
            ),
            const SizedBox(width: 14),
            
            // 2. TEXTOS FAKE
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Título línea 1
                  Container(width: double.infinity, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  // Título línea 2
                  Container(width: 150, height: 16, color: Colors.white),
                  const SizedBox(height: 16),
                  // Descripción
                  Container(width: double.infinity, height: 10, color: Colors.white),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}