FROM debian:stable-slim AS build

RUN apt-get update && apt-get install -y \
    curl unzip xz-utils zip git ca-certificates libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.35.7-stable.tar.xz \
    | tar -xJ

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter config --enable-web
RUN flutter doctor -v

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 10000
CMD ["nginx", "-g", "daemon off;"]