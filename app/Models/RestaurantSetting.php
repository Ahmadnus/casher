<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Spatie\MediaLibrary\HasMedia;
use Spatie\MediaLibrary\InteractsWithMedia;
use Spatie\MediaLibrary\MediaCollections\Models\Media;

/**
 * Singleton settings row (id is always 1). Use RestaurantSetting::current()
 * to fetch/create it rather than querying directly.
 *
 * @property string $name
 * @property string $currency
 * @property string $currency_symbol
 * @property string|null $address
 * @property string|null $phone
 * @property float $tax_rate
 * @property string $theme
 * @property string|null $receipt_header
 * @property string|null $receipt_footer
 */
class RestaurantSetting extends Model implements HasMedia
{
    use InteractsWithMedia;

    protected $fillable = [
        'name', 'currency', 'currency_symbol', 'address', 'phone',
        'tax_rate', 'theme', 'receipt_header', 'receipt_footer',
    ];

    protected function casts(): array
    {
        return [
            'tax_rate' => 'decimal:2',
        ];
    }

    public static function current(): self
    {
        return static::query()->firstOrCreate(['id' => 1], [
            'name' => config('app.name', 'Restaurant'),
        ]);
    }

    public function registerMediaCollections(): void
    {
        $this->addMediaCollection('logo')
            ->singleFile()
            ->useDisk(config('media-library.disk_name'));
    }

    public function registerMediaConversions(?Media $media = null): void
    {
        $this->addMediaConversion('thumb')->width(200)->height(200)->nonQueued();
    }

    public function getLogoUrlAttribute(): ?string
    {
        return $this->getFirstMedia('logo')?->getUrl();
    }
}
