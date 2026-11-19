import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';

import '../../../../core/utils/app_logo.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text.dart';
import '../../../../core/widgets/custom_textFormFiled.dart';

class UploadPlaylist extends StatefulWidget {
  static const routeName = AppRoutes.uploadPlaylist;
  const UploadPlaylist({super.key});

  @override
  State<UploadPlaylist> createState() => _UploadPlaylistState();
}

class _UploadPlaylistState extends State<UploadPlaylist>
    with SingleTickerProviderStateMixin {
  TextEditingController macCtrl = TextEditingController();
  TextEditingController playlistNameCtrl = TextEditingController();
  TextEditingController playlistUrlCtrl = TextEditingController();
  ApiService apiService = ApiService();

  bool _isUploading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    macCtrl.dispose();
    playlistNameCtrl.dispose();
    playlistUrlCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: null,
        title: appLogo(),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColor.accentCyan.withOpacity(0.8),
            size: 20,
          ),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 2.0,
            colors: [
              AppColor.accentBlue.withOpacity(0.06),
              AppColor.background,
              const Color(0xFF05070A),
            ],
          ),
        ),
        child: Builder(
          builder: (context) {
            // Compute device type live — never stale after rotation.
            final bool isPhone = isPhoneWidth(context);
            if (isPhone) {
              return _buildFormContent();
            }
            // On wide screens, centre the form in a capped-width box.
            final double formWidth = (MediaQuery.sizeOf(context).width * 0.45)
                .clamp(280.0, 520.0);
            return Center(
              child: SizedBox(width: formWidth, child: _buildFormContent()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // --- Header Section ---
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColor.accentCyan.withOpacity(
                        0.08 + (_pulseController.value * 0.06),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.playlist_add_rounded,
                  size: 48,
                  color: AppColor.accentCyan.withOpacity(0.8),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            "Add New Playlist",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Enter your M3U playlist details below",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 36),

          // --- Glass Form Card ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColor.surfaceDark.withOpacity(0.7),
                  AppColor.surfaceDark.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColor.accentCyan.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColor.accentBlue.withOpacity(0.06),
                  blurRadius: 30,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MAC Address field (disabled)
                _buildFieldLabel("Device MAC", Icons.router_outlined),
                const SizedBox(height: 8),
                CustomTextFormFiled(
                  controller: macCtrl,
                  hintText: "Device Mac $macAddress",
                  isEnabled: false,
                ),

                const SizedBox(height: 20),

                // Playlist Name field
                _buildFieldLabel("Playlist Name", Icons.label_outline_rounded),
                const SizedBox(height: 8),
                CustomTextFormFiled(
                  controller: playlistNameCtrl,
                  hintText: "Enter playlist name",
                ),

                const SizedBox(height: 20),

                // Playlist URL field
                _buildFieldLabel("Playlist URL", Icons.link_rounded),
                const SizedBox(height: 8),
                CustomTextFormFiled(
                  controller: playlistUrlCtrl,
                  hintText: "http://example.com/playlist.m3u",
                ),

                const SizedBox(height: 32),

                // Upload Button
                AbsorbPointer(
                  absorbing: _isUploading,
                  child: Opacity(
                    opacity: _isUploading ? 0.7 : 1.0,
                    child: SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        gradient: AppColor.primaryGradient,
                        onPressed: () {
                          _handleUpload();
                        },
                        child: _isUploading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const CText("Uploading..."),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.cloud_upload_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const CText("Upload Playlist"),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Info Tip ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColor.accentBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColor.accentBlue.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColor.accentCyan.withOpacity(0.5),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Supported formats: M3U, M3U8. Refresh the main page after uploading.",
                    style: TextStyle(
                      color: AppColor.moreLightGrey.withOpacity(0.5),
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColor.accentCyan.withOpacity(0.5), size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColor.moreLightGrey.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpload() async {
    if (playlistNameCtrl.text.isNotEmpty && playlistUrlCtrl.text.isNotEmpty) {
      setState(() => _isUploading = true);
      final res = await apiService.hitPostApi(
        reqData: {
          "name": "mac1",
          "m3uUrl": "https://iptv-org.github.io/iptv/categories/news.m3u",
        },
        endpoint: "/api/playlist/m3u",
      );
      if (!mounted) return;
      setState(() => _isUploading = false);

      if (res.isSuccess) {
        snackBar(
          context,
          "Playlist upload Successfully \nRefresh the page",
          Colors.green,
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) GoRouter.of(context).pop();
        });
      } else {
        snackBar(
          context,
          res.error ?? "Please Try after some time",
          Colors.red,
        );
      }
    } else {
      snackBar(context, "All Fields are required", Colors.red);
    }
  }
}
