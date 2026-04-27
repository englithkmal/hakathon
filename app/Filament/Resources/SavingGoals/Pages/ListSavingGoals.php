<?php

namespace App\Filament\Resources\SavingGoals\Pages;

use App\Filament\Resources\SavingGoals\SavingGoalResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListSavingGoals extends ListRecords
{
    protected static string $resource = SavingGoalResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }
}
