import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mepharma/src/data/db/app_database.dart';
import 'package:mepharma/src/data/db/enums.dart';
import 'package:mepharma/src/data/repositories/sqlite_auth_repository.dart';
import 'package:mepharma/src/data/repositories/sqlite_user_repository.dart';

void main() {
  late AppDatabase db;
  late SqliteUserRepository userRepo;
  late SqliteAuthRepository authRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    userRepo = SqliteUserRepository(db);
    authRepo = SqliteAuthRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('User Real Name & Username Separation Tests', () {
    test('createUser stores real name and uses it as displayName', () async {
      final user = await userRepo.createUser(
        name: 'Dr. Mohamed Ali',
        username: 'Moe_Ali',
        password: 'password123',
        role: UserRole.pharmacist,
      );

      expect(user.name, 'Dr. Mohamed Ali');
      expect(user.username, 'moe_ali');
      expect(user.displayName, 'Dr. Mohamed Ali');
    });

    test('displayName falls back to username when name is null or whitespace', () async {
      final userWithoutName = await userRepo.createUser(
        username: 'cashier_john',
        password: 'password123',
        role: UserRole.staff,
      );

      expect(userWithoutName.name, isNull);
      expect(userWithoutName.username, 'cashier_john');
      expect(userWithoutName.displayName, 'cashier_john');

      final userWithEmptyName = await userRepo.createUser(
        name: '   ',
        username: 'cashier_sara',
        password: 'password123',
        role: UserRole.staff,
      );

      expect(userWithEmptyName.displayName, 'cashier_sara');
    });

    test('updateUser modifies real name while preserving login credentials', () async {
      final created = await userRepo.createUser(
        name: 'Initial Name',
        username: 'staff_user',
        password: 'secretPassword',
        role: UserRole.staff,
      );

      final updated = await userRepo.updateUser(
        created.id,
        name: 'Dr. Sarah Ahmed',
      );

      expect(updated.name, 'Dr. Sarah Ahmed');
      expect(updated.displayName, 'Dr. Sarah Ahmed');
      expect(updated.username, 'staff_user');

      // Login using username works and returns updated real name
      final loggedIn = await authRepo.login(
        username: 'staff_user',
        password: 'secretPassword',
      );

      expect(loggedIn, isNotNull);
      expect(loggedIn!.name, 'Dr. Sarah Ahmed');
      expect(loggedIn.displayName, 'Dr. Sarah Ahmed');
    });

    test('ensureDefaultAdmin seeds real name as System Admin', () async {
      await userRepo.ensureDefaultAdmin();

      final admin = await userRepo.findByUsername('admin');
      expect(admin, isNotNull);
      expect(admin!.name, 'System Admin');
      expect(admin.displayName, 'System Admin');
      expect(admin.username, 'admin');
    });
  });
}
