<?php

namespace App\OpenApi;

use OpenApi\Attributes as OA;

/**
 * Documentation OpenAPI 3 — générée pour Swagger UI (L5-Swagger).
 * Les chemins correspondent au préfixe `/api` des routes Laravel.
 */
#[OA\Info(
    title: 'MechAssist API',
    version: '1.0.0',
    description: 'API REST : clients, mécaniciens, demandes d’intervention, chat, géolocalisation, notes. Auth : Laravel Sanctum (Bearer token).'
)]
#[OA\Server(url: '/', description: 'Serveur d’exécution (ex. http://127.0.0.1:8000)')]
#[OA\SecurityScheme(
    securityScheme: 'sanctum',
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'Sanctum',
    description: 'Token obtenu via POST /api/login, /api/register ou /api/auth/google — header : Authorization: Bearer {token}'
)]
#[OA\Tag(name: 'Auth', description: 'Inscription, connexion, mot de passe, Google')]
#[OA\Tag(name: 'Public', description: 'Configuration exposée au client')]
#[OA\Tag(name: 'Profil', description: 'Profil et disponibilité (Bearer)')]
#[OA\Tag(name: 'Géolocalisation', description: 'Position et recherche (Bearer)')]
#[OA\Tag(name: 'Demandes', description: 'Interventions (Bearer)')]
#[OA\Tag(name: 'Chat', description: 'Messages (Bearer)')]
#[OA\Tag(name: 'Push', description: 'FCM (Bearer)')]
// --- Auth ---
#[OA\Post(
    path: '/api/register',
    operationId: 'register',
    description: 'Crée un compte client ou mécanicien.',
    tags: ['Auth'],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['name', 'email', 'phone', 'password', 'password_confirmation', 'role'],
            properties: [
                new OA\Property(property: 'name', type: 'string'),
                new OA\Property(property: 'email', type: 'string', format: 'email'),
                new OA\Property(property: 'phone', type: 'string'),
                new OA\Property(property: 'password', type: 'string', format: 'password'),
                new OA\Property(property: 'password_confirmation', type: 'string', format: 'password'),
                new OA\Property(property: 'role', type: 'string', enum: ['client', 'mecanicien']),
                new OA\Property(property: 'fcm_token', type: 'string', nullable: true),
                new OA\Property(property: 'mechanic_specialty', type: 'string', nullable: true),
            ]
        )
    ),
    responses: [
        new OA\Response(response: 201, description: 'Compte créé + token'),
        new OA\Response(response: 422, description: 'Validation'),
    ]
)]
#[OA\Post(
    path: '/api/login',
    operationId: 'login',
    tags: ['Auth'],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['email', 'password'],
            properties: [
                new OA\Property(property: 'email', type: 'string', format: 'email'),
                new OA\Property(property: 'password', type: 'string', format: 'password'),
                new OA\Property(property: 'fcm_token', type: 'string', nullable: true),
            ]
        )
    ),
    responses: [
        new OA\Response(response: 200, description: 'OK + token'),
        new OA\Response(response: 401, description: 'Identifiants incorrects'),
    ]
)]
#[OA\Post(
    path: '/api/auth/google',
    operationId: 'googleLogin',
    tags: ['Auth'],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['id_token'],
            properties: [
                new OA\Property(property: 'id_token', type: 'string'),
                new OA\Property(property: 'role', type: 'string', enum: ['client', 'mecanicien'], nullable: true),
                new OA\Property(property: 'fcm_token', type: 'string', nullable: true),
            ]
        )
    ),
    responses: [
        new OA\Response(response: 200, description: 'OK + token'),
        new OA\Response(response: 401, description: 'Jeton Google invalide'),
        new OA\Response(response: 503, description: 'Google non configuré'),
    ]
)]
#[OA\Post(
    path: '/api/forgot-password',
    operationId: 'forgotPassword',
    description: 'Envoie un e-mail avec le lien / token de réinitialisation (MAIL_* requis).',
    tags: ['Auth'],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['email'],
            properties: [new OA\Property(property: 'email', type: 'string', format: 'email')]
        )
    ),
    responses: [
        new OA\Response(response: 200, description: 'E-mail envoyé'),
        new OA\Response(response: 422, description: 'E-mail inconnu ou throttling'),
    ]
)]
#[OA\Post(
    path: '/api/reset-password',
    operationId: 'resetPassword',
    tags: ['Auth'],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['email', 'token', 'password', 'password_confirmation'],
            properties: [
                new OA\Property(property: 'email', type: 'string', format: 'email'),
                new OA\Property(property: 'token', type: 'string'),
                new OA\Property(property: 'password', type: 'string', format: 'password'),
                new OA\Property(property: 'password_confirmation', type: 'string', format: 'password'),
            ]
        )
    ),
    responses: [
        new OA\Response(response: 200, description: 'Mot de passe mis à jour'),
        new OA\Response(response: 422, description: 'Jeton invalide ou expiré'),
    ]
)]
#[OA\Get(
    path: '/api/client-config',
    operationId: 'clientConfig',
    tags: ['Public'],
    responses: [new OA\Response(response: 200, description: 'google_client_id, google_maps_web_api_key')]
)]
// --- Sanctum ---
#[OA\Post(
    path: '/api/logout',
    operationId: 'logout',
    security: [['sanctum' => []]],
    tags: ['Auth'],
    responses: [new OA\Response(response: 200, description: 'Déconnecté')]
)]
#[OA\Get(
    path: '/api/me',
    operationId: 'me',
    security: [['sanctum' => []]],
    tags: ['Profil'],
    responses: [new OA\Response(response: 200, description: 'Utilisateur courant')]
)]
#[OA\Get(
    path: '/api/profile',
    operationId: 'profileShow',
    security: [['sanctum' => []]],
    tags: ['Profil'],
    responses: [new OA\Response(response: 200, description: 'Profil')]
)]
#[OA\Patch(
    path: '/api/profile',
    operationId: 'profileUpdate',
    security: [['sanctum' => []]],
    tags: ['Profil'],
    requestBody: new OA\RequestBody(
        content: new OA\JsonContent(
            properties: [
                new OA\Property(property: 'name', type: 'string', nullable: true),
                new OA\Property(property: 'phone', type: 'string', nullable: true),
                new OA\Property(property: 'is_available', type: 'boolean', nullable: true),
                new OA\Property(property: 'mechanic_specialty', type: 'string', nullable: true),
            ]
        )
    ),
    responses: [new OA\Response(response: 200, description: 'Mis à jour')]
)]
#[OA\Post(
    path: '/api/location',
    operationId: 'locationUpdate',
    security: [['sanctum' => []]],
    tags: ['Géolocalisation'],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['latitude', 'longitude'],
            properties: [
                new OA\Property(property: 'latitude', type: 'number', format: 'float'),
                new OA\Property(property: 'longitude', type: 'number', format: 'float'),
            ]
        )
    ),
    responses: [new OA\Response(response: 200, description: 'Position enregistrée')]
)]
#[OA\Post(
    path: '/api/presence/touch',
    operationId: 'presenceTouch',
    security: [['sanctum' => []]],
    tags: ['Géolocalisation'],
    responses: [new OA\Response(response: 200, description: 'Présence mécano')]
)]
#[OA\Get(
    path: '/api/mechanics/nearby',
    operationId: 'mechanicsNearby',
    security: [['sanctum' => []]],
    tags: ['Géolocalisation'],
    parameters: [
        new OA\Parameter(name: 'latitude', in: 'query', required: true, schema: new OA\Schema(type: 'number')),
        new OA\Parameter(name: 'longitude', in: 'query', required: true, schema: new OA\Schema(type: 'number')),
        new OA\Parameter(name: 'radius_km', in: 'query', required: false, schema: new OA\Schema(type: 'number')),
        new OA\Parameter(name: 'min_rating', in: 'query', required: false, schema: new OA\Schema(type: 'number')),
        new OA\Parameter(name: 'specialty', in: 'query', required: false, schema: new OA\Schema(type: 'string')),
    ],
    responses: [new OA\Response(response: 200, description: 'Liste JSON mécaniciens')]
)]
#[OA\Get(
    path: '/api/requests',
    operationId: 'requestsIndex',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    parameters: [
        new OA\Parameter(name: 'status', in: 'query', required: false, schema: new OA\Schema(type: 'string', enum: ['pending', 'accepted', 'declined', 'completed'])),
    ],
    responses: [new OA\Response(response: 200, description: 'Liste des demandes')]
)]
#[OA\Post(
    path: '/api/requests',
    operationId: 'requestsStore',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    description: 'Accepte `application/json` ou `multipart/form-data` (champs identiques + fichier optionnel `photo`).',
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['mechanic_id', 'vehicle_type', 'description', 'client_lat', 'client_lng'],
            properties: [
                new OA\Property(property: 'mechanic_id', type: 'integer'),
                new OA\Property(property: 'vehicle_type', type: 'string', enum: ['moto', 'voiture', 'autre']),
                new OA\Property(property: 'description', type: 'string'),
                new OA\Property(property: 'client_lat', type: 'number'),
                new OA\Property(property: 'client_lng', type: 'number'),
                new OA\Property(property: 'client_address', type: 'string', nullable: true),
            ]
        )
    ),
    responses: [
        new OA\Response(response: 201, description: 'Demande créée'),
        new OA\Response(response: 422, description: 'Validation'),
    ]
)]
#[OA\Get(
    path: '/api/requests/{id}',
    operationId: 'requestsShow',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    responses: [new OA\Response(response: 200, description: 'Détail demande')]
)]
#[OA\Post(
    path: '/api/requests/{id}/accept',
    operationId: 'requestsAccept',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    responses: [new OA\Response(response: 200, description: 'Acceptée')]
)]
#[OA\Post(
    path: '/api/requests/{id}/decline',
    operationId: 'requestsDecline',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    responses: [new OA\Response(response: 200, description: 'Refusée')]
)]
#[OA\Post(
    path: '/api/requests/{id}/mechanic-complete',
    operationId: 'requestsMechanicComplete',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    responses: [new OA\Response(response: 200, description: 'Mécanicien a marqué l’intervention terminée')]
)]
#[OA\Post(
    path: '/api/requests/{id}/outcome',
    operationId: 'requestsOutcome',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    description: 'Après que le mécanicien a appelé POST /api/requests/{id}/mechanic-complete.',
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['outcome'],
            properties: [new OA\Property(property: 'outcome', type: 'string', enum: ['fixed', 'not_fixed'])]
        )
    ),
    responses: [new OA\Response(response: 200, description: 'Clôturée')]
)]
#[OA\Post(
    path: '/api/requests/{id}/rating',
    operationId: 'requestsRating',
    security: [['sanctum' => []]],
    tags: ['Demandes'],
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['stars'],
            properties: [
                new OA\Property(property: 'stars', type: 'integer', minimum: 1, maximum: 5),
                new OA\Property(property: 'comment', type: 'string', nullable: true),
            ]
        )
    ),
    responses: [
        new OA\Response(response: 201, description: 'Note enregistrée'),
        new OA\Response(response: 409, description: 'Déjà noté'),
    ]
)]
#[OA\Get(
    path: '/api/requests/{id}/messages',
    operationId: 'messagesIndex',
    security: [['sanctum' => []]],
    tags: ['Chat'],
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    responses: [new OA\Response(response: 200, description: 'Liste messages')]
)]
#[OA\Post(
    path: '/api/requests/{id}/messages',
    operationId: 'messagesStore',
    security: [['sanctum' => []]],
    tags: ['Chat'],
    parameters: [new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'integer'))],
    requestBody: new OA\RequestBody(
        required: true,
        content: new OA\JsonContent(
            required: ['body'],
            properties: [new OA\Property(property: 'body', type: 'string')]
        )
    ),
    responses: [
        new OA\Response(response: 201, description: 'Message créé'),
        new OA\Response(response: 422, description: 'Demande non acceptée'),
    ]
)]
#[OA\Post(
    path: '/api/push/token',
    operationId: 'pushToken',
    security: [['sanctum' => []]],
    tags: ['Push'],
    requestBody: new OA\RequestBody(
        content: new OA\JsonContent(
            properties: [new OA\Property(property: 'fcm_token', type: 'string', nullable: true)]
        )
    ),
    responses: [new OA\Response(response: 200, description: 'OK')]
)]
final class MechAssistDocument
{
}
