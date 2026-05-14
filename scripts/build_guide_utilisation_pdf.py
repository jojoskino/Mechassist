#!/usr/bin/env python3
"""Génère docs/GUIDE_UTILISATION_MECHASSIST.pdf (guide utilisateur MechAssist, FR)."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.enums import TA_JUSTIFY, TA_LEFT
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import cm
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.platypus import (
        ListFlowable,
        ListItem,
        PageBreak,
        Paragraph,
        SimpleDocTemplate,
        Spacer,
    )
except ImportError:
    print("Installe reportlab : pip install reportlab", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "GUIDE_UTILISATION_MECHASSIST.pdf"


def _register_font() -> str:
    """Police avec accents FR ; retourne le nom enregistré."""
    candidates = [
        Path(r"C:\Windows\Fonts\arial.ttf"),
        Path(r"C:\Windows\Fonts\calibri.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for p in candidates:
        if p.is_file():
            name = "MechAssistBody"
            pdfmetrics.registerFont(TTFont(name, str(p)))
            return name
    return "Helvetica"


def build_pdf() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    font = _register_font()

    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "T",
        parent=styles["Heading1"],
        fontName=font,
        fontSize=22,
        spaceAfter=14,
        textColor=colors.HexColor("#0F4C75"),
    )
    h1 = ParagraphStyle(
        "H1",
        parent=styles["Heading2"],
        fontName=font,
        fontSize=16,
        spaceBefore=16,
        spaceAfter=10,
        textColor=colors.HexColor("#0F4C75"),
    )
    h2 = ParagraphStyle(
        "H2",
        parent=styles["Heading3"],
        fontName=font,
        fontSize=13,
        spaceBefore=10,
        spaceAfter=6,
        textColor=colors.HexColor("#E85D04"),
    )
    body = ParagraphStyle(
        "B",
        parent=styles["Normal"],
        fontName=font,
        fontSize=10.5,
        leading=14,
        alignment=TA_JUSTIFY,
        spaceAfter=8,
    )
    bullet = ParagraphStyle(
        "Bul",
        parent=body,
        leftIndent=18,
        bulletIndent=8,
        alignment=TA_LEFT,
    )
    small = ParagraphStyle(
        "S",
        parent=body,
        fontSize=9,
        textColor=colors.grey,
    )

    story: list = []

    story.append(Paragraph("MechAssist", title))
    story.append(Paragraph("Guide d&rsquo;utilisation", styles["Heading2"]))
    story.append(Spacer(1, 0.3 * cm))
    story.append(
        Paragraph(
            "Application mobile (Flutter) et API Laravel pour mettre en relation "
            "<b>clients</b> en panne et <b>m&eacute;caniciens</b> disponibles &agrave; proximit&eacute;. "
            "Ce document d&eacute;crit les fonctions principales une fois connect&eacute;.",
            body,
        )
    )
    story.append(Paragraph(f"Document g&eacute;n&eacute;r&eacute; automatiquement. Fichier : {OUT.name}", small))
    story.append(PageBreak())

    # --- Prérequis
    story.append(Paragraph("1. Avant de commencer", h1))
    story.append(
        Paragraph(
            "<b>Serveur API.</b> L&rsquo;application parle &agrave; un backend Laravel. Sur un t&eacute;l&eacute;phone "
            "r&eacute;el, l&rsquo;URL par d&eacute;faut de l&rsquo;&eacute;mulateur ne fonctionne pas : configure "
            "l&rsquo;URL dans l&rsquo;&eacute;cran <b>Aide</b> (m&ecirc;me r&eacute;seau Wi-Fi que le PC, "
            "<i>php artisan serve --host=0.0.0.0</i> sur la machine qui h&eacute;berge l&rsquo;API).",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>Comptes.</b> Tu peux cr&eacute;er un compte <i>client</i> ou <i>m&eacute;canicien</i>, "
            "ou te connecter (e-mail / mot de passe ou Google selon configuration serveur).",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>Localisation.</b> Le client utilise la position pour lister les m&eacute;caniciens proches et "
            "envoyer une demande. Autorise la g&eacute;olocalisation sur l&rsquo;appareil.",
            body,
        )
    )

    # --- Client
    story.append(Paragraph("2. Espace client", h1))
    story.append(Paragraph("2.1 Tableau de bord", h2))
    story.append(
        Paragraph(
            "Deux onglets : <b>Proches</b> (carte et liste des m&eacute;caniciens) et <b>Demandes</b> "
            "(historique de tes interventions).",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>Proches</b> : tu vois la carte, puis les cartes m&eacute;canicien (distance, sp&eacute;cialit&eacute;, "
            "note si disponible). Actions : <b>Appeler</b> ouvre le composeur t&eacute;l&eacute;phonique ; "
            "<b>Demander</b> ouvre le formulaire (v&eacute;hicule, description, adresse optionnelle, photo optionnelle). "
            "Tu peux affiner la recherche (rayon, note minimum, mot-cl&eacute; sp&eacute;cialit&eacute;) puis "
            "<b>Appliquer</b>.",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>Demandes</b> : touche une ligne pour le d&eacute;tail. Statuts courants : en attente, accept&eacute;e, "
            "refus&eacute;e, annul&eacute;e par toi, termin&eacute;e (apr&egrave;s cl&ocirc;ture).",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>Annuler</b> : tant que la demande est <i>en attente</i>, tu peux l&rsquo;annuler (confirmation). "
            "Le m&eacute;canicien re&ccedil;oit une notification.",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>Chat</b> : une fois la demande <b>accept&eacute;e</b>, ouvre la discussion depuis le d&eacute;tail ou "
            "la liste. C&rsquo;est une page d&eacute;di&eacute;e (rafra&icirc;chissement p&eacute;riodique des messages).",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>Cl&ocirc;ture</b> : quand le m&eacute;canicien a indiqu&eacute; l&rsquo;intervention termin&eacute;e, "
            "tu peux cl&ocirc;turer (panne r&eacute;gl&eacute;e ou non), puis <b>noter</b> le m&eacute;canicien si besoin.",
            body,
        )
    )

    # --- Mécano
    story.append(Paragraph("3. Espace m&eacute;canicien", h1))
    story.append(Paragraph("3.1 Disponibilit&eacute; et localisation", h2))
    story.append(
        Paragraph(
            "Active <b>Disponible</b> pour appara&icirc;tre aux clients. L&rsquo;app envoie position et pr&eacute;sence "
            "tant que tu es connect&eacute; (selon permissions GPS).",
            body,
        )
    )
    story.append(Paragraph("3.2 Demandes re&ccedil;ues", h2))
    story.append(
        Paragraph(
            "Liste des demandes qui te concernent. Filtres : toutes, en attente, accept&eacute;es, termin&eacute;es, "
            "refus&eacute;es, annul&eacute;es. Actions typiques : <b>Accepter</b> / <b>Refuser</b> (en attente), "
            "<b>Intervention termin&eacute;e</b> (demande accept&eacute;e), <b>Chat</b> (demande accept&eacute;e), "
            "<b>Appeler le client</b> si un num&eacute;ro est renseign&eacute;.",
            body,
        )
    )

    # --- Profil & compte
    story.append(Paragraph("4. Profil et compte", h1))
    story.append(
        Paragraph(
            "Depuis l&rsquo;ic&ocirc;ne <b>Mon profil</b> (tableaux de bord client ou m&eacute;canicien) : "
            "nom, t&eacute;l&eacute;phone ; pour le m&eacute;canicien : sp&eacute;cialit&eacute;s et interrupteur "
            "<b>Visible comme disponible</b>. L&rsquo;e-mail affich&eacute; n&rsquo;est pas modifiable dans cet &eacute;cran. "
            "Enregistre pour appliquer les changements.",
            body,
        )
    )
    story.append(
        Paragraph(
            "<b>D&eacute;connexion</b> : une confirmation est demand&eacute;e avant d&rsquo;effacer la session locale "
            "et d&rsquo;appeler la d&eacute;connexion serveur.",
            body,
        )
    )

    # --- Notifications
    story.append(Paragraph("5. Notifications (Android)", h1))
    story.append(
        Paragraph(
            "Si Firebase est configur&eacute; c&ocirc;t&eacute; projet et serveur (cl&eacute; FCM, jeton enregistr&eacute;), "
            "tu peux recevoir des alertes (nouvelle demande, message, cl&ocirc;ture, etc.). "
            "Un appui sur une notification locale ouvre l&rsquo;&eacute;cran adapt&eacute; (ex. liste Demandes ou chat) "
            "lorsque tu es d&eacute;j&agrave; connect&eacute;.",
            body,
        )
    )

    # --- Aide
    story.append(Paragraph("6. Aide", h1))
    story.append(
        Paragraph(
            "L&rsquo;&eacute;cran <b>Aide</b> permet de saisir l&rsquo;URL de l&rsquo;API, de tester la connexion "
            "et d&rsquo;acc&eacute;der &agrave; des rappels utiles (t&eacute;l&eacute;phone physique, pare-feu, etc.).",
            body,
        )
    )

    # --- Dépannage
    story.append(Paragraph("7. D&eacute;pannage rapide", h1))
    items = [
        "Carte ou liste vide : v&eacute;rifie l&rsquo;URL API (Aide), le serveur Laravel, le Wi-Fi.",
        "Impossible d&rsquo;appeler : v&eacute;rifie le num&eacute;ro ; sur Android, une app T&eacute;l&eacute;phone doit g&eacute;rer les liens <i>tel:</i>.",
        "Chat en lecture seule : demande non accept&eacute;e, termin&eacute;e ou refus&eacute;e &mdash; c&rsquo;est normal.",
        "Erreur r&eacute;seau ou timeout : serveur &eacute;teint, mauvaise IP, ou pare-feu Windows bloquant le port 8000.",
    ]
    story.append(
        ListFlowable(
            [ListItem(Paragraph(x, bullet)) for x in items],
            bulletType="bullet",
            start="bullet",
        )
    )
    story.append(Spacer(1, 0.5 * cm))
    story.append(
        Paragraph(
            "<i>MechAssist &mdash; guide g&eacute;n&eacute;r&eacute; pour les utilisateurs finaux. "
            "Pour l&rsquo;installation d&eacute;veloppeur, voir README du d&eacute;p&ocirc;t.</i>",
            small,
        )
    )

    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        rightMargin=2 * cm,
        leftMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
        title="MechAssist - Guide d'utilisation",
        author="MechAssist",
    )
    doc.build(story)
    print(f"OK: {OUT}")


if __name__ == "__main__":
    build_pdf()
