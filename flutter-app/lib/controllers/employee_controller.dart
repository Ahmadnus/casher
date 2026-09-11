import 'package:get/get.dart';
import '../models/employee_model.dart';
import '../repositories/employee_repository.dart';
import '../core/api_exception.dart';

class EmployeeController extends GetxController {
  final _repo = EmployeeRepository();

  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;
  final RxList<String> availableRoles = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
    loadRoles();
  }

  Future<void> loadEmployees() async {
    isLoading.value = true;
    error.value = '';
    try {
      final page = await _repo.getEmployees(perPage: 100);
      employees.value = page.items;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    } catch (_) {
      error.value = 'فشل تحميل الموظفين';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadRoles() async {
    try {
      final roles = await _repo.getRoles();
      availableRoles.value = roles;
    } catch (_) {
      availableRoles.value = ['admin', 'manager', 'cashier', 'kitchen', 'delivery'];
    }
  }

  bool usernameExists(String username, {String? excludeId}) {
    return employees.any((e) =>
        e.username.toLowerCase() == username.trim().toLowerCase() &&
        e.id != excludeId);
  }

  Future<String?> addEmployee({
    required String username,
    required String password,
    required String name,
    required String role,
    String? pin,
    String? email,
    String? phone,
  }) async {
    try {
      final emp = await _repo.createEmployee({
        'name': name,
        'username': username,
        'email': email ?? '${username.replaceAll(RegExp(r"\s+"), ".")}@restaurant.local',
        'password': password,
        'password_confirmation': password,
        'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
        'is_active': true,
      });
      employees.add(emp);
      return null; // null = success
    } on ApiException catch (e) {
      return e.displayMessage;
    } catch (_) {
      return 'فشل إضافة الموظف';
    }
  }

  Future<String?> updateEmployee(EmployeeModel emp, Map<String, dynamic> data) async {
    try {
      final updated = await _repo.updateEmployee(emp.id, data);
      final idx = employees.indexWhere((e) => e.id == emp.id);
      if (idx >= 0) employees[idx] = updated;
      return null;
    } on ApiException catch (e) {
      return e.displayMessage;
    }
  }

  Future<void> toggleActive(String id) async {
    try {
      final updated = await _repo.toggleActive(id);
      final idx = employees.indexWhere((e) => e.id == id);
      if (idx >= 0) employees[idx] = updated;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
    }
  }

  Future<bool> deleteEmployee(String id) async {
    try {
      await _repo.deleteEmployee(id);
      employees.removeWhere((e) => e.id == id);
      return true;
    } on ApiException catch (e) {
      error.value = e.displayMessage;
      return false;
    }
  }
}