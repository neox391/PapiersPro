# PapiersPro

Application iOS (SwiftUI, iOS 17+) qui génère les documents administratifs d'un métier, prêts à imprimer : devis, facture, contrat de prestation, attestation, bon de commande, fiche d'intervention, reçu.

> Les modèles sont fournis à titre indicatif et ne remplacent pas un conseil juridique.

## Fonctionnalités

- **Onboarding** : choix du métier (artisan du bâtiment, coiffeur/esthéticienne, auto-entrepreneur, restaurateur, chauffeur VTC, photographe, développeur freelance, commerçant) et du pays (France, Belgique, Suisse, Québec), puis saisie unique des infos entreprise (nom, adresse, SIRET/BCE/IDE/NEQ, TVA, IBAN, logo).
- **Accueil** : documents disponibles pour le métier, compteur de documents gratuits, documents récents.
- **Éditeur** : formulaire limité aux champs utiles au métier, au pays et au type de document (client, lignes, TVA/TPS-TVQ, délai de paiement, conditions…), mentions légales ajoutées automatiquement, aperçu A4 mis à jour en direct.
- **Actions** : Imprimer (AirPrint), Exporter en PDF (Fichiers), Partager (Mail, WhatsApp, Messages…).
- **Historique** : recherche, filtres, modifier, dupliquer, transformer un devis en facture ; numérotation automatique `FAC-2026-0001`, `DEV-2026-0001`…
- **Monétisation** (StoreKit 2) : 3 documents gratuits par mois, puis abonnement mensuel « PapiersPro Illimité » (documents illimités, logo personnalisé, tous les métiers).
- Interface en français, thème clair / sombre / système.

## Structure

```
PapiersPro/
  App/          Point d'entrée, navigation
  Models/       Métiers, pays (taux de taxes), types de documents, données
  Rules/        Moteur de règles : champs affichés, totaux, mentions légales
  Services/     Stockage local (JSON), StoreKit 2, export PDF / impression
  Views/        Onboarding, Accueil, Éditeur, Aperçu A4, Historique, Réglages, Paywall
  Resources/    Assets, configuration StoreKit de test
PapiersProTests/  Tests unitaires (taxes, mentions, numérotation, quota)
```

## Compiler

Prérequis : macOS avec Xcode 15+ et [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open PapiersPro.xcodeproj
```

Le schéma utilise `PapiersPro/Resources/PapiersPro.storekit` pour tester l'abonnement dans le simulateur sans App Store Connect. Avant publication, créez le produit `com.papierspro.app.unlimited.monthly` dans App Store Connect et renseignez votre `DEVELOPMENT_TEAM` dans `project.yml`.

## Tests

```sh
xcodebuild test -scheme PapiersPro -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Avertissement

Les règles (taux, mentions obligatoires) couvrent les cas courants en France, Belgique, Suisse et Québec mais doivent être validées par un professionnel (expert-comptable, juriste) avant une utilisation commerciale.
