<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    // MariaDB < 10.5.2 (this project's local server: 10.4.32) hits a bug in
    // Laravel's doctrine/dbal-free renameColumn() that throws "Trying to
    // access array offset on null". Raw CHANGE COLUMN sidesteps it; sqlite
    // (used in tests) and other drivers use the normal Schema builder path.
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE printer_settings CHANGE bluetooth_address device_identifier VARCHAR(191) NOT NULL');
        } else {
            Schema::table('printer_settings', function (Blueprint $table) {
                $table->renameColumn('bluetooth_address', 'device_identifier');
            });
        }
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'mysql') {
            DB::statement('ALTER TABLE printer_settings CHANGE device_identifier bluetooth_address VARCHAR(191) NOT NULL');
        } else {
            Schema::table('printer_settings', function (Blueprint $table) {
                $table->renameColumn('device_identifier', 'bluetooth_address');
            });
        }
    }
};
