<?php

namespace App\Filament\Resources\Budgets;

use App\Filament\Resources\Budgets\Pages\ListBudgets;
use App\Filament\Resources\Budgets\Tables\BudgetsTable;
use App\Models\Budget;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class BudgetResource extends Resource
{
    protected static ?string $model = Budget::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedChartPie;

    protected static ?string $recordTitleAttribute = 'id';

    protected static ?int $navigationSort = 4;

    public static function getNavigationGroup(): ?string
    {
        return __('waffer.navigation_groups.finance');
    }

    public static function getNavigationLabel(): string
    {
        return __('waffer.resources.budget.plural');
    }

    public static function getModelLabel(): string
    {
        return __('waffer.resources.budget.label');
    }

    public static function getPluralModelLabel(): string
    {
        return __('waffer.resources.budget.plural');
    }

    public static function table(Table $table): Table
    {
        return BudgetsTable::configure($table);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListBudgets::route('/'),
        ];
    }
}
