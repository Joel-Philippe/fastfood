# --- Étape 1 : Build de l'application Flutter Web ---
FROM debian:stable-slim AS build-env

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    xz-utils \
    libglu1-mesa \
    ca-certificates \
    && apt-get clean

# Création d'un utilisateur non-root pour Flutter
RUN useradd -m -s /bin/bash flutteruser
USER flutteruser
WORKDIR /home/flutteruser

# Installation de Flutter dans le répertoire de l'utilisateur
RUN git clone https://github.com/flutter/flutter.git -b stable /home/flutteruser/flutter
ENV PATH="/home/flutteruser/flutter/bin:/home/flutteruser/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Configuration de Flutter (sans analytics et uniquement pour le web)
RUN flutter config --no-analytics
RUN flutter config --enable-web

# Copie des fichiers du projet
WORKDIR /home/flutteruser/app
COPY --chown=flutteruser:flutteruser . .

# Création d'un fichier .env vide pour satisfaire pubspec.yaml sans exposer de secrets
RUN touch .env

# Installation des dépendances et build
RUN flutter pub get
RUN flutter build web --release

# --- Étape 2 : Runtime Node.js pour le Backend ---
FROM node:18-slim

WORKDIR /app

# Copie des fichiers compilés du frontend
COPY --from=build-env /home/flutteruser/app/build/web ./build/web

# Copie du backend
COPY ./backend ./backend

# Installation des dépendances du backend
WORKDIR /app/backend
RUN npm install --production

# Exposition du port
EXPOSE 10000

# Commande de démarrage
CMD ["node", "server.js"]
