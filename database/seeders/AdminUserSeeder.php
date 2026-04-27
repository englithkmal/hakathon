<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['phone' => '+966500000000'],
            [
                'name' => 'Waffer Admin',
                'email' => 'admin@waffer.app',
                'phone_verified_at' => now(),
                'email_verified_at' => now(),
                'password' => Hash::make('password'),
                'currency' => 'SAR',
                'language' => 'ar',
                'is_admin' => true,
                'is_active' => true,
            ]
        );
    }
}
