<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * @property int $id
 * @property string $name
 * @property string $type
 * @property string $device_identifier
 * @property bool $is_active
 * @property bool $is_default
 */
class PrinterSetting extends Model
{
    /** @use HasFactory<\Database\Factories\PrinterSettingFactory> */
    use HasFactory, SoftDeletes;

    public const TYPES = ['cash', 'invoice'];

    protected $fillable = ['name', 'type', 'device_identifier', 'is_active', 'is_default'];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'is_default' => 'boolean',
        ];
    }

    public function scopeType($query, ?string $type)
    {
        return $type ? $query->where('type', $type) : $query;
    }

    public function scopeDefault($query)
    {
        return $query->where('is_default', true);
    }
}
