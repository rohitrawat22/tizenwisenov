import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/colors/tv_theme.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/core/widgets/custom_button.dart';
import 'package:wiseplayertizen/core/widgets/custom_textFormFiled.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';

class TVUploadPlaylistScreen extends StatefulWidget {
  const TVUploadPlaylistScreen({super.key});

  @override
  State<TVUploadPlaylistScreen> createState() => _TVUploadPlaylistScreenState();
}

class _TVUploadPlaylistScreenState extends State<TVUploadPlaylistScreen> {
  final TextEditingController macCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController urlCtrl = TextEditingController();
  final ApiService apiService = ApiService();

  final FocusNode _backNode = FocusNode(debugLabel: 'tv_upload_back');
  final FocusNode _nameNode = FocusNode(debugLabel: 'tv_upload_name');
  final FocusNode _urlNode = FocusNode(debugLabel: 'tv_upload_url');
  final FocusNode _submitNode = FocusNode(debugLabel: 'tv_upload_submit');

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    macCtrl.text = macAddress;

    // Wire D-pad navigation flow using the shared helper.
    wireDpadNode(
      _backNode,
      down: _nameNode,
      lockUp: true,
      lockLeft: true,
      lockRight: true,
      onSelect: () => GoRouter.of(context).pop(),
    );

    wireDpadNode(
      _nameNode,
      up: _backNode,
      down: _urlNode,
      lockLeft: true,
      lockRight: true,
    );

    wireDpadNode(
      _urlNode,
      up: _nameNode,
      down: _submitNode,
      lockLeft: true,
      lockRight: true,
    );

    wireDpadNode(
      _submitNode,
      up: _urlNode,
      lockDown: true,
      lockLeft: true,
      lockRight: true,
      onSelect: _handleUpload,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameNode.requestFocus();
    });
  }

  @override
  void dispose() {
    macCtrl.dispose();
    nameCtrl.dispose();
    urlCtrl.dispose();
    _backNode.dispose();
    _nameNode.dispose();
    _urlNode.dispose();
    _submitNode.dispose();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    if (nameCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
      setState(() => _isUploading = true);
      final res = await apiService.hitPostApi(
        reqData: {
          "name": nameCtrl.text.toString(),
          "m3uUrl": "http://line.vpnworld.pro/get.php?username=77D317&password=41CC5066&type=m3u_plus&output=mpegts",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TVTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Back Button
              Row(
                children: [
                  Focus(
                    focusNode: _backNode,
                    child: Builder(
                      builder: (ctx) {
                        final hasFocus = Focus.of(ctx).hasFocus;
                        return Container(
                          decoration: TVTheme.focusDecoration(
                            focused: hasFocus,
                            radius: 28,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => GoRouter.of(context).pop(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text("Add New Playlist", style: TVTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 30),

              // Form Fields Center Card
              Expanded(
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: TVTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: TVTheme.border),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Device MAC Address",
                            style: TVTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          CustomTextFormFiled(
                            controller: macCtrl,
                            hintText: "Device Mac",
                            isEnabled: false,
                          ),
                          const SizedBox(height: 20),

                          const Text("Playlist Name", style: TVTheme.bodyLarge),
                          const SizedBox(height: 8),
                          CustomTextFormFiled(
                            focusNode: _nameNode,
                            controller: nameCtrl,
                            hintText: "Enter playlist name",
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            "Playlist M3U/M3U8 URL",
                            style: TVTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          CustomTextFormFiled(
                            focusNode: _urlNode,
                            controller: urlCtrl,
                            hintText: "http://example.com/playlist.m3u",
                          ),
                          const SizedBox(height: 30),

                          Focus(
                            focusNode: _submitNode,
                            child: Builder(
                              builder: (ctx) {
                                final hasFocus = Focus.of(ctx).hasFocus;
                                return CustomButton(
                                  onPressed: _handleUpload,
                                  backgroundColor: hasFocus
                                      ? Colors.white
                                      : TVTheme.accentRed,
                                  child: _isUploading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: hasFocus
                                                ? Colors.black
                                                : Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          "Upload Playlist",
                                          style: TVTheme.bodyLarge.copyWith(
                                            color: hasFocus
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
