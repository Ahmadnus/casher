/// All API route strings, derived 1-to-1 from routes/api.php.
/// Never write a URL string anywhere else in the project.
class ApiEndpoints {

  // ── Auth ────────────────────────────────────────────────────
  static const String login          = '/auth/login';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword  = '/auth/reset-password';
  static const String logout         = '/auth/logout';
  static const String logoutAll      = '/auth/logout-all';
  static const String me             = '/auth/me';
  static const String changePassword = '/auth/change-password';

  // ── Employees ───────────────────────────────────────────────
  static const String employees    = '/employees';
  static const String employeeRoles = '/employees/roles';
  static String employee(dynamic id)            => '/employees/$id';
  static String toggleEmployeeActive(dynamic id) => '/employees/$id/toggle-active';

  // ── Customers ───────────────────────────────────────────────
  static const String customers      = '/customers';
  static const String customerByPhone = '/customers/find-by-phone';
  static String customer(dynamic id) => '/customers/$id';

  // ── Categories ──────────────────────────────────────────────
  static const String categories       = '/categories';
  static const String activeCategories = '/categories/active';
  static String category(dynamic id)   => '/categories/$id';

  // ── Menu Items ──────────────────────────────────────────────
  static const String menuItems             = '/menu-items';
  static const String availableMenuItems    = '/menu-items/available';
  static String menuItem(dynamic id)        => '/menu-items/$id';
  static String toggleMenuItemAvailability(dynamic id)
                                            => '/menu-items/$id/toggle-availability';

  // ── Delivery Areas ──────────────────────────────────────────
  static const String deliveryAreas        = '/delivery-areas';
  static const String activeDeliveryAreas  = '/delivery-areas/active';
  static String deliveryArea(dynamic id)   => '/delivery-areas/$id';
  static String toggleDeliveryAreaActive(dynamic id)
                                           => '/delivery-areas/$id/toggle-active';

  // ── Orders ──────────────────────────────────────────────────
  static const String orders       = '/orders';
  static const String kitchenBoard = '/orders/kitchen-board';
  static String order(dynamic id)        => '/orders/$id';
  static String orderStatus(dynamic id)  => '/orders/$id/status';

  // ── Invoices ────────────────────────────────────────────────
  static const String invoices = '/invoices';
  static String invoice(dynamic id)          => '/invoices/$id';
  static String invoicePrintData(dynamic id) => '/invoices/$id/print-data';
  static String markInvoicePaid(dynamic id)  => '/invoices/$id/mark-paid';
  static String refundInvoice(dynamic id)    => '/invoices/$id/refund';
  static String cancelInvoice(dynamic id)    => '/invoices/$id/cancel';

  // ── Settings ────────────────────────────────────────────────
  static const String settings = '/settings';

  // ── Printer Settings ────────────────────────────────────────
  static const String printerSettings = '/printer-settings';
  static String printerSetting(dynamic id)   => '/printer-settings/$id';
  static String setDefaultPrinter(dynamic id) => '/printer-settings/$id/set-default';

  // ── Dashboard ───────────────────────────────────────────────
  static const String dashboard = '/dashboard';

  // ── Reports ─────────────────────────────────────────────────
  static const String reportDaily          = '/reports/daily';
  static const String reportWeekly         = '/reports/weekly';
  static const String reportMonthly        = '/reports/monthly';
  static const String reportBestSelling    = '/reports/best-selling-items';
  static const String reportByEmployee     = '/reports/sales-by-employee';
  static const String reportByDeliveryArea = '/reports/sales-by-delivery-area';
  static const String reportByCategory     = '/reports/sales-by-category';

  // ── Notifications ────────────────────────────────────────────
  static const String notifications           = '/notifications';
  static const String markAllNotificationsRead = '/notifications/mark-all-read';
  static String markNotificationRead(String id) => '/notifications/$id/mark-read';
  static String notificationById(String id)     => '/notifications/$id';
}