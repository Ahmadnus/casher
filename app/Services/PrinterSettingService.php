<?php

namespace App\Services;

use App\Models\PrinterSetting;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class PrinterSettingService
{
    public function listByType(?string $type = null): Collection
    {
        return PrinterSetting::query()->type($type)->orderByDesc('is_default')->get();
    }

    public function create(array $data): PrinterSetting
    {
        return DB::transaction(function () use ($data) {
            $printer = PrinterSetting::create($data);

            if ($printer->is_default) {
                $this->clearOtherDefaults($printer);
            }

            return $printer;
        });
    }

    public function update(PrinterSetting $printer, array $data): PrinterSetting
    {
        return DB::transaction(function () use ($printer, $data) {
            $printer->update($data);

            if ($printer->is_default) {
                $this->clearOtherDefaults($printer);
            }

            return $printer->fresh();
        });
    }

    public function setDefault(PrinterSetting $printer): PrinterSetting
    {
        return DB::transaction(function () use ($printer) {
            $printer->update(['is_default' => true]);
            $this->clearOtherDefaults($printer);

            return $printer->fresh();
        });
    }

    public function delete(PrinterSetting $printer): void
    {
        $printer->delete();
    }

    /**
     * Only one default printer is allowed per type (cash / invoice),
     * matching the Flutter PrinterService's single-active-connection
     * model per printer role (wired USB printers only accept one caller at a time).
     */
    protected function clearOtherDefaults(PrinterSetting $printer): void
    {
        PrinterSetting::where('type', $printer->type)
            ->where('id', '!=', $printer->id)
            ->update(['is_default' => false]);
    }
}
