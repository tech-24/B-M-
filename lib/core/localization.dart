import 'package:flutter/material.dart';

/// Lightweight in-app localization (Arabic / English).
class L10n {
  final Locale locale;
  L10n(this.locale);

  static L10n of(BuildContext context) =>
      Localizations.of<L10n>(context, L10n)!;

  static const supported = [Locale('ar'), Locale('en')];

  bool get isAr => locale.languageCode == 'ar';

  static const _s = <String, Map<String, String>>{
    'appTitle': {'ar': 'مدير الأعمال', 'en': 'Business Manager'},
    'projects': {'ar': 'المشاريع', 'en': 'Projects'},
    'addProject': {'ar': 'إضافة مشروع', 'en': 'Add Project'},
    'editProject': {'ar': 'تعديل المشروع', 'en': 'Edit Project'},
    'deleteProject': {'ar': 'حذف المشروع', 'en': 'Delete Project'},
    'deleteProjectConfirm': {
      'ar': 'سيتم حذف المشروع وجميع بياناته نهائياً. هل أنت متأكد؟',
      'en': 'The project and all its data will be permanently deleted. Are you sure?'
    },
    'projectName': {'ar': 'اسم المشروع', 'en': 'Project name'},
    'description': {'ar': 'الوصف', 'en': 'Description'},
    'noProjects': {
      'ar': 'لا توجد مشاريع بعد. أضف مشروعك الأول للبدء.',
      'en': 'No projects yet. Add your first project to get started.'
    },
    'monthSales': {'ar': 'مبيعات الشهر', 'en': 'Month sales'},
    'monthProfit': {'ar': 'ربح الشهر', 'en': 'Month profit'},
    'dashboard': {'ar': 'الرئيسية', 'en': 'Dashboard'},
    'dailyRecords': {'ar': 'السجلات اليومية', 'en': 'Daily Records'},
    'inventory': {'ar': 'المخزون', 'en': 'Inventory'},
    'expenses': {'ar': 'المصاريف', 'en': 'Expenses'},
    'reports': {'ar': 'التقارير', 'en': 'Reports'},
    'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
    'revenue': {'ar': 'الإيرادات', 'en': 'Revenue'},
    'totalExpenses': {'ar': 'إجمالي المصاريف', 'en': 'Total expenses'},
    'netProfit': {'ar': 'صافي الربح', 'en': 'Net profit'},
    'currentUnitCost': {'ar': 'تكلفة الوحدة الحالية', 'en': 'Current unit cost'},
    'inventoryStatus': {'ar': 'حالة المخزون', 'en': 'Inventory status'},
    'items': {'ar': 'صنف', 'en': 'items'},
    'recentRecords': {'ar': 'آخر السجلات اليومية', 'en': 'Recent daily records'},
    'quickActions': {'ar': 'إجراءات سريعة', 'en': 'Quick actions'},
    'addDailyRecord': {'ar': 'سجل يومي', 'en': 'Daily record'},
    'addExpense': {'ar': 'إضافة مصروف', 'en': 'Add expense'},
    'addInventoryItem': {'ar': 'إضافة صنف', 'en': 'Add item'},
    'viewReports': {'ar': 'عرض التقارير', 'en': 'View reports'},
    'operatingCost': {'ar': 'تكلفة التشغيل', 'en': 'Operating Cost'},
    'costHistory': {'ar': 'سجل التكاليف الشهرية', 'en': 'Monthly cost history'},
    'costPerUnit': {'ar': 'تكلفة الوحدة', 'en': 'Cost per unit'},
    'addCostItem': {'ar': 'إضافة صنف تكلفة', 'en': 'Add cost item'},
    'noCostItems': {
      'ar': 'لا توجد أصناف تكلفة بعد. أضف صنفك الأول (مثلاً: آيسكريم فانيلا).',
      'en': 'No cost items yet. Add your first one (e.g. vanilla ice cream).'
    },
    'currentCost': {'ar': 'التكلفة الحالية', 'en': 'Current cost'},
    'noCostSet': {'ar': 'لم تُحدد تكلفة بعد', 'en': 'No cost set yet'},
    'deleteCostItem': {'ar': 'حذف الصنف', 'en': 'Delete item'},
    'deleteCostItemConfirm': {
      'ar': 'سيتم حذف الصنف وكل أسعاره واستهلاكه المسجل نهائياً. هل أنت متأكد؟',
      'en': 'The item and all its prices and recorded usage will be permanently deleted. Are you sure?'
    },
    'costItemsHint': {
      'ar': 'أضف الأصناف التي تريد تتبع تكلفتها (مثل أنواع الآيسكريم)، ثم حدد تكلفة كل صنف لكل شهر. باليوميات تختار الصنف وتكتب الكمية المستهلكة.',
      'en': 'Add the items you want to track cost for, then set each one\'s monthly cost. In daily records, pick the item and enter the quantity used.'
    },
    'itemCostHint': {
      'ar': 'حدد تكلفة هذا الصنف لكل شهر، وسيتم استخدامها تلقائياً عند تسجيل استهلاكه باليوميات.',
      'en': 'Set this item\'s cost for each month; it is applied automatically to its daily usage.'
    },
    'selectItem': {'ar': 'اختر الصنف', 'en': 'Select item'},
    'addUsage': {'ar': 'إضافة استهلاك', 'en': 'Add usage'},
    'editUsage': {'ar': 'تعديل الاستهلاك', 'en': 'Edit usage'},
    'noUsage': {'ar': 'لا يوجد استهلاك مسجل لهذا اليوم.', 'en': 'No usage recorded for this day.'},
    'noItemsTitle': {'ar': 'لا توجد أصناف تكلفة', 'en': 'No cost items'},
    'noItemsHint': {
      'ar': 'لم تُضف أي صنف تكلفة بعد. أضف صنفاً من شاشة إعدادات التكلفة أولاً.',
      'en': 'You haven\'t added any cost items yet. Add one from Cost Settings first.'
    },
    'allItemsUsed': {
      'ar': 'كل الأصناف مسجلة بالفعل لهذا اليوم. عدّل الكمية من القائمة.',
      'en': 'All items are already recorded for this day. Edit the quantity from the list.'
    },
    'month': {'ar': 'الشهر', 'en': 'Month'},
    'save': {'ar': 'حفظ', 'en': 'Save'},
    'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
    'delete': {'ar': 'حذف', 'en': 'Delete'},
    'edit': {'ar': 'تعديل', 'en': 'Edit'},
    'add': {'ar': 'إضافة', 'en': 'Add'},
    'date': {'ar': 'التاريخ', 'en': 'Date'},
    'sales': {'ar': 'المبيعات', 'en': 'Sales'},
    'salesAmount': {'ar': 'مبلغ المبيعات', 'en': 'Sales amount'},
    'usage': {'ar': 'الاستخدام', 'en': 'Usage'},
    'usedQuantity': {'ar': 'الكمية المستخدمة', 'en': 'Quantity used'},
    'productCost': {'ar': 'تكلفة المنتج', 'en': 'Product cost'},
    'dailyExpenses': {'ar': 'المصاريف اليومية', 'en': 'Daily expenses'},
    'fixedExpenses': {'ar': 'المصاريف الثابتة', 'en': 'Fixed expenses'},
    'dailyResult': {'ar': 'نتيجة اليوم', 'en': 'Daily result'},
    'dailyProfit': {'ar': 'ربح اليوم', 'en': 'Daily profit'},
    'category': {'ar': 'التصنيف', 'en': 'Category'},
    'amount': {'ar': 'المبلغ', 'en': 'Amount'},
    'notes': {'ar': 'ملاحظات', 'en': 'Notes'},
    'expenseName': {'ar': 'اسم المصروف', 'en': 'Expense name'},
    'monthlyAmount': {'ar': 'المبلغ الشهري', 'en': 'Monthly amount'},
    'startMonth': {'ar': 'يبدأ من شهر', 'en': 'Starts from'},
    'itemName': {'ar': 'اسم الصنف', 'en': 'Item name'},
    'unitType': {'ar': 'نوع الوحدة', 'en': 'Unit type'},
    'purchaseQuantity': {'ar': 'كمية الشراء', 'en': 'Purchase quantity'},
    'purchasePrice': {'ar': 'سعر الشراء (إجمالي)', 'en': 'Purchase price (total)'},
    'currentStock': {'ar': 'المخزون الحالي', 'en': 'Current stock'},
    'used': {'ar': 'المستخدم', 'en': 'Used'},
    'remaining': {'ar': 'المتبقي', 'en': 'Remaining'},
    'recordUsage': {'ar': 'تسجيل استخدام', 'en': 'Record usage'},
    'consumedCost': {'ar': 'تكلفة الاستهلاك', 'en': 'Consumed cost'},
    'totalRevenue': {'ar': 'إجمالي الإيرادات', 'en': 'Total revenue'},
    'totalCosts': {'ar': 'إجمالي التكاليف', 'en': 'Total costs'},
    'inventoryConsumption': {'ar': 'استهلاك المخزون', 'en': 'Inventory consumption'},
    'profitPercent': {'ar': 'نسبة الربح', 'en': 'Profit margin'},
    'monthlyReport': {'ar': 'التقرير الشهري', 'en': 'Monthly report'},
    'yearlyOverview': {'ar': 'نظرة سنوية', 'en': 'Yearly overview'},
    'profit': {'ar': 'الربح', 'en': 'Profit'},
    'language': {'ar': 'اللغة', 'en': 'Language'},
    'theme': {'ar': 'المظهر', 'en': 'Theme'},
    'light': {'ar': 'فاتح', 'en': 'Light'},
    'dark': {'ar': 'داكن', 'en': 'Dark'},
    'system': {'ar': 'النظام', 'en': 'System'},
    'about': {'ar': 'عن التطبيق', 'en': 'About'},
    'aboutBody': {
      'ar': 'مدير الأعمال — تطبيق لإدارة مشاريع متعددة: مبيعات، مصاريف، مخزون وتقارير شهرية. البيانات محفوظة محلياً على جهازك.',
      'en': 'Business Manager — manage multiple projects: sales, expenses, inventory and monthly reports. Data is stored locally on your device.'
    },
    'noData': {'ar': 'لا توجد بيانات', 'en': 'No data'},
    'noRecords': {
      'ar': 'لا توجد سجلات لهذا الشهر. اضغط + لإضافة يوم جديد.',
      'en': 'No records for this month. Tap + to add a new day.'
    },
    'noExpenses': {'ar': 'لا توجد مصاريف مسجلة.', 'en': 'No expenses recorded.'},
    'noInventory': {'ar': 'لا توجد أصناف في المخزون.', 'en': 'No inventory items.'},
    'required': {'ar': 'هذا الحقل مطلوب', 'en': 'This field is required'},
    'invalidNumber': {'ar': 'أدخل رقماً صحيحاً', 'en': 'Enter a valid number'},
    'sar': {'ar': 'ر.س', 'en': 'SAR'},
    'selectDate': {'ar': 'اختيار التاريخ', 'en': 'Select date'},
    'total': {'ar': 'الإجمالي', 'en': 'Total'},
    'daily': {'ar': 'يومي', 'en': 'Daily'},
    'fixed': {'ar': 'ثابت', 'en': 'Fixed'},
    'quantity': {'ar': 'الكمية', 'en': 'Quantity'},
    'lowStock': {'ar': 'مخزون منخفض', 'en': 'Low stock'},
    'setCostHint': {
      'ar': 'حدد تكلفة الوحدة لكل شهر، وسيتم استخدامها تلقائياً في حساب تكلفة الاستخدام اليومي.',
      'en': 'Set the unit cost for each month; it is applied automatically to daily usage cost.'
    },
    'openDay': {'ar': 'فتح اليوم', 'en': 'Open day'},
    'deleteDay': {'ar': 'حذف اليوم', 'en': 'Delete day'},
    'deleteDayConfirm': {
      'ar': 'سيتم حذف كل بيانات هذا اليوم نهائياً (المبيعات، الاستهلاك، والمصاريف). لا يمكن التراجع عن هذا الإجراء. متابعة؟',
      'en': 'All data for this day (sales, usage, and expenses) will be permanently deleted. This cannot be undone. Continue?'
    },
    'today': {'ar': 'اليوم', 'en': 'Today'},
    'backupTitle': {'ar': 'النسخ الاحتياطي على Google Drive', 'en': 'Google Drive backup'},
    'backupSubtitle': {
      'ar': 'اختياري بالكامل — نسخة من بياناتك تُحفظ بشكل خاص في حسابك على Google Drive، ما أحد يشوفها إلا التطبيق.',
      'en': 'Fully optional — a copy of your data is stored privately in your own Google Drive, visible only to this app.'
    },
    'signInWithGoogle': {'ar': 'تسجيل الدخول بحساب Google', 'en': 'Sign in with Google'},
    'signOut': {'ar': 'تسجيل الخروج', 'en': 'Sign out'},
    'signOutConfirm': {'ar': 'هل تبي تسجّل خروج من حسابك؟', 'en': 'Sign out of your account?'},
    'account': {'ar': 'الحساب', 'en': 'Account'},
    'email': {'ar': 'البريد الإلكتروني', 'en': 'Email'},
    'password': {'ar': 'كلمة المرور', 'en': 'Password'},
    'invalidEmail': {'ar': 'أدخل بريدًا إلكترونيًا صحيحًا', 'en': 'Enter a valid email'},
    'passwordTooShort': {'ar': 'كلمة المرور ٦ أحرف على الأقل', 'en': 'Password must be at least 6 characters'},
    'signIn': {'ar': 'تسجيل الدخول', 'en': 'Sign in'},
    'createAccount': {'ar': 'إنشاء حساب', 'en': 'Create account'},
    'signInSubtitle': {'ar': 'سجّل دخولك عشان توصل لبياناتك', 'en': 'Sign in to access your data'},
    'createAccountSubtitle': {'ar': 'أنشئ حساب جديد للبدء', 'en': 'Create a new account to get started'},
    'haveAccountSignIn': {'ar': 'عندك حساب؟ سجّل الدخول', 'en': 'Already have an account? Sign in'},
    'noAccountSignUp': {'ar': 'ما عندك حساب؟ أنشئ واحد', 'en': "Don't have an account? Sign up"},
    'signUpCheckEmailOrDone': {
      'ar': 'تم إنشاء الحساب. إذا طُلب منك تفعيل عبر البريد الإلكتروني، تحقق من صندوق الوارد.',
      'en': 'Account created. If email confirmation is required, check your inbox.'
    },
    'backupNow': {'ar': 'نسخ احتياطي الآن', 'en': 'Backup now'},
    'autoBackupDaily': {'ar': 'نسخ احتياطي تلقائي يومي', 'en': 'Automatic daily backup'},
    'lastBackup': {'ar': 'آخر نسخة احتياطية', 'en': 'Last backup'},
    'neverBackedUp': {'ar': 'لم تُؤخذ أي نسخة بعد', 'en': 'No backup yet'},
    'restoreLatest': {'ar': 'استعادة آخر نسخة', 'en': 'Restore latest backup'},
    'restoreConfirmTitle': {'ar': 'استعادة النسخة الاحتياطية', 'en': 'Restore backup'},
    'restoreConfirmBody': {
      'ar': 'سيتم استبدال كل بياناتك الحالية بآخر نسخة محفوظة على Google Drive. هذا الإجراء لا يمكن التراجع عنه. متابعة؟',
      'en': 'All current data will be replaced with the latest backup from Google Drive. This cannot be undone. Continue?'
    },
    'backupSuccess': {'ar': 'تم أخذ نسخة احتياطية بنجاح', 'en': 'Backup completed successfully'},
    'backupFailed': {'ar': 'تعذّر أخذ نسخة احتياطية', 'en': 'Backup failed'},
    'restoreSuccess': {
      'ar': 'تمت الاستعادة بنجاح. أعد فتح التطبيق لرؤية بياناتك.',
      'en': 'Restore complete. Please reopen the app to see your data.'
    },
    'restoreFailed': {'ar': 'تعذّرت الاستعادة (تأكد من وجود نسخة محفوظة)', 'en': 'Restore failed (make sure a backup exists)'},
    'signedInAs': {'ar': 'مسجّل الدخول بـ', 'en': 'Signed in as'},

    // Printable period summary
    'printSummary': {'ar': 'طباعة ملخص', 'en': 'Print summary'},
    'selectPeriod': {'ar': 'اختر الفترة', 'en': 'Select period'},
    'oneMonth': {'ar': 'شهر', 'en': '1 month'},
    'threeMonths': {'ar': '٣ أشهر', 'en': '3 months'},
    'sixMonths': {'ar': '٦ أشهر', 'en': '6 months'},
    'nineMonths': {'ar': '٩ أشهر', 'en': '9 months'},
    'oneYear': {'ar': 'سنة', 'en': '1 year'},
    'customRange': {'ar': 'تحديد يدوي', 'en': 'Custom range'},
    'fromDate': {'ar': 'من تاريخ', 'en': 'From'},
    'toDate': {'ar': 'إلى تاريخ', 'en': 'To'},
    'chooseDateRange': {'ar': 'اختر الفترة الزمنية', 'en': 'Choose date range'},
    'generateReport': {'ar': 'إنشاء التقرير', 'en': 'Generate report'},
    'reportPeriod': {'ar': 'فترة التقرير', 'en': 'Report period'},
    'generatedOn': {'ar': 'تاريخ الإنشاء', 'en': 'Generated on'},
    'summaryReport': {'ar': 'ملخص تقرير', 'en': 'Summary report'},
    'preparingReport': {'ar': 'جارٍ تجهيز التقرير...', 'en': 'Preparing report...'},

    // Project logo
    'projectLogo': {'ar': 'شعار المشروع', 'en': 'Project logo'},
    'changeLogo': {'ar': 'تغيير الشعار', 'en': 'Change logo'},
    'addLogo': {'ar': 'إضافة شعار', 'en': 'Add logo'},
    'removeLogo': {'ar': 'إزالة الشعار', 'en': 'Remove logo'},
    'logoUpdated': {'ar': 'تم تحديث الشعار', 'en': 'Logo updated'},
    'logoUploadFailed': {'ar': 'تعذّر رفع الشعار', 'en': 'Failed to upload logo'},
    'deleteProjectTypeNameHint': {
      'ar': 'للتأكيد، اكتب اسم المشروع بالضبط:',
      'en': 'To confirm, type the project name exactly:'
    },
    'nameDoesNotMatch': {
      'ar': 'الاسم غير مطابق',
      'en': 'Name does not match'
    },
  };

  String t(String key) => _s[key]?[locale.languageCode] ?? key;
}

class L10nDelegate extends LocalizationsDelegate<L10n> {
  const L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      L10n.supported.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(L10nDelegate old) => false;
}
