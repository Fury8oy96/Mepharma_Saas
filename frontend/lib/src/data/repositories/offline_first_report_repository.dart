import '../../core/services/network_monitor.dart';
import '../../domain/models/report_depth.dart';
import '../../domain/models/report_summary.dart';
import '../../domain/repositories/report_repository.dart';
import 'api/api_report_repository.dart';
import 'sqlite_report_repository.dart';

class OfflineFirstReportRepository implements ReportRepository {
  OfflineFirstReportRepository({
    required ApiReportRepository apiRepo,
    required SqliteReportRepository localRepo,
    required NetworkMonitor networkMonitor,
  })  : _apiRepo = apiRepo,
        _localRepo = localRepo,
        _networkMonitor = networkMonitor;

  final ApiReportRepository _apiRepo;
  final SqliteReportRepository _localRepo;
  final NetworkMonitor _networkMonitor;

  bool get _isOnline => _networkMonitor.isOnline;

  @override
  Future<ReportSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    if (_isOnline) {
      try {
        final summary = await _apiRepo.getSummary(from: from, to: to);
        _networkMonitor.reportSuccess();
        return summary;
      } catch (e) {
        _networkMonitor.reportFailure(e);
        return _localRepo.getSummary(from: from, to: to);
      }
    }
    return _localRepo.getSummary(from: from, to: to);
  }

  @override
  Future<List<MonthlyReport>> getMonthlySummary({required int months}) async {
    if (_isOnline) {
      try {
        final monthly = await _apiRepo.getMonthlySummary(months: months);
        _networkMonitor.reportSuccess();
        return monthly;
      } catch (e) {
        _networkMonitor.reportFailure(e);
        return _localRepo.getMonthlySummary(months: months);
      }
    }
    return _localRepo.getMonthlySummary(months: months);
  }

  @override
  Future<List<CategoryReport>> getCategorySummary({
    required DateTime from,
    required DateTime to,
  }) async {
    if (_isOnline) {
      try {
        final categories = await _apiRepo.getCategorySummary(from: from, to: to);
        _networkMonitor.reportSuccess();
        return categories;
      } catch (e) {
        _networkMonitor.reportFailure(e);
        return _localRepo.getCategorySummary(from: from, to: to);
      }
    }
    return _localRepo.getCategorySummary(from: from, to: to);
  }

  @override
  Future<StockValuation> getStockValuation() async {
    if (_isOnline) {
      try {
        final valuation = await _apiRepo.getStockValuation();
        _networkMonitor.reportSuccess();
        return valuation;
      } catch (e) {
        _networkMonitor.reportFailure(e);
        return _localRepo.getStockValuation();
      }
    }
    return _localRepo.getStockValuation();
  }
}
