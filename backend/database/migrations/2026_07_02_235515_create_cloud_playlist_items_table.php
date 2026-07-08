<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * Tabel ini menyimpan item (lagu) di dalam setiap cloud_playlist.
     * 'song_id' adalah identifier unik dari Flutter (misal: 'online:youtube:VIDEO_ID').
     */
    public function up(): void
    {
        Schema::create('cloud_playlist_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cloud_playlist_id')->constrained()->onDelete('cascade');
            $table->string('song_id'); // e.g. 'online:youtube:dQw4w9WgXcQ'
            $table->string('title');
            $table->string('artist')->nullable();
            $table->string('thumbnail_url')->nullable();
            $table->integer('duration_seconds')->nullable();
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('cloud_playlist_items');
    }
};
