# Guide d’utilisation — MechAssist

Ce document décrit l’usage de l’application **MechAssist** (client Flutter) pour les **clients** et les **mécaniciens**. Il complète la configuration technique (backend Laravel, URL de l’API) décrite dans `frontend/README.md`.

### Comptes de démonstration (après `php artisan migrate --seed` dans `backend/`)

Ces comptes sont créés par le **seeder** Laravel (`database/seeders/DatabaseSeeder.php`). **Même mot de passe** pour les deux :

| Rôle | E-mail | Mot de passe |
|------|--------|----------------|
| **Client** | `client@mechassist.local` | `MechAssist2026!` |
| **Mécanicien** | `mecanicien@mechassist.local` | `MechAssist2026!` |

Les comptes que **tu crées** depuis l’app (inscription) utilisent l’**e-mail et le mot de passe que tu saisis** : ils sont enregistrés dans la **même base** que celle configurée dans `backend/.env` (PostgreSQL local, SQLite, etc.). Si l’app Flutter pointe vers un **autre serveur** ou une autre machine, tu ne verras pas les mêmes données. Vérifie `API_BASE_URL` / l’IP du PC (voir `frontend/README.md`).

**Si la reconnexion échoue** : mauvais e-mail ou mot de passe ; compte inexistant sur cette base (refais `php artisan db:seed` pour les démos, ou réinscris-toi). **Ne pas** confondre le mot de passe **PostgreSQL** (`DB_PASSWORD` dans `.env`, accès au serveur de base) avec les comptes **application** (e-mail / mot de passe MechAssist).

---

## 1. À quoi sert MechAssist ?

MechAssist met en relation des **clients** en panne (ou besoin d’assistance) avec des **mécaniciens** à proximité. L’application :

- affiche les mécaniciens **disponibles** autour de ta position ;
- permet d’**envoyer une demande d’intervention** (description, type de véhicule, photo optionnelle) ;
- gère le **cycle de vie** de la demande (en attente, acceptée, refusée, terminée) ;
- offre un **chat** entre client et mécanicien lorsque la demande est acceptée ;
- permet au client de **clôturer** l’intervention (panne réglée ou non) et de **noter** le mécanicien.

---

## 2. Rôles : client et mécanicien

| Rôle | Accès |
|------|--------|
| **Client** | Tableau de bord avec onglets **Proches** et **Demandes** : carte / liste des mécaniciens, envoi de demandes, suivi et chat. |
| **Mécanicien** | Tableau de bord **MechAssist Pro** : interrupteur **Disponible**, liste des demandes reçues, acceptation / refus, chat. |

Le rôle est défini à l’**inscription** (choix client ou mécanicien). Une connexion **Google** respecte aussi le rôle choisi sur l’écran d’inscription.

---

## 3. Avant de commencer (important)

### 3.1 Réseau et serveur

L’application parle à une **API Laravel** (généralement sur le port **8000**). Si le serveur est arrêté, l’URL est incorrecte ou le réseau bloque la connexion, tu verras des **messages d’erreur** ou des **délais d’attente** (environ 25 secondes maximum par requête, au lieu d’un chargement infini).

- **Émulateur Android** : l’app utilise par défaut l’hôte `10.0.2.2` pour joindre le PC.
- **Téléphone physique** : il faut compiler avec une URL qui pointe vers ton PC, par exemple  
  `flutter run --dart-define=API_BASE_URL=http://ADRESSE_IP_DU_PC:8000`  
  (même origine que ton `APP_URL` Laravel, **sans** `/api` à la fin ; l’app ajoute `/api` automatiquement).

### 3.2 Géolocalisation

- **Clients** : la position sert à lister les mécaniciens **à proximité** et à envoyer la position avec la demande. **Autorise la localisation** quand l’app ou le navigateur le demande.
- **Mécaniciens** : la position permet d’être visible dans les recherches « à proximité » des clients. Active les **services de localisation** sur l’appareil.

Sur **le Web**, autorise la géolocalisation pour le site (icône à côté de la barre d’adresse). Une carte peut s’afficher (Google Maps si une clé est configurée côté serveur, sinon fond Carto).

### 3.3 Notifications (optionnel)

