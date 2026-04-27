<?php

namespace App\Filament\Resources\Tips;

use App\Filament\Resources\Tips\Pages\CreateTip;
use App\Filament\Resources\Tips\Pages\EditTip;
use App\Filament\Resources\Tips\Pages\ListTips;
use App\Filament\Resources\Tips\Schemas\TipForm;
use App\Filament\Resources\Tips\Tables\TipsTable;
use App\Models\Tip;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;

class TipResource extends Resource
{
    protected static ?string $model = Tip::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedLightBulb;

    protected static ?string $recordTitleAttribute = 'title_ar';

    protected static ?int $navigationSort = 3;

    public static function getNavigationGroup(): ?string
    {
        return __('waffer.navigation_groups.content');
    }

    public static function getNavigationLabel(): string
    {
        return __('waffer.resources.tip.plural');
    }

    public static function getModelLabel(): string
    {
        return __('waffer.resources.tip.label');
    }

    public static function getPluralModelLabel(): string
    {
        return __('waffer.resources.tip.plural');
    }

    public static function form(Schema $schema): Schema
    {
        return TipForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return TipsTable::configure($table);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListTips::route('/'),
            'create' => CreateTip::route('/create'),
            'edit' => EditTip::route('/{record}/edit'),
        ];
    }
}
