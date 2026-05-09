<?php

namespace App\Http\Controllers;

use App\Models\InterventionRequest;
use App\Models\MechanicRating;
use App\Models\User;
use App\Services\FcmService;
use App\Services\FirestoreSyncService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class InterventionRequestController extends Controller
{
    public function __construct(
        private readonly FcmService $fcmService,
        private readonly FirestoreSyncService $firestoreSync,
    ) {
    }

    public function index(Request $request)
    {
        $user = $request->user();
        if (! in_array($user->role, ['client', 'mecanicien'], true)) {
            return response()->json(['message' => 'Role utilisateur invalide.'], 403);
        }

        $validated = $request->validate([
            'status' => 'sometimes|in:pending,accepted,declined,completed',
        ]);

        $q = InterventionRequest::query()->with([
            'client:id,name,phone',
            'mechanic:id,name,phone',
            'mechanicRating',
        ]);

        if ($user->role === 'client') {
            $q->where('client_id', $user->id);
        } else {
            $q->where('mechanic_id', $user->id);
        }

        if (! empty($validated['status'])) {
            $q->where('status', $validated['status']);
        }

        $items = $q->orderByDesc('id')->get()->map(fn ($r) => $this->transform($r));

        return response()->json($items);
    }

    public function store(Request $request)
    {
        if ($request->user()->role !== 'client') {
            return response()->json(['message' => 'Seuls les clients peuvent créer une demande.'], 403);
        }

        $validated = $request->validate([
            'mechanic_id' => 'required|exists:users,id',
            'vehicle_type' => 'required|in:moto,voiture,autre',
            'description' => 'required|string|max:5000',
            'client_lat' => 'required|numeric|between:-90,90',
            'client_lng' => 'required|numeric|between:-180,180',
            'photo' => 'nullable|image|max:5120',
        ]);

        $mechanic = User::query()->findOrFail($validated['mechanic_id']);
        if ($mechanic->id === $request->user()->id) {
            return response()->json(['message' => 'Vous ne pouvez pas vous auto-assigner une demande.'], 422);
        }
        if (! $mechanic->isReachableMechanic()) {
            return response()->json(['message' => 'Ce mécanicien n’est pas disponible ou plus en ligne.'], 422);
        }

        $alreadyOpen = InterventionRequest::query()
            ->where('client_id', $request->user()->id)
            ->where('mechanic_id', $mechanic->id)
            ->whereIn('status', ['pending', 'accepted'])
            ->exists();
        if ($alreadyOpen) {
            return response()->json(['message' => 'Une demande active existe déjà pour ce mécanicien.'], 409);
        }

        $photoPath = null;
        if ($request->hasFile('photo')) {
            $photoPath = $request->file('photo')->store('requests', 'public');
        }

        $row = InterventionRequest::query()->create([
            'client_id' => $request->user()->id,
            'mechanic_id' => $mechanic->id,
            'vehicle_type' => $validated['vehicle_type'],
            'description' => $validated['description'],
            'photo_path' => $photoPath,
            'client_lat' => $validated['client_lat'],
            'client_lng' => $validated['client_lng'],
            'status' => 'pending',
        ]);

        $row->load(['client:id,name,phone', 'mechanic:id,name,phone']);

        $this->fcmService->sendToToken(
            $mechanic->fcm_token,
            'Nouvelle demande',
            'Un client vient de vous envoyer une demande.',
            ['type' => 'request_created', 'request_id' => (string) $row->id]
        );

        $this->firestoreSync->syncInterventionRequest($row);

        return response()->json($this->transform($row), 201);
    }

    public function show(Request $request, int $id)
    {
        $row = InterventionRequest::query()->with([
            'client:id,name,phone',
            'mechanic:id,name,phone',
            'mechanicRating',
        ])->findOrFail($id);
        $this->authorizeParticipant($request->user()->id, $row);

        return response()->json($this->transform($row));
    }

    /**
     * Clôture par le client : panne réglée ou non, puis possibilité de noter le mécanicien.
     */
    public function recordOutcome(Request $request, int $id)
    {
        if ($request->user()->role !== 'client') {
            return response()->json(['message' => 'Seuls les clients peuvent clôturer une demande.'], 403);
        }

        $row = InterventionRequest::query()->findOrFail($id);
        if ($row->client_id !== $request->user()->id) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }
        if ($row->status !== 'accepted') {
            return response()->json(['message' => 'Cette demande n’est pas en cours (acceptée).'], 422);
        }

        $validated = $request->validate([
            'outcome' => 'required|in:fixed,not_fixed',
        ]);

        $row->status = 'completed';
        $row->outcome = $validated['outcome'];
        $row->outcome_at = now();
        $row->save();

        $row->load(['client:id,name,phone', 'mechanic:id,name,phone', 'mechanicRating']);

        $this->fcmService->sendToToken(
            $row->mechanic?->fcm_token,
            'Intervention clôturée',
            'Le client a indiqué que la panne était '.($validated['outcome'] === 'fixed' ? 'réglée' : 'non réglée').'.',
            ['type' => 'request_completed', 'request_id' => (string) $row->id]
        );

        $this->firestoreSync->syncInterventionRequest($row->fresh());

        return response()->json($this->transform($row->fresh()));
    }

    /**
     * Note le mécanicien pour cette intervention (une seule fois).
     */
    public function storeRating(Request $request, int $id)
    {
        if ($request->user()->role !== 'client') {
            return response()->json(['message' => 'Seuls les clients peuvent noter.'], 403);
        }

        $row = InterventionRequest::query()->with('mechanicRating')->findOrFail($id);
        if ($row->client_id !== $request->user()->id) {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }
        if ($row->status !== 'completed' || $row->outcome === null) {
            return response()->json(['message' => 'Clôture d’abord l’intervention avant de noter.'], 422);
        }
        if ($row->mechanicRating !== null) {
            return response()->json(['message' => 'Tu as déjà noté cette intervention.'], 409);
        }

        $validated = $request->validate([
            'stars' => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string|max:2000',
        ]);

        MechanicRating::query()->create([
            'intervention_request_id' => $row->id,
            'client_id' => $request->user()->id,
            'mechanic_id' => $row->mechanic_id,
            'stars' => $validated['stars'],
            'comment' => $validated['comment'] ?? null,
        ]);

        $fresh = $row->fresh(['client:id,name,phone', 'mechanic:id,name,phone', 'mechanicRating']);

        $this->fcmService->sendToToken(
            $fresh->mechanic?->fcm_token,
            'Nouvelle note',
            'Un client t’a attribué '.$validated['stars'].'/5 pour une intervention.',
            ['type' => 'mechanic_rated', 'request_id' => (string) $fresh->id]
        );

        return response()->json($this->transform($fresh), 201);
    }

    public function accept(Request $request, int $id)
    {
        $user = $request->user();
        if ($user->role !== 'mecanicien') {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $row = InterventionRequest::query()->findOrFail($id);
        if ($row->mechanic_id !== $user->id) {
            return response()->json(['message' => 'Cette demande ne vous est pas adressée.'], 403);
        }
        if ($row->status !== 'pending') {
            return response()->json(['message' => 'Demande déjà traitée.'], 409);
        }

        $row->status = 'accepted';
        $row->save();
        $row->load(['client:id,name,phone', 'mechanic:id,name,phone']);

        $this->fcmService->sendToToken(
            $row->client?->fcm_token,
            'Demande acceptee',
            'Votre demande a ete acceptee par le mecanicien.',
            ['type' => 'request_accepted', 'request_id' => (string) $row->id]
        );

        $this->firestoreSync->syncInterventionRequest($row->fresh());

        return response()->json($this->transform($row));
    }

    public function decline(Request $request, int $id)
    {
        $user = $request->user();
        if ($user->role !== 'mecanicien') {
            return response()->json(['message' => 'Non autorisé.'], 403);
        }

        $row = InterventionRequest::query()->findOrFail($id);
        if ($row->mechanic_id !== $user->id) {
            return response()->json(['message' => 'Cette demande ne vous est pas adressée.'], 403);
        }
        if ($row->status !== 'pending') {
            return response()->json(['message' => 'Demande déjà traitée.'], 409);
        }

        $row->status = 'declined';
        $row->save();
        $row->load(['client:id,name,phone', 'mechanic:id,name,phone']);

        $this->fcmService->sendToToken(
            $row->client?->fcm_token,
            'Demande refusee',
            'Le mecanicien a refuse cette demande.',
            ['type' => 'request_declined', 'request_id' => (string) $row->id]
        );

        $this->firestoreSync->syncInterventionRequest($row->fresh());

        return response()->json($this->transform($row));
    }

    private function authorizeParticipant(int $userId, InterventionRequest $row): void
    {
        if ($row->client_id !== $userId && $row->mechanic_id !== $userId) {
            abort(403, 'Non autorisé.');
        }
    }

    private function transform(InterventionRequest $r): array
    {
        $data = $r->toArray();
        $data['photo_url'] = $r->photo_path
            ? Storage::disk('public')->url($r->photo_path)
            : null;

        $data['rating'] = null;
        if ($r->relationLoaded('mechanicRating') && $r->mechanicRating) {
            $data['rating'] = [
                'stars' => $r->mechanicRating->stars,
                'comment' => $r->mechanicRating->comment,
                'created_at' => $r->mechanicRating->created_at?->toIso8601String(),
            ];
        } elseif ($r->mechanicRating) {
            $data['rating'] = [
                'stars' => $r->mechanicRating->stars,
                'comment' => $r->mechanicRating->comment,
                'created_at' => $r->mechanicRating->created_at?->toIso8601String(),
            ];
        }

        return $data;
    }
}
