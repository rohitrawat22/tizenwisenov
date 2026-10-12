import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/localization/generated/l10n.dart';
import 'package:wiseplayertizen/core/routes/router.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/bloc_observer.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/connectivity_bloc/connectivity_bloc.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/repo/api_repo.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/data/local_storage/hive_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ✅ Catch Flutter framework errors (including focus-node lifecycle errors)
      // instead of letting them crash the entire app.
      FlutterError.onError = (FlutterErrorDetails details) {
        log(
          'FlutterError caught: ${details.exceptionAsString()}',
          stackTrace: details.stack,
        );
        FlutterError.presentError(details);
      };

      // ✅ Catch platform-channel / native errors not caught by FlutterError.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        log('PlatformDispatcher error caught: $error', stackTrace: stack);
        return true; // handled — do not crash the app
      };

      // ✅ Set bloc observer early (not inside build)
      Bloc.observer = AppBlocObserver();

      // ✅ Only init critical services before runApp (Hive needed on first frame)
      await HiveService.init();

      runApp(const MyApp());
    },
    (Object error, StackTrace stack) {
      // Catches any uncaught async error that escaped the zone — last resort.
      log('Uncaught zone error: $error', stackTrace: stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ApiService apiService = ApiService();
    return MultiBlocProvider(
      providers: [
        BlocProvider<WiseBloc>(
          create: (context) =>
              WiseBloc(ApiRepo(apiService: apiService))
                ..add(ChangeLanguageEvent(localWord: "")),
        ),
        // ✅ ConnectivityBloc is lazy: it only starts when first accessed
        BlocProvider<ConnectivityBloc>(
          lazy: true,
          create: (context) =>
              ConnectivityBloc()..add(CheckInterNetConnectionEvent()),
        ),
      ],
      child: BlocBuilder<WiseBloc, WiseState>(
        buildWhen: (previous, current) =>
            previous.localeWord != current.localeWord,
        builder: (context, state) {
          final Locale locale = Locale(
            state.localeWord.isEmpty ? "en" : state.localeWord,
          );
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            locale: locale,
            supportedLocales: S.delegate.supportedLocales,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            title: 'Wise Player',
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColor.background,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColor.background,
              ),
              useMaterial3: true,
            ),
          );
        },
      ),
    );
  }
}
