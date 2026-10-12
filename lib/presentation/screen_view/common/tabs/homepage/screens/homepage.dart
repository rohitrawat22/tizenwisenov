import 'dart:developer';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/widgets/cached_image.dart';
import 'package:wiseplayertizen/core/widgets/custom_button.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';

import '../../../../../../core/const/api/onboardingApi.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  ValueNotifier<int> carouselDot = ValueNotifier<int>(0);
  @override
  Widget build(BuildContext context) {
    log("Homepage loading again");
    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            trandingSlider(),
            // _heroBanner(),
            _section("Recommended for you"),
            _section("Trending Now"),
            _section("Recently Watched", height: 140),
            _liveTvSection(),
          ],
        ),
      ),
    );
  }

  Widget trandingSlider() {
    // Compute available width live so the carousel never overflows after
    // rotation or on tablets — no stale global reads.
    final double sliderWidth = MediaQuery.sizeOf(context).width;
    // On wide screens (tablets / desktop), cap the carousel to 600px and
    // centre it so it doesn't stretch to a panoramic aspect ratio.
    final double clampedWidth = sliderWidth.clamp(0.0, 600.0);

    return Center(
      child: SizedBox(
        height: 245,
        width: clampedWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 225,
              width: clampedWidth,
              child: CarouselSlider(
                items: onboardingData
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadiusGeometry.circular(10),
                              child: CachedImage(
                                imageUrl: e['image'],
                                height: 230,
                                // double.infinity: CarouselSlider with
                                // viewportFraction:1 already constrains
                                // each item to the slider's own width.
                                width: double.infinity,
                              ),
                            ),
                            Positioned(
                              bottom: 15,
                              left: 20,
                              child: CustomButton(
                                borderRadius: 5,
                                height: 20,
                                width: 100,
                                icon: Icons.play_arrow,
                                child: const CText("Watch Now", fontSize: 12),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                options: CarouselOptions(
                  viewportFraction: 1,
                  autoPlay: true,
                  onPageChanged: (valueIndex, reason) {
                    carouselDot.value = valueIndex;
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length,
                (index) => ValueListenableBuilder(
                  valueListenable: carouselDot,
                  builder: (context, value, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: value == index ? 13 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: value == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  // ---------------- APP BAR ----------------
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      title: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          children: [
            TextSpan(
              text: "Wise ",
              style: TextStyle(color: Colors.white),
            ),
            TextSpan(
              text: "Player",
              style: TextStyle(color: AppColor.accentRed),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: const [
        Icon(Icons.notifications_none, color: Colors.white),
        SizedBox(width: 16),
      ],
    );
  }

  // ---------------- SECTION ----------------
  Widget _section(String title, {double height = 77}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const SizedBox(height: 10),
        SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 8,
            itemBuilder: (_, index) => const _PosterCard(),
          ),
        ),
      ],
    );
  }

  // ---------------- LIVE TV ----------------
  Widget _liveTvSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        children: [
          const _LiveChip(text: "CINE"),
          const _LiveChip(text: "SPORTS"),
          const _LiveChip(text: "NEWS"),
          const _LiveChip(text: "MUSIC"),
          const _LiveChip(text: "KIDS"),
        ],
      ),
    );
  }
}

// ─── Extracted StatelessWidgets ───────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CText(title, fontSize: 16, fontWeight: FontWeight.w600),
          InkWell(child: CText("See All", color: AppColor.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(left: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedImage(
          imageUrl: demoImage,
          height: double.infinity,
          width: 130,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  final String text;
  const _LiveChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.red, size: 8),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
