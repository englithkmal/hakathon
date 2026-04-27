<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TipResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $locale = app()->getLocale();

        return [
            'id' => $this->id,
            'title' => $locale === 'ar' ? $this->title_ar : $this->title_en,
            'content' => $locale === 'ar' ? $this->content_ar : $this->content_en,
            'icon' => $this->icon,
            'image' => $this->image,
            'audience' => $this->audience,
            'category' => new CategoryResource($this->whenLoaded('category')),
        ];
    }
}
