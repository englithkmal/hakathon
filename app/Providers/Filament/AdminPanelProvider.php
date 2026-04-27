<?php

namespace App\Providers\Filament;

use App\Filament\Widgets\ExpensesByCategoryChart;
use App\Filament\Widgets\IncomeVsExpensesChart;
use App\Filament\Widgets\UserGrowthChart;
use App\Filament\Widgets\WafferStatsOverview;
use App\Http\Middleware\SetLocale;
use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\AuthenticateSession;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Navigation\MenuItem;
use Filament\Pages\Dashboard;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Support\Colors\Color;
use Filament\Widgets\AccountWidget;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\View\Middleware\ShareErrorsFromSession;

class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->login()
            ->brandName(__('waffer.brand'))
            ->brandLogo(asset('images/waffer-logo.png'))
            ->brandLogoHeight('2.6rem')
            ->favicon(asset('favicon.png'))
            ->colors([
                'primary' => [
                    50  => '#EEFBF8',
                    100 => '#D5F4EC',
                    200 => '#ABE7D7',
                    300 => '#7FD7C0',
                    400 => '#52C2A6',
                    500 => '#2BA98C',
                    600 => '#1F8B8E',
                    700 => '#1A6E73',
                    800 => '#15565B',
                    900 => '#103F44',
                    950 => '#082529',
                ],
                'success' => [
                    50  => '#F1FBF4',
                    100 => '#DBF5E1',
                    200 => '#B7EBC4',
                    300 => '#85DA9D',
                    400 => '#54C374',
                    500 => '#34A85A',
                    600 => '#258846',
                    700 => '#206A39',
                    800 => '#1A5430',
                    900 => '#143F25',
                    950 => '#082516',
                ],
                'gray' => Color::Slate,
                'info' => Color::Sky,
                'warning' => Color::Amber,
                'danger' => Color::Rose,
            ])
            ->font('Cairo')
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\Filament\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\Filament\Pages')
            ->pages([
                Dashboard::class,
            ])
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\Filament\Widgets')
            ->widgets([
                WafferStatsOverview::class,
                IncomeVsExpensesChart::class,
                ExpensesByCategoryChart::class,
                UserGrowthChart::class,
                AccountWidget::class,
            ])
            ->databaseNotifications()
            ->databaseNotificationsPolling('30s')
            ->userMenuItems([
                'language-ar' => MenuItem::make()
                    ->label('العربية')
                    ->icon('heroicon-o-language')
                    ->url(fn () => request()->fullUrlWithQuery(['lang' => 'ar']))
                    ->visible(fn () => app()->getLocale() !== 'ar'),
                'language-en' => MenuItem::make()
                    ->label('English')
                    ->icon('heroicon-o-language')
                    ->url(fn () => request()->fullUrlWithQuery(['lang' => 'en']))
                    ->visible(fn () => app()->getLocale() !== 'en'),
            ])
            ->middleware([
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                AuthenticateSession::class,
                ShareErrorsFromSession::class,
                VerifyCsrfToken::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
                SetLocale::class,
            ])
            ->authMiddleware([
                Authenticate::class,
            ]);
    }
}
