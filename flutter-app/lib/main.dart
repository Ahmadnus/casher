import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/app_theme.dart';
import 'network/network.dart';
import 'storage/hive_storage.dart';
import 'controllers/menu_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/cart_controller.dart';
import 'controllers/invoice_controller.dart';
import 'controllers/reports_controller.dart';
import 'controllers/delivery_area_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/employee_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/notification_controller.dart';
import 'services/printer_service.dart';
import 'views/screens/home_screen.dart';
import 'views/screens/itemized_sales_screen.dart';
import 'views/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);

  // 1. Init Hive first (token is stored here, Network reads it)
  await HiveStorage.init();

  // 2. Init Dio singleton — must be after Hive so the auth
  //    interceptor can read the stored token immediately.
  Network.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'كاشير المطعم',
      theme: AppTheme.theme,
      locale: const Locale('ar', 'SA'),
      textDirection: TextDirection.rtl,
      debugShowCheckedModeBanner: false,
      initialBinding: BindingsBuilder(() {
        // No ApiService registration — Network is a static class.
        Get.put(AuthController());
        Get.put(EmployeeController());
        Get.put(MenuItemController());
        Get.put(CategoryController());
        Get.put(CartController());
        Get.put(InvoiceController());
        Get.put(ReportsController());
        Get.put(DeliveryAreaController());
        Get.put(DashboardController());
        Get.put(SettingsController());
        Get.put(NotificationController());
        Get.put(PrinterService());
      }),
      home: const AuthGate(),
      // Standalone named routes (deep-linkable full pages).
      getPages: [
        GetPage(
            name: ItemizedSalesScreen.route,
            page: () => const ItemizedSalesScreen()),
      ],
    );
  }
}

/// Reactively switches between LoginScreen and HomeScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final auth = Get.find<AuthController>();
      // Show a splash while a stored token is being validated so the
      // LoginScreen never flashes for an already-signed-in user.
      if (auth.isRestoring.value && auth.currentEmployee.value == null) {
        return const Scaffold(
          backgroundColor: AppTheme.primary,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
        );
      }
      return auth.currentEmployee.value == null
          ? const LoginScreen()
          : const HomeScreen();
    });
  }
}