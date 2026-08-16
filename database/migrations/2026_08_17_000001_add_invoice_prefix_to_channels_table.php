<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Per-channel invoice numbering.
 *
 * Talabaty and Eshyai get their own prefixes so each platform's invoices run
 * on an independent daily sequence (TLB-20260817-0001, ESH-20260817-0001).
 * The four in-house channels keep sharing the existing INV prefix, so current
 * numbering and all historical invoices are untouched.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('channels', function (Blueprint $table) {
            $table->string('invoice_prefix', 8)->default('INV')->after('name_ar');
        });

        DB::table('channels')->where('code', 'talabaty')->update(['invoice_prefix' => 'TLB']);
        DB::table('channels')->where('code', 'eshyai')->update(['invoice_prefix' => 'ESH']);
    }

    public function down(): void
    {
        Schema::table('channels', function (Blueprint $table) {
            $table->dropColumn('invoice_prefix');
        });
    }
};
