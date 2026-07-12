import 'dart:io';
import 'dart:async';

// ── ANSI Colors ──────────────────────────────────────────────────────────────
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _bold = '\x1B[1m';
const _reset = '\x1B[0m';

void _ok(String msg) => stdout.writeln('$_green✅ $msg$_reset');
void _warn(String msg) => stdout.writeln('$_yellow⚠️  $msg$_reset');
void _fail(String msg) => stdout.writeln('$_red❌ $msg$_reset');
void _info(String msg) => stdout.writeln('$_cyanℹ️  $msg$_reset');

bool get _isWindows => Platform.isWindows;

// ── Command runner ───────────────────────────────────────────────────────────
String get _shellExe => _isWindows ? 'powershell' : 'bash';
List<String> _shellArgs(String command) =>
    _isWindows ? ['-NoProfile', '-Command', command] : ['-c', command];

Future<ProcessResult> _run(
  String command, {
  String? workingDirectory,
  bool showOutput = true,
}) async {
  final result = await Process.run(
    _shellExe,
    _shellArgs(command),
    workingDirectory: workingDirectory,
    runInShell: false,
  );
  if (showOutput) {
    if (result.stdout.toString().isNotEmpty) {
      stdout.write(result.stdout);
    }
    if (result.stderr.toString().isNotEmpty) {
      stderr.write(result.stderr);
    }
  }
  return result;
}

