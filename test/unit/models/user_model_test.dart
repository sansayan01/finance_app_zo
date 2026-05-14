import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('creates instance with required fields', () {
      final user = UserModel(
        id: '123',
        email: 'test@example.com',
        fullName: 'Test User',
      );

      expect(user.id, '123');
      expect(user.email, 'test@example.com');
      expect(user.fullName, 'Test User');
      expect(user.isActive, true);
      expect(user.is2FAEnabled, false);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'user-123',
        'email': 'john@example.com',
        'full_name': 'John Doe',
        'phone': '+919999999999',
        'avatar_url': 'https://example.com/avatar.png',
        'org_id': 'org-456',
        'branch_id': 'branch-789',
        'role': 'collectionAgent',
        'is_2fa_enabled': true,
        'is_active': false,
        'created_at': '2024-01-15T10:30:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user-123');
      expect(user.email, 'john@example.com');
      expect(user.fullName, 'John Doe');
      expect(user.phone, '+919999999999');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.orgId, 'org-456');
      expect(user.branchId, 'branch-789');
      expect(user.role, UserRole.collectionAgent);
      expect(user.is2FAEnabled, true);
      expect(user.isActive, false);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.fullName, '');
      expect(user.phone, null);
      expect(user.is2FAEnabled, false);
      expect(user.isActive, true);
    });

    test('toJson serializes correctly', () {
      final user = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
        phone: '+919999999999',
        role: UserRole.manager,
        is2FAEnabled: true,
        isActive: false,
      );

      final json = user.toJson();

      expect(json['id'], 'user-123');
      expect(json['email'], 'test@example.com');
      expect(json['full_name'], 'Test User');
      expect(json['phone'], '+919999999999');
      expect(json['role'], 'manager');
      expect(json['is_2fa_enabled'], true);
      expect(json['is_active'], false);
    });

    test('supports equality', () {
      final user1 = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
      );

      final user2 = UserModel(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
      );

      expect(user1, equals(user2));
    });
  });

  group('ProfileModel', () {
    test('creates instance with required fields', () {
      final profile = ProfileModel(id: 'profile-123');

      expect(profile.id, 'profile-123');
      expect(profile.fullName, null);
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'profile-123',
        'user_id': 'user-456',
        'full_name': 'Jane Doe',
        'phone': '+919988776655',
        'pan': 'ABCDE1234F',
        'aadhar': '123456789012',
        'address': '123 Main Street',
        'city': 'Bangalore',
        'state': 'Karnataka',
        'pincode': '560001',
        'role': 'manager',
        'org_id': 'org-789',
        'branch_id': 'branch-101',
        'employee_id': 'EMP001',
        'date_of_birth': '1990-05-15',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-06-01T00:00:00Z',
      };

      final profile = ProfileModel.fromJson(json);

      expect(profile.id, 'profile-123');
      expect(profile.userId, 'user-456');
      expect(profile.fullName, 'Jane Doe');
      expect(profile.phone, '+919988776655');
      expect(profile.pan, 'ABCDE1234F');
      expect(profile.aadhar, '123456789012');
      expect(profile.address, '123 Main Street');
      expect(profile.city, 'Bangalore');
      expect(profile.state, 'Karnataka');
      expect(profile.pincode, '560001');
      expect(profile.role, UserRole.manager);
      expect(profile.orgId, 'org-789');
      expect(profile.branchId, 'branch-101');
      expect(profile.employeeId, 'EMP001');
    });

    test('handles branch name from nested object', () {
      final json = {
        'id': 'profile-123',
        'branch': {'name': 'Downtown Branch'},
      };

      final profile = ProfileModel.fromJson(json);

      expect(profile.branchName, 'Downtown Branch');
    });

    test('toJson serializes correctly', () {
      final profile = ProfileModel(
        id: 'profile-123',
        fullName: 'Test Profile',
        role: UserRole.collectionAgent,
        orgId: 'org-001',
      );

      final json = profile.toJson();

      expect(json['id'], 'profile-123');
      expect(json['full_name'], 'Test Profile');
      expect(json['role'], 'collectionAgent');
      expect(json['org_id'], 'org-001');
    });
  });
}