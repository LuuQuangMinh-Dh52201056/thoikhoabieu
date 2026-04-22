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
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.d/10-runtime-config.sh /docker-entrypoint.d/10-runtime-config.sh
RUN chmod +x /docker-entrypoint.d/10-runtime-config.sh

EXPOSE 10000

CMD ["nginx", "-g", "daemon off;"]
