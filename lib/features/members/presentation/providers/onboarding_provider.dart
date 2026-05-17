import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/core/constants/enums.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/member_model.dart';
import '../../data/repositories/members_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/providers/org_provider.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

class OnboardingState {
  final String fullName;
  final String phone;
  final String shopName;
  final String businessType;
  final double? latitude;
  final double? longitude;
  final bool isLoading;
  final String? error;

  OnboardingState({
    this.fullName = '',
    this.phone = '',
    this.shopName = '',
    this.businessType = '',
    this.latitude,
    this.longitude,
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    String? fullName,
    String? phone,
    String? shopName,
    String? businessType,
    double? latitude,
    double? longitude,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      shopName: shopName ?? this.shopName,
      businessType: businessType ?? this.businessType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final MembersRepository _repository;
  final LocationService _locationService;

  OnboardingNotifier(this._repository, this._locationService)
      : super(OnboardingState());

  void updateFullName(String val) => state = state.copyWith(fullName: val);
  void updatePhone(String val) => state = state.copyWith(phone: val);
  void updateShopName(String val) => state = state.copyWith(shopName: val);
  void updateBusinessType(String val) =>
      state = state.copyWith(businessType: val);

  Future<void> captureLocation() async {
    state = state.copyWith(isLoading: true);
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        isLoading: false,
      );
    } else {
      state =
          state.copyWith(isLoading: false, error: 'Could not capture location');
    }
  }

  Future<bool> submit() async {
    if (state.fullName.isEmpty || state.phone.isEmpty) {
      state = state.copyWith(error: 'Full name and phone are required');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final member = MemberModel(
        id: const Uuid().v4(),
        fullName: state.fullName,
        phone: state.phone,
        memberId: 'MEM-${const Uuid().v4().substring(0, 8).toUpperCase()}',
        kycStatus: KYCStatus.pending,
        createdAt: DateTime.now(),
        shopName: state.shopName,
        businessType: state.businessType,
        latitude: state.latitude,
        longitude: state.longitude,
      );

      await _repository.createMember(member);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() => state = OnboardingState();
}

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return MembersRepository(client, orgId);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(
    ref.watch(membersRepositoryProvider),
    ref.watch(locationServiceProvider),
  );
});
