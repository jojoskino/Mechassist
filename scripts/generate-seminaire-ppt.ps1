# Genere docs/MechAssist_Seminaire_MIDA.pptx (sections I a VI)
$ErrorActionPreference = "Stop"
$docsDir = Join-Path $PSScriptRoot "..\docs"
if (-not (Test-Path $docsDir)) { New-Item -ItemType Directory -Path $docsDir | Out-Null }
$outPath = [System.IO.Path]::GetFullPath((Join-Path $docsDir "MechAssist_Seminaire_MIDA.pptx"))

$slides = @(
    @{
        Layout = 1
        Title = "MechAssist"
        Body = "Application mobile de mise en relation Client - Mecanicien par geolocalisation`n`nSeminaire MIDA - Groupe 12`nUCAO-UUT - Genie Informatique (2023-2026)`n`nESSE Henry-Joel | JOHNSON Jeremiah | MATANVI Akouvi Abigail`nEncadrement : Mr WOAMEY"
    }
    @{
        Layout = 2
        Title = "I - INTRODUCTION"
        Body = "Contexte : hausse des pannes mecaniques (motos, voitures)`nRecherche encore basee sur bouche-a-oreille et appels`nDigitalisation et smartphones : opportunite de centraliser l'assistance`n`nMechAssist : plateforme mobile pour connecter conducteurs et mecaniciens en temps reel"
    }
    @{
        Layout = 2
        Title = "I - INTRODUCTION (suite)"
        Body = "Objectif du seminaire : presenter l'analyse, la conception et la realisation d'une solution operationnelle`n`nStack retenue : Flutter (front), Laravel (API REST), PostgreSQL (donnees metier)`nDepot : github.com/jojoskino/Mechassist"
    }
    @{
        Layout = 2
        Title = "II - PRESENTATION DU THEME ET PROBLEMATIQUE"
        Body = "Theme : assistance mecanique geolocalisee`n`nProblematique :`nComment mettre en relation, en temps reel, un client en panne avec un mecanicien proche pour une assistance rapide, efficace et tracee ?`n`nConstat : pas de solution simple, centralisee et fiable dans le contexte vise"
    }
    @{
        Layout = 2
        Title = "II - Objectifs du projet"
        Body = "Objectif general : reduire le delai d'intervention en connectant client et professionnel`n`nObjectifs specifiques :`n- Signaler une panne facilement`n- Geolocaliser les mecaniciens proches`n- Assistance a distance (chat) et sur site`n- Notifications et suivi des demandes`n- Evaluation post-intervention"
    }
    @{
        Layout = 2
        Title = "II - Public cible et valeur"
        Body = "Clients : conducteurs de motos et voitures en situation de panne`nMecaniciens : professionnels gerant disponibilite et interventions`n`nValeur client : gain de temps, transparence, historique`nValeur mecanicien : nouvelles demandes, visibilite, optimisation des deplacements"
    }
    @{
        Layout = 2
        Title = "III - ANALYSE ET CONCEPTION"
        Body = "Acteurs : Client, Mecanicien, Systeme de notifications`n`nBesoins client : trouver un proche, envoyer demande, suivre statut, chatter, noter`nBesoins mecanicien : recevoir demandes, accepter/refuser, naviguer, cloturer`n`nContraintes : securite (JWT), performance, mode hors-ligne partiel (cache)"
    }
    @{
        Layout = 2
        Title = "III - Architecture technique"
        Body = "Frontend Flutter : Android, Web (carte, chat, profils)`nBackend Laravel 11 : API REST /api/*`nBase PostgreSQL (MechAssist_db) : source de verite`nFirebase (optionnel) : FCM notifications, sync Firestore desactivee en local`n`nFlux : App -> API -> PostgreSQL ; temps reel via polling / push"
    }
    @{
        Layout = 2
        Title = "III - Modele de donnees (principal)"
        Body = "users : comptes client / mecanicien, profil, position, disponibilite`nintervention_requests : panne, statut, GPS, vehicule`nchat_messages : echanges lies a une demande`nmechanic_ratings : notes et commentaires`n`nStatuts demande : pending, accepted, in_progress, completed, cancelled"
    }
    @{
        Layout = 2
        Title = "III - Conception UX"
        Body = "Ecran carte type Google Maps (decouverte mecaniciens / zone d'intervention)`nBarre de recherche epuree, filtres (rayon, notes, specialite)`nBottom sheet : liste des resultats et actions`nNavigation par role : tableau de bord client vs mecanicien`nAuthentification : email/mot de passe + Google OAuth"
    }
    @{
        Layout = 2
        Title = "IV - REALISATION ET MISE EN OEUVRE"
        Body = "Backend : controllers REST, migrations PostgreSQL, seed comptes demo`nFrontend : dashboards client/mecanicien, carte, creation demande, chat`nScripts dev : flutter_run.ps1, run_web.ps1 (port 53100), API Laravel 8000`n`nComptes demo :`nclient@mechassist.local / mecanicien@mechassist.local`nMot de passe : MechAssist2026!"
    }
    @{
        Layout = 2
        Title = "IV - Fonctionnalites implementees"
        Body = "Inscription / connexion et synchronisation du role session`nCarte avec marqueurs mecaniciens et recentrage GPS`nCreation et suivi des demandes d'intervention`nMessagerie par demande`nProfil utilisateur et avatars`nHealth check API + verification PostgreSQL (verify-postgres.ps1)"
    }
    @{
        Layout = 2
        Title = "IV - Difficultes et corrections"
        Body = "Conflit ports Flutter/Laravel : web 53100, API 8000`nFichier .env invalide (commentaire sans #) : blocage PostgreSQL - corrige`nRole client/mecanicien desynchronise : correction session_role`nUI surchargee : barre recherche + filtres dans bottom sheet`nRelance Flutter : scripts stop-flutter-web + wait port"
    }
    @{
        Layout = 2
        Title = "V - DEMONSTRATION"
        Body = "1. Demarrer Laravel : php artisan serve --port=8000`n2. Lancer l'app : cd frontend puis .\flutter_run.ps1`n3. Connexion client -> carte -> filtres -> choisir mecanicien`n4. Creer une demande (vehicule, probleme, photo)`n5. Connexion mecanicien -> accepter demande -> chat`n6. Verifier en base : scripts\verify-postgres.ps1"
    }
    @{
        Layout = 2
        Title = "V - DEMONSTRATION (ecrans cles)"
        Body = "Client : carte, recherche, feuille mecaniciens proches, nouvelle demande`nMecanicien : zone d'intervention, demandes entrantes, statut en ligne`nAPI : http://127.0.0.1:8000/api/health/ready`nWeb : http://localhost:53100`n`nCaptures d'ecran a integrer lors de la soutenance"
    }
    @{
        Layout = 2
        Title = "VI - CONCLUSION"
        Body = "MechAssist repond a la problematique de mise en relation rapide client-mecanicien`nSolution technique viable : Flutter + Laravel + PostgreSQL`nBase locale operationnelle et donnees persistees en PostgreSQL`n`nPerspectives : paiement mobile, PostGIS avance, app iOS, deploiement cloud"
    }
    @{
        Layout = 2
        Title = "VI - CONCLUSION (suite)"
        Body = "Merci pour votre attention.`n`nQuestions ?`n`nGitHub : github.com/jojoskino/Mechassist`nEquipe Groupe 12 - UCAO-UUT"
    }
)