// ── Main ─────────────────────────────────────────────────────────────────────
Future<void> main(List<String> args) async {
  final isDryRun = args.contains('--dry-run');
  final isStaging = args.contains('--staging');
  final projectDir = _findProjectRoot();

  stdout.writeln();
  stdout.writeln('$_bold$_cyan┌─────────────────────────────────┐$_reset');
  stdout.writeln('$_bold$_cyan│      microflow release          │$_reset');
  stdout.writeln('$_bold$_cyan└─────────────────────────────────┘$_reset');
  stdout.writeln();

  if (isDryRun) {
    _info('DRY RUN — nothing will be executed');
    stdout.writeln();
  }

  // ── Step 1: Check prerequisites ──────────────────────────────────────────
  _info('Checking prerequisites...');

  // Check if supabase CLI is installed
  final sbCheck = await _run(
    _isWindows ? 'where.exe supabase' : 'which supabase',
    showOutput: false,
  );
  if (sbCheck.exitCode != 0) {
    _fail('Supabase CLI not found!');
    _info('Install it: npm install -g supabase');
    _info('Or visit: https://supabase.com/docs/guides/cli');
    exit(1);
  }
  _ok('Supabase CLI installed');

  // Check if supabase is logged in
  final loginCheck = await _run('supabase projects list', showOutput: false);
  if (loginCheck.exitCode != 0) {
    _warn('Not logged in to Supabase. Opening browser to login...');
    final loginResult = await _run('supabase login', showOutput: true);
    if (loginResult.exitCode != 0) {
      _fail('Failed to login to Supabase');
      exit(1);
    }
  }
  _ok('Supabase logged in');

  // Check if linked to production
  final projectRef = isStaging ? 'mirdnsifontxoccjwgak' : 'tccwdpsnuudzfyxfoohk';

  // Try to link if needed (idempotent)
  if (!isDryRun) {
    final linkCmd = 'supabase link --project-ref $projectRef';
    final linkResult = await _run(linkCmd, workingDirectory: projectDir, showOutput: false);
    if (linkResult.exitCode == 0) {
      _ok('Linked to ${isStaging ? "staging" : "production"}');
    } else {
      // Check if already linked
      final stderr = linkResult.stderr.toString();
      if (stderr.contains('already linked') || stderr.contains('Already linked')) {
        _ok('Already linked to ${isStaging ? "staging" : "production"}');
      } else {
        _warn('Link status unclear, proceeding anyway...');
      }
    }
  } else {
    _ok('Would link to ${isStaging ? "staging" : "production"}');
  }

  stdout.writeln();

  // ── Step 2: Database migration ───────────────────────────────────────────
  _info('Pushing database migrations...');

  if (isDryRun) {
    _ok('Would run: supabase db push');
  } else {
    var pushResult = await _run(
      'supabase db push',
      workingDirectory: projectDir,
    );

    if (pushResult.exitCode != 0) {
      _warn('First push attempt failed. Trying with --include-all...');
      pushResult = await _run(
        'supabase db push --include-all',
        workingDirectory: projectDir,
      );

      if (pushResult.exitCode != 0) {
        _fail('Database migration failed!');
        _info('Please fix the error above and try again.');
        exit(1);
      }
    }
    _ok('Database migrations pushed');
  }

  stdout.writeln();

  // ── Step 3: Version bump ─────────────────────────────────────────────────
  _info('Bumping version...');

  final pubspecFile = File('$projectDir/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    _fail('pubspec.yaml not found!');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s*(.+)$', multiLine: true);
  final match = versionRegex.firstMatch(pubspecContent);

  if (match == null) {
    _fail('Could not find version in pubspec.yaml');
    exit(1);
  }

  final currentVersion = match.group(1)!.trim();
  final parts = currentVersion.split('+');
  final currentSemver = parts[0];
  final currentBuildNum = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;

  stdout.writeln('  Current version: $_bold$currentVersion$_reset');
  stdout.write('  New version: ');

  String newVersion;

  if (isDryRun) {
    // For dry run, just show what would happen
    newVersion = currentSemver; // Keep same for dry run
    stdout.writeln('$newVersion (dry run, no change)');
    _ok('Would bump version: $currentVersion → $newVersion+${currentBuildNum + 1}');
  } else {
    // Read from stdin
    final input = stdin.readLineSync()?.trim();
    if (input == null || input.isEmpty) {
      _fail('No version entered');
      exit(1);
    }

    // Validate version format (x.y.z)
    final versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
    if (!versionPattern.hasMatch(input)) {
      _fail('Invalid version format. Use x.y.z (e.g., 1.0.8)');
      exit(1);
    }

    newVersion = input;
    final newBuildNum = currentBuildNum + 1;
    final newFullVersion = '$newVersion+$newBuildNum';

    // Update pubspec.yaml
    final updatedContent = pubspecContent.replaceFirst(
      RegExp(r'^version:\s*.+$', multiLine: true),
      'version: $newFullVersion',
    );

    pubspecFile.writeAsStringSync(updatedContent);
    _ok('Version bumped: $currentVersion → $newFullVersion');
  }

  stdout.writeln();

  // ── Step 4: Commit and push ──────────────────────────────────────────────
  _info('Committing and pushing...');

  if (isDryRun) {
    _ok('Would commit all changes and push to development');
  } else {
    // Check for uncommitted changes
    final statusResult = await _run('git status --porcelain', workingDirectory: projectDir, showOutput: false);
    if (statusResult.stdout.toString().trim().isNotEmpty) {
      // There are changes, commit them
      await _run('git add .', workingDirectory: projectDir, showOutput: false);
      await _run(
        'git commit -m "chore: release v$newVersion"',
        workingDirectory: projectDir,
        showOutput: false,
      );
      _ok('Changes committed');
    } else {
      _info('No uncommitted changes to commit');
    }

    // Push to development
    final pushResult = await _run(
      'git push origin development',
      workingDirectory: projectDir,
    );

    if (pushResult.exitCode != 0) {
      _warn('Push failed. Trying to push with upstream...');
      await _run(
        'git push --set-upstream origin development',
        workingDirectory: projectDir,
      );
    }

    _ok('Pushed to development');
  }

  stdout.writeln();

  // ── Step 5: Merge development → main ─────────────────────────────────────
  _info('Merging development → main...');

  if (isDryRun) {
    _ok('Would merge development into main');
  } else {
    // Fetch latest
    await _run('git fetch origin', workingDirectory: projectDir, showOutput: false);

    // Switch to main and reset graphify-out to avoid merge conflicts
    // (graphify files are regenerated artifacts, not source of truth)
    await _run('git checkout main', workingDirectory: projectDir, showOutput: false);
    await _run(
      'git checkout -- graphify-out/',
      workingDirectory: projectDir,
      showOutput: false,
    );
    final mergeResult = await _run(
      'git merge origin/development --no-edit -m "chore: merge development into main for release v$newVersion"',
      workingDirectory: projectDir,
    );

    if (mergeResult.exitCode != 0) {
      _warn('Merge conflict detected. Aborting merge...');
      await _run('git merge --abort', workingDirectory: projectDir, showOutput: false);
      await _run('git checkout development', workingDirectory: projectDir, showOutput: false);
      _fail('Could not merge. Fix conflicts manually and try again.');
      exit(1);
    }

    // Push main
    await _run('git push origin main', workingDirectory: projectDir);

    // Switch back to development
    await _run('git checkout development', workingDirectory: projectDir, showOutput: false);

    _ok('Merged development → main');
  }

  stdout.writeln();

  // ── Step 6: Tag and push ─────────────────────────────────────────────────
  _info('Tagging and pushing...');

  final tagVersion = newVersion;
  final tagName = 'v$tagVersion';

  if (isDryRun) {
    _ok('Would create tag: $tagName');
    _ok('Would push tag to GitHub');
  } else {
    // Create tag
    final tagResult = await _run(
      'git tag $tagName',
      workingDirectory: projectDir,
    );

    if (tagResult.exitCode != 0) {
      final stderr = tagResult.stderr.toString();
      if (stderr.contains('already exists') || stderr.contains('fatal: tag')) {
        _warn('Tag $tagName already exists. Updating...');
        await _run(
          'git tag -d $tagName',
          workingDirectory: projectDir,
          showOutput: false,
        );
        await _run(
          'git push origin :refs/tags/$tagName',
          workingDirectory: projectDir,
          showOutput: false,
        );
        await _run(
          'git tag $tagName',
          workingDirectory: projectDir,
          showOutput: false,
        );
      } else {
        _fail('Failed to create tag: $stderr');
        exit(1);
      }
    }

    // Push tag
    await _run(
      'git push origin $tagName',
      workingDirectory: projectDir,
    );

    _ok('Tagged and pushed $tagName');
  }

  stdout.writeln();

  // ── Done ─────────────────────────────────────────────────────────────────
  if (isDryRun) {
    stdout.writeln('$_bold$_yellow╔═══════════════════════════════════════════════╗$_reset');
    stdout.writeln('$_bold$_yellow║  DRY RUN COMPLETE — Nothing was executed     ║$_reset');
    stdout.writeln('$_bold$_yellow╚═══════════════════════════════════════════════╝$_reset');
  } else {
    stdout.writeln('$_bold$_green╔═══════════════════════════════════════════════╗$_reset');
    stdout.writeln('$_bold$_green║  🚀 Release $tagName started!                  ║$_reset');
    stdout.writeln('$_bold$_green║  Check GitHub Actions for build progress.     ║$_reset');
    stdout.writeln('$_bold$_green╚═══════════════════════════════════════════════╝$_reset');
  }

  stdout.writeln();
}

// ── Find project root ────────────────────────────────────────────────────────
String _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      _fail('Could not find pubspec.yaml. Are you in the project directory?');
      exit(1);
    }
    dir = parent;
  }
}