L’app peut enregistrer un jeton **FCM** (Firebase Cloud Messaging) pour les notifications push, une fois connecté. Si tu refuses les notifications, le reste de l’app fonctionne en général normalement.

---

## 4. Démarrage de l’application

1. Au lancement, un **écran d’accueil** (splash) vérifie si une session est déjà enregistrée.
2. Si tu es **déjà connecté** avec un jeton valide, tu es redirigé vers le tableau de bord **client** ou **mécanicien** selon ton rôle.
3. Sinon, tu arrives sur l’écran **Bienvenue** : **Se connecter**, **Créer un compte**, ou **Besoin d’aide ?**.

---

## 5. Compte utilisateur

### 5.1 Créer un compte

1. Depuis **Bienvenue**, touche **Créer un compte**.
2. Renseigne : **nom**, **email**, **téléphone**, **mot de passe**, **confirmation du mot de passe**.
3. Choisis le **rôle** : **client** ou **mécanicien**.
4. Règles usuelles : tous les champs obligatoires ; mot de passe **identique** à la confirmation ; **au moins 6 caractères** pour le mot de passe.
5. Tu peux aussi t’inscrire / te connecter avec **Google** (bouton dédié) : le **rôle** sélectionné sur le formulaire est envoyé au serveur lors de la première liaison.

Après une inscription réussie, tu es connecté et dirigé vers le bon tableau de bord.

### 5.2 Se connecter (email et mot de passe)

1. **Se connecter** depuis **Bienvenue**.
2. Saisis **email** et **mot de passe**.
3. Option **Se souvenir de moi** : enregistre **uniquement l’email** sur l’appareil (le mot de passe n’est **pas** conservé).

### 5.3 Connexion Google

Sur l’écran de connexion, utilise le flux Google ; en cas de succès, le serveur renvoie ton compte et tu accèdes directement à ton espace.

### 5.4 Mot de passe oublié

1. Sur l’écran de connexion, ouvre **Mot de passe oublié**.
2. Indique ton **email** : le backend envoie un message avec un lien ou un jeton de réinitialisation (**selon la configuration mail du serveur**).
3. En développement, si le mail est en mode **log**, le contenu peut se retrouver dans les fichiers de log du backend plutôt que dans ta boîte mail.

Écran **Réinitialiser le mot de passe** : saisis email, jeton reçu, nouveau mot de passe et confirmation.

---

## 6. Écran Aide

Depuis **Bienvenue** (lien *Besoin d’aide ?*) ou via l’icône **?** dans la barre des tableaux de bord :

- voir et **copier** l’**URL de base de l’API** utilisée par l’app ;
- ouvrir la **documentation Swagger** (test des routes HTTP) ;
- rappel pour la compilation avec `API_BASE_URL` sur téléphone physique.

Pour Swagger : connecte-toi avec `POST /api/login`, copie le **token**, puis utilise **Authorize** avec le schéma **Bearer**.

---

## 7. Espace client

### 7.1 Barre supérieure

- **Aide** : écran décrit ci-dessus.
- **Rafraîchir** : recharge les listes et, si besoin, une position GPS récente.
- **Déconnexion** : invalide la session côté serveur si possible, déconnecte Google si utilisé, efface la session locale, retour à la connexion.

### 7.2 Onglet « Proches »

- **Carte** (si position disponible) : ta position et les mécaniciens à proximité.
- **Liste** : nom, distance, téléphone, indicateur **En ligne** si applicable, **note moyenne** et nombre d’avis si disponibles.
- **Demander** : ouvre une fenêtre pour créer une demande vers ce mécanicien.

#### Créer une demande

1. **Type de véhicule** : voiture, moto ou autre.
2. **Description de la panne** : obligatoire ; décris le problème clairement.
3. **Photo (optionnel)** : galerie ; sur mobile, **appareil photo** aussi. Tu peux retirer la photo avant envoi.
4. **Envoyer** : la position actuelle est envoyée avec la demande. Sans position, l’app t’invite à activer la géolocalisation.

Après envoi réussi, l’app peut basculer sur l’onglet **Demandes**.

### 7.3 Onglet « Demandes »

Liste de toutes tes demandes avec un résumé (véhicule, mécanicien, description, **statut**).

**Statuts côté affichage (résumé)** :

