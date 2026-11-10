import 'dart:async';

import '../../core/services/network_monitor.dart';
import '../../core/services/sync_engine.dart';
import '../../domain/models/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import 'api/api_customer_repository.dart';
import 'sqlite_customer_repository.dart';

class OfflineFirstCustomerRepository implements CustomerRepository {
  OfflineFirstCustomerRepository({
    required ApiCustomerRepository apiRepo,
    required SqliteCustomerRepository localRepo,
    required SyncEngine syncEngine,
    required NetworkMonitor networkMonitor,
  })  : _apiRepo = apiRepo,
        _localRepo = localRepo,
        _syncEngine = syncEngine,
        _networkMonitor = networkMonitor;

  final ApiCustomerRepository _apiRepo;
  final SqliteCustomerRepository _localRepo;
  final SyncEngine _syncEngine;
  final NetworkMonitor _networkMonitor;

  bool get _isOnline => _networkMonitor.isOnline;

  Future<void> _mirrorToLocal(List<CustomerWithBalance> list) async {
    for (final item in list) {
      try {
        final c = item.customer;
        final existing = await _localRepo.findById(c.id);
        if (existing == null) {
          await _localRepo.create(
            name: c.name,
            phone: c.phone,
            email: c.email,
            address: c.address,
            notes: c.notes,
            creditLimit: c.creditLimit,
          );
        } else {
          await _localRepo.update(
            c.id,
            name: c.name,
            phone: c.phone,
            email: c.email,
            address: c.address,
            notes: c.notes,
            creditLimit: c.creditLimit,
          );
        }
      } catch (_) {}
    }
  }

  @override
  Stream<List<CustomerWithBalance>> watchAll() async* {
    if (_isOnline) {
      try {
        final list = await _apiRepo.watchAll().first;
        unawaited(_mirrorToLocal(list));
        yield list;
      } catch (_) {}
      yield* _apiRepo.watchAll();
    } else {
      yield* _localRepo.watchAll();
    }
  }

  @override
  Future<Customer?> findById(int id) async {
    if (_isOnline) {
      try {
        return await _apiRepo.findById(id);
      } catch (_) {
        return _localRepo.findById(id);
      }
    }
    return _localRepo.findById(id);
  }

  @override
  Future<Customer> create({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    int creditLimit = 0,
  }) async {
    if (_isOnline) {
      try {
        final customer = await _apiRepo.create(
          name: name,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
          creditLimit: creditLimit,
        );
        unawaited(_mirrorToLocal([
          CustomerWithBalance(
            customer: customer,
            outstanding: 0,
            totalPaid: 0,
            totalCredit: 0,
          )
        ]));
        return customer;
      } catch (e) {
        _networkMonitor.reportFailure(e);
      }
    }

    final customer = await _localRepo.create(
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      creditLimit: creditLimit,
    );

    final payload = {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'credit_limit': creditLimit,
    };

    await _syncEngine.enqueueAction(
      entityType: 'customer',
      action: 'create',
      payload: payload,
    );

    return customer;
  }

  @override
  Future<void> update(
    int id, {
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    int? creditLimit,
  }) async {
    if (_isOnline) {
      try {
        await _apiRepo.update(
          id,
          name: name,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
          creditLimit: creditLimit,
        );
        await _localRepo.update(
          id,
          name: name,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
          creditLimit: creditLimit,
        );
        return;
      } catch (e) {
        _networkMonitor.reportFailure(e);
      }
    }

    await _localRepo.update(
      id,
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      creditLimit: creditLimit,
    );

    final payload = {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'credit_limit': creditLimit,
    };

    await _syncEngine.enqueueAction(
      entityType: 'customer',
      action: 'update',
      payload: payload,
    );
  }

  @override
  Future<void> delete(int id) async {
    if (_isOnline) {
      try {
        await _apiRepo.delete(id);
        await _localRepo.delete(id);
        return;
      } catch (e) {
        _networkMonitor.reportFailure(e);
      }
    }

    await _localRepo.delete(id);
    await _syncEngine.enqueueAction(
      entityType: 'customer',
      action: 'delete',
      payload: {'id': id},
    );
  }

  @override
  Future<bool> isNameTaken(String name, {int? excludeId}) async {
    if (_isOnline) {
      try {
        return await _apiRepo.isNameTaken(name, excludeId: excludeId);
      } catch (_) {
        return _localRepo.isNameTaken(name, excludeId: excludeId);
      }
    }
    return _localRepo.isNameTaken(name, excludeId: excludeId);
  }

  @override
  Future<int> getBalance(int customerId) async {
    if (_isOnline) {
      try {
        return await _apiRepo.getBalance(customerId);
      } catch (_) {
        return _localRepo.getBalance(customerId);
      }
    }
    return _localRepo.getBalance(customerId);
  }

  @override
  Future<CustomerPayment> recordPayment({
    required int customerId,
    required int amount,
    int? userId,
    String? note,
  }) async {
    if (_isOnline) {
      try {
        final payment = await _apiRepo.recordPayment(
          customerId: customerId,
          amount: amount,
          userId: userId,
          note: note,
        );
        await _localRepo.recordPayment(
          customerId: customerId,
          amount: amount,
          userId: userId,
          note: note,
        );
        return payment;
      } catch (e) {
        _networkMonitor.reportFailure(e);
      }
    }

    final payment = await _localRepo.recordPayment(
      customerId: customerId,
      amount: amount,
      userId: userId,
      note: note,
    );

    final payload = {
      'customer_id': customerId,
      'amount': amount,
      'user_id': userId,
      'notes': note,
    };

    await _syncEngine.enqueueAction(
      entityType: 'customer_payment',
      action: 'create',
      payload: payload,
    );

    return payment;
  }

  @override
  Stream<List<CustomerPayment>> watchPayments(int customerId) {
    if (_isOnline) {
      return _apiRepo.watchPayments(customerId);
    }
    return _localRepo.watchPayments(customerId);
  }

  @override
  Future<void> refresh() async {
    if (_isOnline) {
      await _apiRepo.refresh();
    }
    await _localRepo.refresh();
  }
}
