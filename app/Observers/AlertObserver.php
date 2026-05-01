<?php

namespace App\Observers;

use App\Models\Alert;
use App\Services\FcmService;
use Illuminate\Support\Facades\Log;
use Throwable;

class AlertObserver
{
    public function __construct(protected FcmService $fcm) {}

    /**
     * Push the alert to the user's devices the moment it is persisted.
     * Failures here are non-fatal: logging only — we never break the alert flow.
     */
    public function created(Alert $alert): void
    {
        try {
            $alert->loadMissing('user');

            if (! $alert->user || ! $alert->user->is_active) {
                return;
            }

            $stats = $this->fcm->sendForAlert($alert);
            if (($stats['sent'] ?? 0) === 0 && ($stats['failed'] ?? 0) === 0) {
                Log::info('Alert created but no FCM delivery (no active device tokens for user).', [
                    'alert_id' => $alert->id,
                    'user_id' => $alert->user_id,
                ]);
            }
        } catch (Throwable $e) {
            Log::warning('AlertObserver failed to dispatch push notification.', [
                'alert_id' => $alert->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
