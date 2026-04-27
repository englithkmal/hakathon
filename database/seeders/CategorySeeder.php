<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            ['name_ar' => 'طعام وشراب', 'name_en' => 'Food & Drinks', 'slug' => 'food', 'icon' => 'heroicon-o-cake', 'color' => '#F97316', 'type' => 'expense', 'sort_order' => 1],
            ['name_ar' => 'مواصلات', 'name_en' => 'Transportation', 'slug' => 'transport', 'icon' => 'heroicon-o-truck', 'color' => '#3B82F6', 'type' => 'expense', 'sort_order' => 2],
            ['name_ar' => 'فواتير', 'name_en' => 'Bills & Utilities', 'slug' => 'bills', 'icon' => 'heroicon-o-document-text', 'color' => '#EF4444', 'type' => 'expense', 'sort_order' => 3],
            ['name_ar' => 'ترفيه', 'name_en' => 'Entertainment', 'slug' => 'entertainment', 'icon' => 'heroicon-o-film', 'color' => '#A855F7', 'type' => 'expense', 'sort_order' => 4],
            ['name_ar' => 'تسوّق', 'name_en' => 'Shopping', 'slug' => 'shopping', 'icon' => 'heroicon-o-shopping-bag', 'color' => '#EC4899', 'type' => 'expense', 'sort_order' => 5],
            ['name_ar' => 'صحة', 'name_en' => 'Health', 'slug' => 'health', 'icon' => 'heroicon-o-heart', 'color' => '#14B8A6', 'type' => 'expense', 'sort_order' => 6],
            ['name_ar' => 'تعليم', 'name_en' => 'Education', 'slug' => 'education', 'icon' => 'heroicon-o-academic-cap', 'color' => '#6366F1', 'type' => 'expense', 'sort_order' => 7],
            ['name_ar' => 'سكن', 'name_en' => 'Housing', 'slug' => 'housing', 'icon' => 'heroicon-o-home', 'color' => '#78350F', 'type' => 'expense', 'sort_order' => 8],
            ['name_ar' => 'أخرى', 'name_en' => 'Other', 'slug' => 'other', 'icon' => 'heroicon-o-ellipsis-horizontal-circle', 'color' => '#6B7280', 'type' => 'expense', 'sort_order' => 9],
            ['name_ar' => 'ادخار', 'name_en' => 'Savings', 'slug' => 'savings', 'icon' => 'heroicon-o-banknotes', 'color' => '#10B981', 'type' => 'saving', 'sort_order' => 10],
            ['name_ar' => 'راتب', 'name_en' => 'Salary', 'slug' => 'salary', 'icon' => 'heroicon-o-currency-dollar', 'color' => '#22C55E', 'type' => 'income', 'sort_order' => 11],
            ['name_ar' => 'دخل إضافي', 'name_en' => 'Extra Income', 'slug' => 'extra-income', 'icon' => 'heroicon-o-sparkles', 'color' => '#84CC16', 'type' => 'income', 'sort_order' => 12],
        ];

        foreach ($categories as $category) {
            Category::updateOrCreate(
                ['slug' => $category['slug'], 'user_id' => null],
                array_merge($category, ['is_default' => true, 'is_active' => true])
            );
        }
    }
}
