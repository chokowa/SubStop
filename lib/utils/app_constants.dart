class AppConstants {
  static const allFilter = 'すべて';
  static const uncategorized = '未分類';

  static const categoryEntertainment = 'エンタメ';
  static const categoryProductivity = '仕事・学習';
  static const categoryLifestyle = '生活インフラ';
  static const categoryBooks = '本・学習';
  static const categoryFinance = '金融・家計';
  static const categoryOther = 'その他';

  static const categories = <String>[
    uncategorized,
    categoryEntertainment,
    categoryProductivity,
    categoryLifestyle,
    categoryBooks,
    categoryFinance,
    categoryOther,
  ];

  static const filterableCategories = <String>[
    allFilter,
    ...categories,
  ];

  static String normalizeCategory(String? value) {
    if (value == null || value.trim().isEmpty) return uncategorized;

    switch (value.trim()) {
      case uncategorized:
      case '譛ｪ蛻・｡・':
        return uncategorized;
      case categoryEntertainment:
      case '繧ｨ繝ｳ繧ｿ繝｡':
        return categoryEntertainment;
      case categoryProductivity:
      case '莉穂ｺ九・蟄ｦ鄙・':
        return categoryProductivity;
      case categoryLifestyle:
      case '逕滓ｴｻ繧､繝ｳ繝輔Λ':
        return categoryLifestyle;
      case categoryBooks:
      case '莉穂ｺ九・蟄ｦ鄙�':
        return categoryBooks;
      case categoryFinance:
      case '驥題檮繝ｻ菫晞匱':
        return categoryFinance;
      case categoryOther:
      case '縺昴・莉・':
        return categoryOther;
      default:
        return value.trim();
    }
  }
}
