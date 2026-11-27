import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/address/widgets/location_permission_dialog.dart';
import 'package:customer/features/location/cubit/user_location_cubit.dart';
import 'package:customer/features/location/screens/location_search_screen.dart';
import 'package:customer/features/location/utils/single_zone_location.dart';
import 'package:customer/features/location/widgets/location_required_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Full-screen "set your location" gate shown before entering [RouteNames.main]
/// whenever [SettingsHiveBox.hasLocation] is false (post-onboarding, post-login, etc).
/// Replaces the current route once location is set.
class LocationRequiredScreen extends StatefulWidget {
  const LocationRequiredScreen({super.key});

  @override
  State<LocationRequiredScreen> createState() => _LocationRequiredScreenState();
}

class _LocationRequiredScreenState extends State<LocationRequiredScreen> {
  // PestRaksh: true while checking for a single service zone. With exactly
  // one there is nothing to ask, so it is stored and we go straight home;
  // otherwise (or if the check fails) the screen asks as before.
  bool _checkingSingleZone = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySingleZone());
  }

  Future<void> _trySingleZone() async {
    final applied = await applySingleZoneLocation(context);
    if (!mounted) return;
    if (applied) {
      _goToMainIfLocationSet(context);
    } else {
      setState(() => _checkingSingleZone = false);
    }
  }

  Future<void> _openSearch(BuildContext context) async {
    final saved = await AppNavigator.push<bool>(
      context,
      const LocationSearchScreen(),
    );
    if (!context.mounted) return;
    if (saved == true) _goToMainIfLocationSet(context);
  }

  void _goToMainIfLocationSet(BuildContext context) {
    if (SettingsHiveBox.instance.hasLocation) {
      AppNavigator.pushReplacementNamed(context, RouteNames.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSingleZone) {
      return const AppScaffold(body: LoadingWidget());
    }
    return BlocProvider(
      create: (_) => UserLocationCubit(),
      child: BlocConsumer<UserLocationCubit, UserLocationState>(
        listener: (context, state) async {
          if (state is UserLocationDetected) {
            if (SettingsHiveBox.instance.hasLocation) {
              AppNavigator.pushReplacementNamed(context, RouteNames.main);
            }
          } else if (state is UserLocationPermissionDenied) {
            await showLocationPermissionDialog(context);
            if (context.mounted) {
              context.read<UserLocationCubit>().reset();
            }
          } else if (state is UserLocationError) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
            context.read<UserLocationCubit>().reset();
          }
        },
        builder: (context, state) {
          return LocationRequiredView(
            isSettingLocation: state is UserLocationDetecting,
            onSetLocation: () =>
                context.read<UserLocationCubit>().detectCurrentLocation(),
            onSearchManually: () => _openSearch(context),
            onLocationConfirmed: () => _goToMainIfLocationSet(context),
          );
        },
      ),
    );
  }
}
