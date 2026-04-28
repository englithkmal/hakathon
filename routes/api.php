<?php

use App\Http\Controllers\Api\AlertController;
use App\Http\Controllers\Api\Auth\AuthController;
use App\Http\Controllers\Api\BudgetController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\MockBankController;
use App\Http\Controllers\Api\SavingGoalController;
use App\Http\Controllers\Api\TipController;
use App\Http\Controllers\Api\TransactionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('devices/register-guest', [DeviceController::class, 'registerGuest'])
        ->middleware('throttle:60,1');

    // Public auth routes
    Route::prefix('auth')->group(function () {
        Route::post('send-otp', [AuthController::class, 'sendOtp']);
        Route::post('verify-otp', [AuthController::class, 'verifyOtp']);
        Route::post('register', [AuthController::class, 'register']);
        Route::post('firebase', [AuthController::class, 'firebaseLogin']);
    });

    // Protected routes
    Route::middleware('auth:sanctum')->group(function () {
        // Auth
        Route::prefix('auth')->group(function () {
            Route::get('me', [AuthController::class, 'me']);
            Route::put('profile', [AuthController::class, 'updateProfile']);
            Route::post('logout', [AuthController::class, 'logout']);
            Route::post('logout-all', [AuthController::class, 'logoutAll']);
        });

        // Dashboard / Insights
        Route::get('dashboard', [DashboardController::class, 'index']);
        Route::get('insights/expense-analysis', [DashboardController::class, 'expenseAnalysis']);
        Route::get('insights/monthly-report', [DashboardController::class, 'monthlyReport']);

        // Categories
        Route::get('categories', [CategoryController::class, 'index']);

        // Budgets
        Route::get('budgets/current', [BudgetController::class, 'current']);
        Route::apiResource('budgets', BudgetController::class);

        // Transactions
        Route::apiResource('transactions', TransactionController::class);

        // Saving Goals
        Route::post('saving-goals/{savingGoal}/deposit', [SavingGoalController::class, 'deposit']);
        Route::apiResource('saving-goals', SavingGoalController::class);

        // Alerts
        Route::get('alerts', [AlertController::class, 'index']);
        Route::put('alerts/read-all', [AlertController::class, 'markAllAsRead']);
        Route::put('alerts/{alert}/read', [AlertController::class, 'markAsRead']);
        Route::delete('alerts/{alert}', [AlertController::class, 'destroy']);

        // Tips
        Route::get('tips', [TipController::class, 'index']);
        Route::get('tips/{tip}', [TipController::class, 'show']);

        // Mock Bank Data
        Route::post('mock-bank/import', [MockBankController::class, 'import']);
        Route::delete('mock-bank/clear', [MockBankController::class, 'clear']);

        // Devices / Push Notifications (FCM)
        Route::get('devices', [DeviceController::class, 'index']);
        Route::post('devices/register', [DeviceController::class, 'register']);
        Route::post('devices/unregister', [DeviceController::class, 'unregister']);
        Route::post('devices/test-push', [DeviceController::class, 'test']);
    });
});
