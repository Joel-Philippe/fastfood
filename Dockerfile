# --- Étape 1 : Build de l'application Flutter Web ---
FROM debian:stable-slim AS build-env

# Installation des dépendances système nécessaires à Flutter
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    xz-utils \
    libglu1-mesa \
    ca-certificates \
    && apt-get clean

# Installation de Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Configuration de Flutter (on désactive les analytics pour éviter les blocages)
RUN flutter config --no-analytics
RUN flutter config --enable-web

# Copie des fichiers du projet et build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release

# --- Étape 2 : Runtime Node.js pour le Backend ---
FROM node:18-slim
...
WORKDIR /app

# Copie des fichiers compilés du frontend depuis l'étape 1
COPY --from=build-env /app/build/web ./build/web

# Copie du backend
COPY --from=build-env /app/backend ./backend

# Installation des dépendances du backend
WORKDIR /app/backend
RUN npm install --production

# Exposition du port (Render utilise généralement 10000)
EXPOSE 10000

# Commande de démarrage
CMD ["node", "server.js"]
