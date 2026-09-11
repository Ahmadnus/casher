import 'package:get/get.dart';
import '../models/employee_model.dart';
import '../repositories/auth_repository.dart';
import '../network/network.dart';
import '../core/api_exception.dart';

class AuthController extends GetxController {
  final _repo = AuthRepository();

  final Rx<EmployeeModel?> currentEmployee = Rx<EmployeeModel?>(null);
  final RxString loginError = ''.obs;
  final RxBool isLoading = false.obs;

  /// True only while the app is validating a stored token at cold start.
  /// AuthGate shows a splash during this window so the LoginScreen never
  /// flashes for an already-authenticated user.
  final RxBool isRestoring = false.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = Network.token;
    if (token == null || token.isEmpty) return;
    isRestoring.value = true;
    try {
      final emp = await _repo.getMe();
      if (emp != null) currentEmployee.value = emp;
    } on ApiException catch (e) {
      // Only a genuine auth rejection should drop the stored token. A
      // transient network error at launch (timeout / no connection) must
      // NOT force the user to log in again — keep the token and let them
      // retry once connectivity returns.
      if (e.statusCode == 401) {
        await Network.clearToken();
      }
    } catch (_) {
      // Unknown/parse error — preserve the token, do not force logout.
    } finally {
      isRestoring.value = false;
    }
  }

  Future<bool> login(String username, String password) async {
    loginError.value = '';
    isLoading.value = true;
    try {
      final result = await _repo.loginWithCredentials(
        username: username,
        password: password,
      );
      return _handleLoginResponse(result);
    } on ApiException catch (e) {
      loginError.value = e.displayMessage;
      return false;
    } catch (_) {
      loginError.value = 'خطأ في الاتصال بالخادم';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> loginWithPin(String pin) async {
    loginError.value = '';
    isLoading.value = true;
    try {
      final result = await _repo.loginWithPin(pin: pin);
      return _handleLoginResponse(result);
    } on ApiException catch (e) {
      loginError.value = e.displayMessage;
      return false;
    } catch (_) {
      loginError.value = 'رمز PIN غير صحيح';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _handleLoginResponse(Map<String, dynamic> result) async {
    final data = result['data'] as Map<String, dynamic>?;
    if (data == null) {
      loginError.value = 'استجابة غير متوقعة من الخادم';
      return false;
    }
    final token = data['token'] as String?;
    if (token == null) {
      loginError.value = 'لم يتم استلام التوكن';
      return false;
    }
    await Network.saveToken(token);
    final userJson = data['user'] as Map<String, dynamic>?;
    if (userJson != null) {
      currentEmployee.value = EmployeeModel.fromJson(userJson);
    }
    return true;
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {}
    await Network.clearToken();
    currentEmployee.value = null;
  }

  // ── Role helpers ───────────────────────────────────────────
  bool get isAdmin =>
      currentEmployee.value?.role == 'admin' ||
      currentEmployee.value?.role == 'super_admin';
  bool get isManager  => currentEmployee.value?.role == 'manager';
  bool get isCashier  => currentEmployee.value?.role == 'cashier';
  bool get isWaiter   => currentEmployee.value?.role == 'waiter';

  bool get canManageMenu          => isAdmin || isManager;
  bool get canManageDeliveryAreas => isAdmin || isManager;
  bool get canViewReports         => isAdmin || isManager;
  bool get canManageEmployees     => isAdmin;
  bool get canPrint               => true;

  /// Cashier/manager/admin see the live "pending orders" queue — the
  /// same set of roles InvoiceController polls unpaid invoices for.
  bool get canSeePendingOrders => isAdmin || isManager || isCashier;
}
