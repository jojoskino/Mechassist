<?php

use App\Http\Controllers\PublicStorageController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/media/{path}', [PublicStorageController::class, 'show'])
    ->where('path', '.*')
    ->name('media.public');

Route::get('/', function () {
    return view('welcome');
});


/*
 * Requis pour les e-mails de réinitialisation Laravel (notification ResetPassword).
 * L’app mobile utilise POST /api/reset-password ; cette page explique la marche à suivre.
 */
Route::get('/password/reset/{token}', function (Request $_request, string $_token) {
    return response(
        '<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>MechAssist</title></head><body style="font-family:sans-serif;padding:2rem">'
        .'<h1>Réinitialisation du mot de passe</h1>'
        .'<p>Ouvre l’application <strong>MechAssist</strong> (écran « Mot de passe oublié » puis « J’ai déjà un code ») avec ton e-mail et le jeton reçu par e-mail.</p>'
        .'<p>Tu peux aussi appeler <code>POST /api/reset-password</code> avec <code>email</code>, <code>token</code>, <code>password</code> et <code>password_confirmation</code>.</p>'
        .'</body></html>',
        200,
        ['Content-Type' => 'text/html; charset=UTF-8'],
    );
})->name('password.reset');
