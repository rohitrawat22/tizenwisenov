// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Exit`
  String get exit {
    return Intl.message('Exit', name: 'exit', desc: '', args: []);
  }

  /// `Okk`
  String get okk {
    return Intl.message('Okk', name: 'okk', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Are you sure you want to exit?`
  String get exitConfirmMessage {
    return Intl.message(
      'Are you sure you want to exit?',
      name: 'exitConfirmMessage',
      desc: '',
      args: [],
    );
  }

  /// `Your MAC address is not associated with any playlist`
  String get macNotAssociated {
    return Intl.message(
      'Your MAC address is not associated with any playlist',
      name: 'macNotAssociated',
      desc: '',
      args: [],
    );
  }

  /// `Upload Playlist`
  String get uploadPlaylist {
    return Intl.message(
      'Upload Playlist',
      name: 'uploadPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Refresh`
  String get refresh {
    return Intl.message('Refresh', name: 'refresh', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Power`
  String get power {
    return Intl.message('Power', name: 'power', desc: '', args: []);
  }

  /// `Select Playlist`
  String get selectPlaylist {
    return Intl.message(
      'Select Playlist',
      name: 'selectPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Series`
  String get series {
    return Intl.message('Series', name: 'series', desc: '', args: []);
  }

  /// `Verify`
  String get verify {
    return Intl.message('Verify', name: 'verify', desc: '', args: []);
  }

  /// `Select the channel to watch video`
  String get selectChannelToWatch {
    return Intl.message(
      'Select the channel to watch video',
      name: 'selectChannelToWatch',
      desc: '',
      args: [],
    );
  }

  /// `Verified`
  String get verified {
    return Intl.message('Verified', name: 'verified', desc: '', args: []);
  }

  /// `Add New Playlist`
  String get addNewPlaylist {
    return Intl.message(
      'Add New Playlist',
      name: 'addNewPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Live TV`
  String get liveTv {
    return Intl.message('Live TV', name: 'liveTv', desc: '', args: []);
  }

  /// `This player is not active yet. Activate your subscription to access content.`
  String get playerNotActive {
    return Intl.message(
      'This player is not active yet. Activate your subscription to access content.',
      name: 'playerNotActive',
      desc: '',
      args: [],
    );
  }

  /// `Activate Now`
  String get activateNow {
    return Intl.message(
      'Activate Now',
      name: 'activateNow',
      desc: '',
      args: [],
    );
  }

  /// `Movies`
  String get movies {
    return Intl.message('Movies', name: 'movies', desc: '', args: []);
  }

  /// `Your MAC`
  String get macLabel {
    return Intl.message('Your MAC', name: 'macLabel', desc: '', args: []);
  }

  /// `WisePlayer.app is a TV player only and does not include any channels`
  String get tvOnlyWarning {
    return Intl.message(
      'WisePlayer.app is a TV player only and does not include any channels',
      name: 'tvOnlyWarning',
      desc: '',
      args: [],
    );
  }

  /// `Favourite`
  String get favourite {
    return Intl.message('Favourite', name: 'favourite', desc: '', args: []);
  }

  /// `Go Premium`
  String get goPremium {
    return Intl.message('Go Premium', name: 'goPremium', desc: '', args: []);
  }

  /// `Unlock Premium Access`
  String get unlockPremiumAccess {
    return Intl.message(
      'Unlock Premium Access',
      name: 'unlockPremiumAccess',
      desc: '',
      args: [],
    );
  }

  /// `Stream unlimited content, enjoy HD video playback, and activate all compatible Android/iOS TV features instantly.`
  String get premiumDesc {
    return Intl.message(
      'Stream unlimited content, enjoy HD video playback, and activate all compatible Android/iOS TV features instantly.',
      name: 'premiumDesc',
      desc: '',
      args: [],
    );
  }

  /// `Safe and secure transaction processing via verified PayPal invoicing channels.`
  String get securePaymentDesc {
    return Intl.message(
      'Safe and secure transaction processing via verified PayPal invoicing channels.',
      name: 'securePaymentDesc',
      desc: '',
      args: [],
    );
  }

  /// `Premium Plan`
  String get premiumPlan {
    return Intl.message(
      'Premium Plan',
      name: 'premiumPlan',
      desc: '',
      args: [],
    );
  }

  /// `days validity`
  String get daysValidity {
    return Intl.message(
      'days validity',
      name: 'daysValidity',
      desc: '',
      args: [],
    );
  }

  /// `Continue to Checkout`
  String get continueToCheckout {
    return Intl.message(
      'Continue to Checkout',
      name: 'continueToCheckout',
      desc: '',
      args: [],
    );
  }

  /// `ACTIVE`
  String get activeStatus {
    return Intl.message('ACTIVE', name: 'activeStatus', desc: '', args: []);
  }

  /// `INACTIVE`
  String get inactiveStatus {
    return Intl.message('INACTIVE', name: 'inactiveStatus', desc: '', args: []);
  }

  /// `Device is streaming`
  String get deviceIsStreaming {
    return Intl.message(
      'Device is streaming',
      name: 'deviceIsStreaming',
      desc: '',
      args: [],
    );
  }

  /// `Activate your device`
  String get activateYourDevice {
    return Intl.message(
      'Activate your device',
      name: 'activateYourDevice',
      desc: '',
      args: [],
    );
  }

  /// `SCAN OR TAP QR TO ADD PLAYLIST`
  String get scanOrTapQr {
    return Intl.message(
      'SCAN OR TAP QR TO ADD PLAYLIST',
      name: 'scanOrTapQr',
      desc: '',
      args: [],
    );
  }

  /// `DEVICE MAC ADDRESS`
  String get deviceMacAddress {
    return Intl.message(
      'DEVICE MAC ADDRESS',
      name: 'deviceMacAddress',
      desc: '',
      args: [],
    );
  }

  /// `Scan or Tap QR to Add Playlist`
  String get scanOrTapHint {
    return Intl.message(
      'Scan or Tap QR to Add Playlist',
      name: 'scanOrTapHint',
      desc: '',
      args: [],
    );
  }

  /// `ANDROID · iOS TV  —  Optimized for TV Players Only`
  String get optimizedTvOnly {
    return Intl.message(
      'ANDROID · iOS TV  —  Optimized for TV Players Only',
      name: 'optimizedTvOnly',
      desc: '',
      args: [],
    );
  }

  /// `Choose playlist`
  String get choosePlaylistWarning {
    return Intl.message(
      'Choose playlist',
      name: 'choosePlaylistWarning',
      desc: '',
      args: [],
    );
  }

  /// `Firstly Verify Your PlayList`
  String get verifyPlaylistFirst {
    return Intl.message(
      'Firstly Verify Your PlayList',
      name: 'verifyPlaylistFirst',
      desc: '',
      args: [],
    );
  }

  /// `Please select a valid playlist to verify.`
  String get selectValidPlaylistToVerify {
    return Intl.message(
      'Please select a valid playlist to verify.',
      name: 'selectValidPlaylistToVerify',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong`
  String get somethingWentWrong {
    return Intl.message(
      'Something went wrong',
      name: 'somethingWentWrong',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'De'),
      Locale.fromSubtags(languageCode: 'Es'),
      Locale.fromSubtags(languageCode: 'ar'),
      Locale.fromSubtags(languageCode: 'fr'),
      Locale.fromSubtags(languageCode: 'hi'),
      Locale.fromSubtags(languageCode: 'it'),
      Locale.fromSubtags(languageCode: 'nl'),
      Locale.fromSubtags(languageCode: 'pt'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
