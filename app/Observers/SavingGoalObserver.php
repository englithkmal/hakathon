<?php

namespace App\Observers;

use App\Models\SavingGoal;
use App\Services\AlertService;

class SavingGoalObserver
{
    public function __construct(protected AlertService $alertService) {}

    public function updated(SavingGoal $goal): void
    {
        if ($goal->wasChanged('current_amount')) {
            $this->alertService->checkSavingGoalProgress($goal);
        }
    }
}