$ppt = $null
$pres = $null
try {
    $ppt = New-Object -ComObject PowerPoint.Application
    $pres = $ppt.Presentations.Add()

    foreach ($s in $slides) {
        $slide = $pres.Slides.Add($pres.Slides.Count + 1, $s.Layout)
        try {
            $slide.Shapes.Title.TextFrame.TextRange.Text = $s.Title
        } catch { }
        $bodyAdded = $false
        foreach ($shape in @($slide.Shapes)) {
            try {
                if ($shape.HasTextFrame -and $shape.TextFrame.HasText -eq $false -and $shape.Name -ne $slide.Shapes.Title.Name) {
                    $shape.TextFrame.TextRange.Text = $s.Body
                    $shape.TextFrame.TextRange.Font.Size = 18
                    $bodyAdded = $true
                    break
                }
            } catch { }
        }
        if (-not $bodyAdded) {
            $box = $slide.Shapes.AddTextbox(1, 50, 120, 620, 380)
            $box.TextFrame.TextRange.Text = $s.Body
            $box.TextFrame.TextRange.Font.Size = 18
        }
    }

    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    $pres.SaveAs($outPath)
    Write-Host "Presentation creee : $outPath" -ForegroundColor Green
}
finally {
    if ($pres) { $pres.Close() | Out-Null }
    if ($ppt) { $ppt.Quit() | Out-Null; [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null }
}
