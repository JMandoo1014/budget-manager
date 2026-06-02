class AppCategories {
  AppCategories._();

  static const expenseList = <(String, String)>[
    ('🍚', '식비'),
    ('🍺', '술'),
    ('🚌', '교통'),
    ('☕', '카페'),
    ('🛍', '쇼핑'),
    ('📦', '기타'),
  ];

  static const incomeList = <(String, String)>[
    ('💼', '알바'),
    ('💰', '용돈'),
    ('💵', '기타수입'),
  ];

  static const incomeNames = ['알바', '용돈', '기타수입'];
  static const warningCategories = {'술', '카페'};
}
