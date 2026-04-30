<?php

namespace App\Http\Controllers;

use App\Models\InterventionRequest;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class InterventionRequestController extends Controller
{
    public function __construct(private readonly FcmService $fcmService)
    {
    }

    public function index(Request $request)
    {
        $user = $request->user();
        if (! in_array($user->role, ['client', 'mecanicien'], true)) {
            return response()->json(['message' => 'Role utilisateur invalide.'], 403);
        }

        $validated = $request->validate([
            'status' => 'sometimes|in:pending,accepted,declined',
        ]);

        $q = InterventionRequest::query()->with(['client:id,name,phone', 'mechanic:id,name,phone']);

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
        if ($mechanic->role !== 'mecanicien' || ! $mechanic->is_available) {
            return response()->json(['message' => 'Ce mécanicien n’est pas disponible.'], 422);
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

        return response()->json($this->transform($row), 201);
    }

    public function show(Request $request, int $id)
    {
        $row = InterventionRequest::query()->with(['client:id,name,phone', 'mechanic:id,name,phone'])->findOrFail($id);
        $this->authorizeParticipant($request->user()->id, $row);

        return response()->json($this->transform($row));
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

        return $data;
    }
}
