<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RestrictSwaggerInProduction
{
    /**
     * Désactive l’UI Swagger en production sauf si L5_SWAGGER_UI_ENABLED=true.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (app()->environment('production') && ! filter_var(config('l5-swagger.ui_enabled'), FILTER_VALIDATE_BOOLEAN)) {
            abort(404);
        }

        return $next($request);
    }
}
