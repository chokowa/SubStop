import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/app_icons.dart';

class ServicePresetPickerScreen extends StatefulWidget {
  const ServicePresetPickerScreen({super.key});

  @override
  State<ServicePresetPickerScreen> createState() =>
      _ServicePresetPickerScreenState();
}

class _ServicePresetPickerScreenState extends State<ServicePresetPickerScreen> {
  String _searchQuery = '';
  String _selectedCategory = AppConstants.allFilter;

  @override
  Widget build(BuildContext context) {
    final filteredPresets = AppIcons.presets.where((preset) {
      final matchesSearch = preset.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      final matchesCategory = _selectedCategory == AppConstants.allFilter ||
          preset.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text(
          'サービスを選択',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightTextMain,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'サービス名で検索...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: AppConstants.filterableCategories.length,
              itemBuilder: (context, index) {
                final category = AppConstants.filterableCategories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: ChoiceChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSub(context),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = category),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.card(context),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredPresets.isEmpty
                ? const Center(child: Text('該当するサービスがありません'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: filteredPresets.length,
                    itemBuilder: (context, index) {
                      final preset = filteredPresets[index];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, preset),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Color(preset.color)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: () {
                                  if (preset.id.startsWith('http')) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Image.network(
                                        preset.id,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          preset.icon,
                                          color: Color(preset.color),
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  }

                                  return Icon(
                                    preset.icon,
                                    color: Color(preset.color),
                                    size: 24,
                                  );
                                }(),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  preset.name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
