<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TipResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $locale = app()->getLocale();

        $title = $locale === 'ar' ? ($this->title_ar ?? '') : ($this->title_en ?? '');
        $content = $locale === 'ar' ? ($this->content_ar ?? '') : ($this->content_en ?? '');

        $base = [
            'id' => $this->id,
            'title' => $title,
            'content' => $content,
            'icon' => $this->icon ?? '',
            'image' => $this->image ?? '',
            'audience' => $this->audience ?? '',
            'category' => $this->relationLoaded('category') && $this->category
                ? new CategoryResource($this->category)
                : CategoryResource::emptyShape(),
        ];

        if ($locale === 'ar') {
            $base['title_ar'] = $this->title_ar ?? '';
            $base['content_ar'] = $this->content_ar ?? '';
        } else {
            $base['title_ar'] = $this->title_ar ?? '';
            $base['title_en'] = $this->title_en ?? '';
            $base['content_ar'] = $this->content_ar ?? '';
            $base['content_en'] = $this->content_en ?? '';
        }

        return $base;
    }

    /**
     * @return array<string, mixed>
     */
    public static function emptyTipPayload(): array
    {
        $base = [
            'id' => 0,
            'title' => '',
            'content' => '',
            'icon' => '',
            'image' => '',
            'audience' => '',
            'category' => CategoryResource::emptyShape(),
        ];

        if (app()->getLocale() === 'ar') {
            $base['title_ar'] = '';
            $base['content_ar'] = '';
        } else {
            $base['title_ar'] = '';
            $base['title_en'] = '';
            $base['content_ar'] = '';
            $base['content_en'] = '';
        }

        return $base;
    }
}
