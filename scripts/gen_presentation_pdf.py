"""Génère docs/Presentation_MechAssist.pdf (texte simple, français)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "Presentation_MechAssist.pdf"
FONT_DIR = Path(r"C:\Windows\Fonts")


def main() -> int:
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
        from reportlab.lib.units import cm
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont
        from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
        from reportlab.lib import colors
    except ImportError:
        print("Installez reportlab : pip install reportlab", file=sys.stderr)
        return 1

    arial = FONT_DIR / "arial.ttf"
    arial_bold = FONT_DIR / "arialbd.ttf"
    if not arial.exists():
        print(f"Police introuvable : {arial}", file=sys.stderr)
        return 1

    pdfmetrics.registerFont(TTFont("Arial", str(arial)))
    if arial_bold.exists():
        pdfmetrics.registerFont(TTFont("ArialBd", str(arial_bold)))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=2 * cm,
        rightMargin=2 * cm,
        topMargin=1.8 * cm,
        bottomMargin=1.8 * cm,
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "T",
        parent=styles["Heading1"],
        fontName="ArialBd" if arial_bold.exists() else "Arial",
        fontSize=18,
        leading=22,
        spaceAfter=12,
    )
    h2_style = ParagraphStyle(
        "H2",
        parent=styles["Heading2"],
        fontName="ArialBd" if arial_bold.exists() else "Arial",
        fontSize=13,
        leading=17,
        spaceBefore=14,
        spaceAfter=8,
    )
    body_style = ParagraphStyle(
        "B",
        parent=styles["Normal"],
        fontName="Arial",
        fontSize=11,
        leading=15,
        spaceAfter=8,
    )
    small_style = ParagraphStyle(
        "S",
        parent=body_style,
        fontSize=9,
        textColor=colors.grey,
        spaceBefore=16,
    )

    story: list = []

    story.append(Paragraph("MechAssist — Présentation simple", title_style))
    story.append(
        Paragraph(
            "<b>Une application pour connecter les automobilistes en panne aux mécaniciens à proximité.</b>",
            body_style,
        )
    )
    story.append(Spacer(1, 0.3 * cm))

    story.append(Paragraph("En deux phrases", h2_style))
    story.append(
        Paragraph(
            "MechAssist aide une personne dont la voiture tombe en panne à <b>trouver rapidement un professionnel</b> "
            "près d’elle, à <b>échanger</b> (messages, photos) et à <b>suivre</b> l’intervention, depuis son téléphone "
            "ou un navigateur web.",
            body_style,
        )
    )

    story.append(Paragraph("À qui ça sert ?", h2_style))
    data = [
        ["Qui ?", "Ce que ça lui apporte"],
        [
            "Conducteur / conductrice",
            "Demande d’aide, carte des mécaniciens autour, chat avec celui qui accepte, historique.",
        ],
        [
            "Mécanicien",
            "Reçoit les demandes, accepte ou refuse, voit où aller, discute avec le client, indique quand c’est terminé.",
        ],
    ]
    t = Table(data, colWidths=[4.2 * cm, 11.3 * cm])
    t.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), "Arial"),
                ("FONTNAME", (0, 0), (-1, 0), "ArialBd" if arial_bold.exists() else "Arial"),
                ("FONTSIZE", (0, 0), (-1, -1), 10),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#e8eef5")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(t)
    story.append(Spacer(1, 0.2 * cm))

    story.append(Paragraph("Comment ça marche ? (sans jargon)", h2_style))
    steps = [
        "Le <b>client</b> ouvre l’application et autorise la <b>position</b> (pour être géolocalisé).",
        "Il voit les <b>mécaniciens disponibles</b> à proximité et envoie une <b>demande</b> (véhicule, problème, photo si besoin).",
        "Un mécanicien <b>accepte</b> la demande : les deux peuvent <b>discuter</b> et <b>s’appeler</b>.",
        "Le mécanicien peut ouvrir l’<b>itinéraire</b> vers le client (navigation dans Google Maps).",
        "Une fois l’intervention faite, la demande peut être <b>clôturée</b> et <b>notée</b>.",
    ]
    for i, s in enumerate(steps, 1):
        story.append(Paragraph(f"{i}. {s}", body_style))

    story.append(Paragraph("Ce que contient le projet sur GitHub", h2_style))
    story.append(
        Paragraph(
            "<b>Backend</b> : le serveur qui enregistre les comptes, les demandes, les messages et les notifications.<br/>"
            "<b>Frontend</b> : l’application mobile et web pour les écrans des clients et des mécaniciens.<br/><br/>"
            "Les deux parties sont synchronisées pour que tout le monde voie les <b>mêmes informations</b>, "
            "avec des mises à jour automatiques.",
            body_style,
        )
    )

    story.append(Paragraph("Pourquoi c’est utile ?", h2_style))
    story.append(
        Paragraph(
            "• <b>Moins de stress</b> en panne : un canal unique au lieu de multiplier appels et SMS.<br/>"
            "• <b>Gain de temps</b> pour le mécanicien : demandes claires, position du client, statut visible.<br/>"
            "• <b>Traçabilité</b> : historique des interventions pour le client.",
            body_style,
        )
    )

    story.append(Paragraph("En résumé", h2_style))
    story.append(
        Paragraph(
            "MechAssist, c’est le <b>lien simple</b> entre une personne coincée au bord de la route et un "
            "<b>professionnel</b> qui peut l’aider, avec carte, messagerie et notifications.",
            body_style,
        )
    )

    story.append(Paragraph("Document à usage présentation — projet MechAssist.", small_style))

    doc.build(story)
    print(f"OK : {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
