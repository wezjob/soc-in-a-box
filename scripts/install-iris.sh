#!/bin/bash
# ============================================================================
# IRIS DFIR Installation Script
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IRIS_DIR="$PROJECT_DIR/iris"

echo "========================================"
echo "  IRIS DFIR Installation"
echo "========================================"

# Vérifier que Docker est disponible
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

# Créer le réseau si nécessaire
echo "📡 Vérification du réseau Docker..."
if ! docker network ls | grep -q labsoc-network; then
    echo "  Création du réseau labsoc-network..."
    docker network create labsoc-network
fi

# Télécharger les images
echo ""
echo "📥 Téléchargement des images IRIS..."
cd "$IRIS_DIR"
docker compose pull

# Démarrer IRIS
echo ""
echo "🚀 Démarrage d'IRIS DFIR..."
docker compose up -d

# Attendre que les services soient prêts
echo ""
echo "⏳ Attente du démarrage des services..."
sleep 30

# Vérifier l'état
echo ""
echo "📊 État des services IRIS:"
docker compose ps

echo ""
echo "========================================"
echo "  ✅ IRIS DFIR Installé avec succès!"
echo "========================================"
echo ""
echo "🌐 Accès IRIS:"
echo "   URL: https://localhost:8443"
echo "   Alt: https://localhost:8444"
echo ""
echo "👤 Identifiants par défaut:"
echo "   Username: administrator"
echo "   Password: IrisAdmin2026!"
echo ""
echo "📖 Documentation: https://docs.dfir-iris.org/"
echo ""
