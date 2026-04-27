<?php

namespace App\Filament\Resources\SavingGoals;

use App\Filament\Resources\SavingGoals\Pages\ListSavingGoals;
use App\Filament\Resources\SavingGoals\Tables\SavingGoalsTable;
use App\Models\SavingGoal;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class SavingGoalResource extends Resource
{
    protected static ?string $model = SavingGoal::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedFlag;

    protected static ?string $recordTitleAttribute = 'title';

    protected static ?int $navigationSort = 6;

    public static function getNavigationGroup(): ?string
    {
        return __('waffer.navigation_groups.finance');
    }

    public static function getNavigationLabel(): string
    {
        return __('waffer.resources.saving_goal.plural');
    }

    public static function getModelLabel(): string
    {
        return __('waffer.resources.saving_goal.label');
    }

    public static function getPluralModelLabel(): string
    {
        return __('waffer.resources.saving_goal.plural');
    }

    public static function table(Table $table): Table
    {
        return SavingGoalsTable::configure($table);
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
            'index' => ListSavingGoals::route('/'),
        ];
    }
}
