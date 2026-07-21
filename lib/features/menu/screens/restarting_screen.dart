import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:restart_app/restart_app.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/player_service.dart';

const _restartMessages = <String>[
  'Applying new audio engine…',
  'Reinitializing playback…',
  'Finishing up…',
];

/// Full-screen overlay shown while Flick restarts to apply a new audio engine.
///
/// Uses [Restart.restartApp] which schedules an AlarmManager relaunch and
/// then kills the process — the only way to truly restart on Android.
class RestartingScreen extends StatefulWidget {
  const RestartingScreen({super.key});

  @override
  State<RestartingScreen> createState() => _RestartingScreenState();
}

class _RestartingScreenState extends State<RestartingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  late final AnimationController _sweepController;
  late final Timer _exitTimer;
  late final Timer _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    )..forward();
    _fade = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _sweepController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat();
    _messageTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _restartMessages.length;
      });
    });
    _exitTimer = Timer(const Duration(milliseconds: 2700), () async {
      // Silence playback now, then hard-kill the process. The default
      // platformDefault mode only calls finishAffinity(), which leaves the
      // foreground audio service + native engine alive (song keeps playing and
      // a second instance opens). forceKill runs Runtime.exit(0) — a real
      // process kill, so the relaunch starts a single fresh instance.
      unawaited(PlayerService().pause());
      await Restart.restartApp(forceKill: true);
    });
  }

  @override
  void dispose() {
    _messageTimer.cancel();
    _exitTimer.cancel();
    _fadeController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _sweepController,
                    builder: (context, child) {
                      return ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          final t = _sweepController.value;
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [
                              AppColors.accentDim,
                              AppColors.accentLight,
                              Colors.white,
                              AppColors.accentLight,
                              AppColors.accentDim,
                            ],
                            stops: [
                              0.0,
                              (t - 0.15).clamp(0.0, 1.0),
                              t,
                              (t + 0.15).clamp(0.0, 1.0),
                              1.0,
                            ],
                          ).createShader(bounds);
                        },
                        child: child!,
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/flicklogo_svg.svg',
                      width: 130,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  Text(
                    'Restarting Flick',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXs),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _restartMessages[_messageIndex],
                      key: ValueKey(_messageIndex),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
