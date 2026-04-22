FROM debian:stable-slim AS build

ARG FLUTTER_VERSION=3.41.6

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    xz-utils \
    zip \
    git \
    ca-certificates \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    | tar -xJ

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN git config --global --add safe.directory /opt/flutter
RUN flutter --disable-analytics
RUN flutter config --enable-web

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:alpine

ENV PORT=10000

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 10000

CMD ["/bin/sh", "-c", "mkdir -p /usr/share/nginx/html/assets/config && printf '{\\n  \"FIREBASE_API_KEY\": \"%s\",\\n  \"FIREBASE_APP_ID\": \"%s\",\\n  \"FIREBASE_MESSAGING_SENDER_ID\": \"%s\",\\n  \"FIREBASE_PROJECT_ID\": \"%s\",\\n  \"FIREBASE_AUTH_DOMAIN\": \"%s\",\\n  \"FIREBASE_STORAGE_BUCKET\": \"%s\"\\n}\\n' \"${FIREBASE_API_KEY:-}\" \"${FIREBASE_APP_ID:-}\" \"${FIREBASE_MESSAGING_SENDER_ID:-}\" \"${FIREBASE_PROJECT_ID:-}\" \"${FIREBASE_AUTH_DOMAIN:-}\" \"${FIREBASE_STORAGE_BUCKET:-}\" > /usr/share/nginx/html/assets/config/firebase_config.json && exec nginx -g 'daemon off;'"]
