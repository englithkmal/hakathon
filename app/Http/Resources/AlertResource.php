<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AlertResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $locale = app()->getLocale();

        $title = $locale === 'ar' ? ($this->title_ar ?? '') : ($this->title_en ?? '');
        $message = $locale === 'ar' ? ($this->message_ar ?? '') : ($this->message_en ?? '');

        $base = [
            'id' => $this->id,
            'type' => $this->type,
            'severity' => $this->severity,
            'title' => $title,
            'message' => $message,
            'payload' => $this->payload ?? [],
            'is_read' => (bool) $this->is_read,
            'read_at' => $this->read_at?->toIso8601String() ?? '',
            'created_at' => $this->created_at?->toIso8601String(),
        ];

        if ($locale === 'ar') {
            $base['title_ar'] = $this->title_ar ?? '';
            $base['message_ar'] = $this->message_ar ?? '';
        } else {
            $base['title_ar'] = $this->title_ar ?? '';
            $base['title_en'] = $this->title_en ?? '';
            $base['message_ar'] = $this->message_ar ?? '';
            $base['message_en'] = $this->message_en ?? '';
        }

        return $base;
    }
}