| Statut (workflow) | Signification pour toi |
|-------------------|-------------------------|
| **pending** | En attente de réponse du mécanicien. |
| **accepted** | Acceptée — le **chat** est disponible. |
| **declined** | Refusée par le mécanicien. |
| **completed** | Terminée — tu as indiqué si la panne était réglée ; tu peux **noter** le mécanicien si ce n’est pas déjà fait. |

**Toucher une ligne** ouvre le **détail** : mécanicien, véhicule, statut, résultat, ta note, texte, **photo** jointe si présente.

**Actions possibles selon le cas** :

- **Chat** : quand la demande est **acceptée** — messagerie avec rafraîchissement automatique ; envoi de messages tant que l’intervention n’est pas dans un état qui bloque l’écriture.
- **Clôturer** : indique **Oui, réglée** ou **Non réglée** pour terminer l’intervention côté workflow.
- **Noter** : après clôture, donne une **note sur 5** et un **commentaire optionnel**.

Tu peux aussi utiliser les boutons **Chat** / **Noter** directement sur certaines lignes de la liste.

### 7.4 Rafraîchissement automatique

Les listes se mettent à jour **périodiquement** en arrière-plan. Tu peux toujours tirer pour rafraîchir (**tirer vers le bas**) sur les onglets qui le supportent.

---

## 8. Espace mécanicien (MechAssist Pro)

### 8.1 Disponibilité

L’interrupteur **Disponible** contrôle si tu es **visible** pour les clients qui cherchent des mécaniciens à proximité.

- **Activé** : tu peux apparaître dans les résultats « proches » (selon règles serveur : position, rayon, en ligne, etc.).
- **Désactivé** : tu es **hors ligne** ; les clients ne te voient pas comme disponible.

### 8.2 Liste « Demandes reçues »

Chaque carte résume : type de véhicule, **statut**, description, éventuellement une **vignette photo** du client.

- **En attente (pending)** : tu peux **accepter** (icône verte) ou **refuser** (icône rouge).
- **Acceptée** : bouton **Chat** pour dialoguer avec le client.
- **Terminée** : l’app peut afficher le **résultat** déclaré par le client (panne réglée ou non) et la **note** laissée.

### 8.3 Barre supérieure

Même logique que le client : **Aide**, **Rafraîchir**, **Déconnexion**.

### 8.4 Position et présence

L’app envoie régulièrement ta **position** et une **activité de présence** pour que le système sache que tu es actif, selon les règles du backend.

---

## 9. Chat d’intervention

- Le chat est centré sur une **demande** précise.
- Tant que la demande n’est **pas acceptée**, le chat peut être **lecture seule** ou limité, avec un message d’information.
- Une demande **refusée** ou **terminée** peut afficher l’historique en **lecture seule** selon le statut.
- Les messages se mettent à jour automatiquement toutes les quelques secondes.

---

## 10. Problèmes fréquents

| Symptôme | Piste |
|----------|--------|
| Message sur **délai dépassé** ou erreur réseau | Vérifie que le **backend** tourne, que l’**URL** (`API_BASE_URL` sur téléphone) est correcte, Wi‑Fi / pare-feu / VPN. |
| **Aucun mécanicien** | Les mécaniciens doivent être **disponibles**, dans le **rayon** défini par le serveur, avec une **position** récente. |
| **Carte** ou position impossible (Web) | Autorise la **géolocalisation** pour le site. |
| **Pas d’e-mail** pour mot de passe oublié | Configure le **mail** sur le serveur Laravel (`MAIL_*`) ou consulte les **logs** en local. |
| Session expirée / « reconnecte-toi » | **Déconnexion** puis nouvelle connexion ; le jeton a peut‑être expiré ou été invalidé. |

---

## 11. Rappels pratiques

- Garde ton **téléphone** et ton **serveur API** sur le **même réseau** (ou une URL accessible) lors des tests sur appareil réel.
- Les **photos** de demande passent par le serveur Laravel : espace disque et droits `storage` doivent être corrects côté backend.
- Pour toute évolution des **routes** ou des champs JSON, la **documentation Swagger** reste la référence technique.

---

*Document généré pour la base de code MechAssist (Flutter + Laravel). En cas d’écart avec une version future de l’app, privilégie les textes affichés à l’écran et la documentation API.*
