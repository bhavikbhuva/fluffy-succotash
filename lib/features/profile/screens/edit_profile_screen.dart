import 'dart:io';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/profile/cubit/profile_update_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/country_dropdown_field.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import '../cubit/profile_detail_cubit.dart';
import '../../../commons/widgets/app_button.dart';
import '../../../commons/widgets/app_text_field.dart';
import '../../../commons/widgets/custom_app_bar.dart';
import '../../../utils/input_validators.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/localization_extensions.dart';
import '../../../utils/extensions/size_extensions.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/auth/models/auth_model.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:customer/features/profile/widgets/profile_verify_sheet.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';
import '../../../commons/widgets/app_text.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _scrollController = ScrollController();

  File? _profileImage;
  String? _profileImageUrl;
  String _phoneNumberOnly = '';
  CountriesData? _selectedCountry;
  CountriesData? _phoneCountry;
  bool _countryPrefilled = false;

  // ── Verification state ────────────────────────────────────────────────────
  final AuthRepository _authRepository = AuthRepository();
  final AppSettingsData? _settings = SettingsHiveBox.instance.getAppSettings();
  String _savedMobile = '';
  String _savedEmail = '';
  bool? _mobileVerified;
  bool? _emailVerified;
  bool _isVerifying = false;
  DateTime? _mobileRetryAt;
  DateTime? _emailRetryAt;
  bool _mobileVerifyUnavailable = false;
  bool _emailVerifyUnavailable = false;

  String? get _authType => AuthHiveBox.instance.userData?.type;
  bool get _isEmailReadOnly =>
      _authType == AuthType.google.name ||
      _authType == AuthType.apple.name ||
      _authType == AuthType.email.name;
  bool get _isPhoneReadOnly => _authType == AuthType.phone.name;

  String get _currentMobile => _phoneNumberOnly.isNotEmpty
      ? _phoneNumberOnly
      : _mobileController.text.trim();
  String get _currentEmail => _emailController.text.trim();

  bool get _canSendFirebaseOtp => _settings?.firebaseAuthentication == '1';
  bool get _canSendCustomOtp =>
      !_canSendFirebaseOtp && _settings?.customSmsGatewayOtpBased == '1';

  /// Mobile Verify button: only for accounts whose mobile is editable, when
  /// the store can verify it and the number is new or still unverified.
  bool get _showMobileVerify =>
      !_isPhoneReadOnly &&
      !_mobileVerifyUnavailable &&
      _settings?.mobileVerificationAvailable == '1' &&
      (_canSendFirebaseOtp || _canSendCustomOtp) &&
      _currentMobile.isNotEmpty &&
      (_currentMobile != _savedMobile || _mobileVerified == false);

  /// Email Verify button: only for phone accounts (email is editable there).
  bool get _showEmailVerify =>
      !_isEmailReadOnly &&
      !_emailVerifyUnavailable &&
      _settings?.emailVerificationAvailable == '1' &&
      _currentEmail.isNotEmpty &&
      (_currentEmail.toLowerCase() != _savedEmail.toLowerCase() ||
          _emailVerified == false);

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadCurrentProfile(ProfileDetailState state) {
    if (state is ProfileDetailLoaded) {
      final user = state.profile.data;
      if (_usernameController.text.isEmpty) {
        _usernameController.text = user?.name ?? '';
        _mobileController.text = user?.mobile ?? '';
        _emailController.text = user?.email ?? '';
        _savedMobile = user?.mobile ?? '';
        _savedEmail = user?.email ?? '';
        _mobileVerified = user?.mobileVerified;
        _emailVerified = user?.emailVerified;
        _profileImageUrl = user?.profile;
      }
    }
  }

  void _prefillCountry(
    BuildContext context,
    int? countryId,
    String? countryCode,
  ) {
    if (_countryPrefilled) return;
    final countriesState = context.read<CountriesCubit>().state;
    if (countriesState is! CountriesLoaded) return;
    final countries = countriesState.countries;

    final byId = countryId == null
        ? null
        : countries.where((c) => c.id == countryId).firstOrNull;
    final byDefault = findDefaultCountry(countries);
    final country = byId ?? byDefault;
    if (country == null) return;

    // Phone dial code is stored separately from the profile country; prefer
    // the profile country when it shares the dial code (e.g. +1 US/Canada).
    final dialCode = (countryCode ?? '').replaceAll('+', '');
    final phoneCountry =
        dialCode.isNotEmpty &&
            (country.dialCode ?? '').replaceAll('+', '') != dialCode
        ? findCountryByDialCode(countries, dialCode) ?? country
        : country;

    _countryPrefilled = true;
    setState(() {
      _selectedCountry = country;
      _phoneCountry = phoneCountry;
    });
  }

  void _updateProfile(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    // A new number/email must be verified first; saving it unverified is not
    // allowed while the store has verification on.
    final mobileUnverified =
        _showMobileVerify && _currentMobile != _savedMobile;
    final emailUnverified =
        _showEmailVerify &&
        _currentEmail.toLowerCase() != _savedEmail.toLowerCase();
    if (mobileUnverified || emailUnverified) {
      AppSnackBar.show(
        context: context,
        message: context.translate(
          mobileUnverified
              ? LanguageLabelKeys.verifyMobileBeforeSaving
              : LanguageLabelKeys.verifyEmailBeforeSaving,
        ),
        type: SnackBarType.warning,
      );
      return;
    }
    context.read<ProfileUpdateCubit>().updateProfile(
      name: _usernameController.text.trim(),
      mobile: _phoneNumberOnly.isNotEmpty
          ? _phoneNumberOnly
          : _mobileController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      profileImagePath: _profileImage?.path,
      countryId: _selectedCountry?.id?.toString(),
      countryCode: _phoneCountry?.dialCode,
    );
  }

  void _showVerifyError(Object e) {
    if (!mounted) return;
    AppSnackBar.show(
      context: context,
      message: e is ApiException
          ? e.message
          : context.translate(LanguageLabelKeys.somethingWentWrong),
      type: SnackBarType.error,
    );
  }

  void _applyVerifiedProfile(AuthModel result, {required bool isMobile}) {
    AuthHiveBox.instance.updateUserSession(updated: result);
    final data = result.data;
    if (!mounted) return;
    setState(() {
      if (isMobile) {
        _savedMobile = data?.mobile ?? _currentMobile;
        _mobileVerified = data?.mobileVerified ?? true;
      } else {
        _savedEmail = data?.email ?? _currentEmail;
        _emailVerified = data?.emailVerified ?? true;
      }
    });
    AppSnackBar.show(
      context: context,
      message: context.translate(
        isMobile
            ? LanguageLabelKeys.mobileVerifiedSuccess
            : LanguageLabelKeys.emailVerifiedSuccess,
      ),
      type: SnackBarType.success,
    );
  }

  /// True while a 429 cool-down is running; tells the customer how long.
  bool _blockedByCooldown(DateTime? retryAt) {
    if (retryAt == null || !DateTime.now().isBefore(retryAt)) return false;
    final secs = retryAt.difference(DateTime.now()).inSeconds + 1;
    AppSnackBar.show(
      context: context,
      message:
          '${context.translate(LanguageLabelKeys.verificationRetryIn)} ${_formatWait(secs)}',
      type: SnackBarType.warning,
    );
    return true;
  }

  /// 4014s -> "1h 7m", 125s -> "2m 5s", 40s -> "40s".
  String _formatWait(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
    return '${s}s';
  }

  DateTime _retryAtFrom(ApiException e) => DateTime.now().add(
    Duration(seconds: e.retryAfterSeconds ?? AppConfig.otpResendTimerSeconds),
  );

  Future<void> _verifyMobile() async {
    if (_isVerifying || _blockedByCooldown(_mobileRetryAt)) return;
    final mobile = _currentMobile;
    final countryCode = _phoneCountry?.dialCode ?? '';
    final fullNumber = '$countryCode$mobile';
    final title = context.translate(LanguageLabelKeys.verifyMobileNumber);
    setState(() => _isVerifying = true);
    try {
      AuthModel? result;
      if (_canSendFirebaseOtp) {
        var verificationId = await _authRepository
            .sendPhoneOtpAndGetVerificationId(
              phoneNumber: mobile,
              countryCode: countryCode,
            );
        Future<AuthModel> save() async {
          final token = await _authRepository.getFirebaseIdToken();
          return _authRepository.verifyProfileMobile(
            mobile: mobile,
            countryCode: countryCode,
            firebaseIdToken: token,
          );
        }

        if (verificationId == null) {
          // Android verified the number instantly, no code to type.
          result = await save();
        } else {
          if (!mounted) return;
          final ok = await showProfileVerifySheet(
            context,
            title: title,
            target: fullNumber,
            onVerify: (code) async {
              await _authRepository.verifyFirebasePhoneOtp(
                verificationId: verificationId!,
                smsCode: code,
              );
              result = await save();
            },
            onResend: () async {
              verificationId = await _authRepository
                  .sendPhoneOtpAndGetVerificationId(
                    phoneNumber: mobile,
                    countryCode: countryCode,
                  );
            },
          );
          if (ok != true) result = null;
        }
      } else {
        await _authRepository.sendProfileSms(fullNumber: fullNumber);
        if (!mounted) return;
        final ok = await showProfileVerifySheet(
          context,
          title: title,
          target: fullNumber,
          onVerify: (code) async {
            result = await _authRepository.verifyProfileMobile(
              mobile: mobile,
              countryCode: countryCode,
              otp: code,
            );
          },
          onResend: () =>
              _authRepository.sendProfileSms(fullNumber: fullNumber),
        );
        if (ok != true) result = null;
      }
      if (result != null) _applyVerifiedProfile(result!, isMobile: true);
    } on ApiException catch (e) {
      if (e.isRateLimited) _mobileRetryAt = _retryAtFrom(e);
      if (e.messageStatusCode == 'MOBILE_VERIFICATION_NOT_AVAILABLE') {
        if (mounted) setState(() => _mobileVerifyUnavailable = true);
      }
      _showVerifyError(e);
    } catch (e) {
      _showVerifyError(e);
    } finally {
      // Firebase phone sign-in is only a proof; the app login is the API token.
      await _authRepository.signOutFirebase();
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _verifyEmail() async {
    if (_isVerifying || _blockedByCooldown(_emailRetryAt)) return;
    final email = _currentEmail;
    setState(() => _isVerifying = true);
    try {
      await _authRepository.sendEmailChangeCode(email: email);
      if (!mounted) return;
      AuthModel? result;
      await showProfileVerifySheet(
        context,
        title: context.translate(LanguageLabelKeys.verifyEmailAddress),
        target: email,
        onVerify: (code) async {
          result = await _authRepository.verifyProfileEmail(
            email: email,
            emailCode: code,
          );
        },
        onResend: () => _authRepository.sendEmailChangeCode(email: email),
      );
      if (result != null) _applyVerifiedProfile(result!, isMobile: false);
    } on ApiException catch (e) {
      if (e.isRateLimited) _emailRetryAt = _retryAtFrom(e);
      if (e.messageStatusCode == 'EMAIL_VERIFICATION_NOT_AVAILABLE') {
        if (mounted) setState(() => _emailVerifyUnavailable = true);
      }
      _showVerifyError(e);
    } catch (e) {
      _showVerifyError(e);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  /// Suffix inside the field: Verify button, spinner while verifying, or a
  /// success check icon. Null when the field has nothing to show.
  Widget? _buildVerifySuffix({
    required bool show,
    required bool isVerified,
    required VoidCallback onPressed,
  }) {
    if (show) {
      if (_isVerifying) {
        return const Padding(
          padding: EdgeInsetsDirectional.only(end: ThemeConstants.paddingM),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingM,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: AppText(
          context.translate(LanguageLabelKeys.verify),
          style: context.tt.labelLarge?.copyWith(
            color: context.cs.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (isVerified) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: ThemeConstants.paddingM),
        // onSecondaryContainer is the theme's success colour (light + dark).
        child: AppSvgIcon(
          AssetsConstants.checkCircleIcon,
          size: ThemeConstants.iconL,
          color: context.cs.onSecondaryContainer,
        ),
      );
    }
    return null;
  }

  Future<void> _pickImage() async {
    final source = await showAppBottomSheet<ImageSource>(
      context,
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingS,
      ),
      builder: (ctx) => SlideAnimationList(
        children: [
          ListTile(
            leading: AppSvgIcon(
              AssetsConstants.cameraIcon,
              size: ThemeConstants.iconL,
              color: context.cs.onSurfaceVariant,
            ),
            title: AppText(context.translate(LanguageLabelKeys.takePhoto)),
            onTap: () => AppNavigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: AppSvgIcon(
              AssetsConstants.galleryIcon,
              size: ThemeConstants.iconL,
              color: context.cs.onSurfaceVariant,
            ),
            title: AppText(
              context.translate(LanguageLabelKeys.chooseFromGallery),
            ),
            onTap: () => AppNavigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.translate(LanguageLabelKeys.cropPhoto),
          toolbarColor: context.cs.primary,
          toolbarWidgetColor: context.cs.onPrimary,
          activeControlsWidgetColor: context.cs.primary,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: context.translate(LanguageLabelKeys.cropPhoto),
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped != null) {
      setState(() {
        _profileImage = File(cropped.path);
        _profileImageUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: context.translate(LanguageLabelKeys.editProfile),
        scrollController: _scrollController,
      ),
      bottomNavigationBar:
          BlocSelector<ProfileUpdateCubit, ProfileUpdateState, bool>(
            selector: (state) => state is ProfileUpdateLoading,
            builder: (context, isLoading) =>
                _buildBottomButton(context, isLoading),
          ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<ProfileUpdateCubit, ProfileUpdateState>(
            listener: (context, state) {
              if (state is ProfileUpdateLoaded) {
                AppSnackBar.show(
                  context: context,
                  message: context.translate(
                    LanguageLabelKeys.profileUpdatedSuccess,
                  ),
                  type: SnackBarType.success,
                );
                AppNavigator.pop(context);
              } else if (state is ProfileUpdateError) {
                AppSnackBar.show(
                  context: context,
                  message: state.message,
                  type: SnackBarType.error,
                );
              }
            },
          ),
          BlocListener<ProfileDetailCubit, ProfileDetailState>(
            listener: (context, state) {
              setState(() => _loadCurrentProfile(state));
              if (state is ProfileDetailLoaded) {
                _prefillCountry(
                  context,
                  state.profile.data?.countryId,
                  state.profile.data?.countryCode,
                );
              }
            },
          ),
          BlocListener<CountriesCubit, CountriesState>(
            listener: (context, state) {
              if (state is CountriesLoaded) {
                final user = context.read<ProfileDetailCubit>().state;
                if (user is ProfileDetailLoaded) {
                  _prefillCountry(
                    context,
                    user.profile.data?.countryId,
                    user.profile.data?.countryCode,
                  );
                }
              }
            },
          ),
        ],
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingXXL,
            ThemeConstants.spaceXXXL,
            ThemeConstants.paddingXXL,
            ThemeConstants.paddingL,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Center(child: _buildProfileAvatar()),
                AppSpacing.h32,
                AppTextField(
                  controller: _usernameController,
                  labelText: context.translate(LanguageLabelKeys.fullName),
                  hintText: context.translate(LanguageLabelKeys.enterFullName),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                  ],
                  validator: (v) => v.validateName(context),
                ),
                AppSpacing.h16,
                AppTextField(
                  controller: _emailController,
                  labelText: context.translate(LanguageLabelKeys.email),
                  hintText: context.translate(LanguageLabelKeys.enterEmail),
                  keyboardType: TextInputType.emailAddress,
                  readOnly: _isEmailReadOnly,
                  validator: (v) => v.validateEmail(context, required: false),
                  onChanged: (_) => setState(() {}),
                  suffixIcon: _buildVerifySuffix(
                    show: _showEmailVerify,
                    // Login-method field is locked and always verified.
                    isVerified:
                        _currentEmail.isNotEmpty &&
                        (_isEmailReadOnly || _emailVerified == true),
                    onPressed: _verifyEmail,
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
                AppSpacing.h16,
                ApiCountryPhoneField(
                  controller: _mobileController,
                  selectedCountry: _phoneCountry,
                  labelText: context.translate(LanguageLabelKeys.mobileNumber),
                  hintText: context.translate(
                    LanguageLabelKeys.enterPhoneNumber,
                  ),
                  readOnly: _isPhoneReadOnly,
                  validator: (v) => v.validateMobile(
                    context,
                    minLength: _phoneCountry?.minMobileLength ?? 10,
                    required: _authType == AuthType.phone.name,
                  ),
                  onCountryChanged: (country) => setState(() {
                    _phoneCountry = country;
                  }),
                  onChanged: (number) {
                    setState(() => _phoneNumberOnly = number);
                  },
                  suffixIcon: _buildVerifySuffix(
                    show: _showMobileVerify,
                    isVerified:
                        _currentMobile.isNotEmpty &&
                        (_isPhoneReadOnly || _mobileVerified == true),
                    onPressed: _verifyMobile,
                  ),
                ),
                AppSpacing.h16,
                CountryDropdownField(
                  selected: _selectedCountry,
                  labelText: context.translate(LanguageLabelKeys.country),
                  hintText: context.translate(LanguageLabelKeys.enterCountry),
                  onChanged: (country) =>
                      setState(() => _selectedCountry = country),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final hasLocalImage = _profileImage != null;
    final hasNetworkImage =
        _profileImageUrl != null && _profileImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: AppDecorations.box(
              shape: .circle,
              color: context.cs.primaryContainer,
              border: Border.all(
                color: context.cs.primary.withValues(alpha: 0.25),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: hasLocalImage
                  ? Image.file(_profileImage!, fit: BoxFit.cover)
                  : hasNetworkImage
                  ? AppNetworkImage(
                      url: _profileImageUrl!,
                      placeholder: AppSvgIcon(
                        AssetsConstants.userIcon,
                        size: ThemeConstants.iconXL,
                        color: context.cs.primary,
                        fit: BoxFit.scaleDown,
                      ),
                      errorWidget: AppSvgIcon(
                        AssetsConstants.userIcon,
                        size: ThemeConstants.iconXL,
                        color: context.cs.primary,
                        fit: BoxFit.scaleDown,
                      ),
                    )
                  : AppSvgIcon(
                      AssetsConstants.userIcon,
                      size: ThemeConstants.iconXL,
                      color: context.cs.primary,
                      fit: BoxFit.scaleDown,
                    ),
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: AppDecorations.box(
                shape: .circle,
                color: context.cs.primary,
                border: Border.all(color: context.cs.surface, width: 2),
              ),
              padding: const EdgeInsetsDirectional.all(
                ThemeConstants.paddingXS,
              ),
              child: AppSvgIcon(
                AssetsConstants.cameraIcon,
                size: ThemeConstants.iconL,
                color: context.cs.onPrimary,
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, bool isLoading) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM + context.bottomSafePadding,
      ),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        boxShadow: [
          BoxShadow(
            color: context.cs.scrim.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: AppButton(
        label: context.translate(LanguageLabelKeys.updateProfile),
        onPressed: () => _updateProfile(context),
        isLoading: isLoading,
      ),
    );
  }
}
