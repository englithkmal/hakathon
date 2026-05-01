<?php

namespace App\Providers;

use App\Models\Alert;
use App\Models\Budget;
use App\Models\BudgetCategory;
use App\Models\SavingGoal;
use App\Models\Tip;
use App\Models\Transaction;
use App\Observers\AlertObserver;
use App\Observers\BudgetCategoryObserver;
use App\Observers\BudgetObserver;
use App\Observers\SavingGoalObserver;
use App\Observers\TipObserver;
use App\Observers\TransactionObserver;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        Transaction::observe(TransactionObserver::class);
        Budget::observe(BudgetObserver::class);
        BudgetCategory::observe(BudgetCategoryObserver::class);
        SavingGoal::observe(SavingGoalObserver::class);
        Alert::observe(AlertObserver::class);
        Tip::observe(TipObserver::class);
    }
}
