<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $locale = app()->getLocale();

        $name = $locale === 'ar' ? ($this->name_ar ?? '') : ($this->name_en ?? '');

        $base = [
            'id' => $this->id,
            'name' => $name,
            'slug' => $this->slug ?? '',
            'icon' => $this->icon ?? '',
            'color' => $this->color ?? '#94A3B8',
            'type' => $this->type ?? 'expense',
            'is_default' => (bool) $this->is_default,
            'sort_order' => $this->sort_order,
        ];

        if ($locale === 'ar') {
            $base['name_ar'] = $this->name_ar ?? '';
        } else {
            $base['name_ar'] = $this->name_ar ?? '';
            $base['name_en'] = $this->name_en ?? '';
        }

        return $base;
    }

    /**
     * @return array<string, mixed>
     */
    public static function emptyShape(): array
    {
        $base = [
            'id' => 0,
            'name' => '',
            'slug' => '',
            'icon' => '',
            'color' => '#94A3B8',
            'type' => 'expense',
            'is_default' => false,
            'sort_order' => 0,
        ];

        if (app()->getLocale() === 'ar') {
            $base['name_ar'] = '';
        } else {
            $base['name_ar'] = '';
            $base['name_en'] = '';
        }

        return $base;
    }
}
