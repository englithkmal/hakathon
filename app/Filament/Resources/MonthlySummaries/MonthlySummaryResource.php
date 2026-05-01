<?php

namespace App\Filament\Resources\MonthlySummaries;

use App\Filament\Resources\MonthlySummaries\Pages\ListMonthlySummaries;
use App\Filament\Resources\MonthlySummaries\Pages\ViewMonthlySummary;
use App\Filament\Resources\MonthlySummaries\Schemas\MonthlySummaryInfolist;
use App\Filament\Resources\MonthlySummaries\Tables\MonthlySummariesTable;
use App\Models\MonthlySummary;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class MonthlySummaryResource extends Resource
{
    protected static ?string $model = MonthlySummary::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedDocumentChartBar;

    protected static ?string $recordTitleAttribute = 'id';

    protected static ?int $navigationSort = 5;

    public static function getNavigationGroup(): ?string
    {
        return __('waffer.navigation_groups.finance');
    }

    public static function getNavigationLabel(): string
    {
        return __('waffer.resources.monthly_summary.plural');
    }

    public static function getModelLabel(): string
    {
        return __('waffer.resources.monthly_summary.label');
    }

    public static function getPluralModelLabel(): string
    {
        return __('waffer.resources.monthly_summary.plural');
    }

    public static function table(Table $table): Table
    {
        return MonthlySummariesTable::configure($table);
    }

    public static function infolist(Schema $schema): Schema
    {
        return MonthlySummaryInfolist::configure($schema);
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
            'index' => ListMonthlySummaries::route('/'),
            'view' => ViewMonthlySummary::route('/{record}'),
        ];
    }
}
