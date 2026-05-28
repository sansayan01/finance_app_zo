import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../data/repositories/members_repository.dart';
import '../../data/models/member_model.dart';

final membersRepositoryProvider = Provider<MembersRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return MembersRepository(ref.watch(supabaseClientProvider), orgId);
});

final membersSearchQueryProvider = StateProvider<String>((ref) => '');

final membersProvider = FutureProvider<List<MemberModel>>((ref) async {
  final repository = ref.watch(membersRepositoryProvider);
  final query = ref.watch(membersSearchQueryProvider);
  return repository.getMembers(query: query);
});

final memberSummaryProvider = FutureProvider<MemberSummary>((ref) async {
  final repository = ref.watch(membersRepositoryProvider);
  return repository.getMemberSummary();
});
