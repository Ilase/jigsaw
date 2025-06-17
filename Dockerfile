# 1. Сборка приложения
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .

# Скачиваем objectbox lib (после того, как исходники на месте!)
RUN curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh -o install.sh && \
    bash install.sh && \
    rm install.sh
RUN dart pub run build_runner build --delete-conflicting-outputs

RUN dart compile exe bin/jigsaw.dart -o bin/server

# 2. Финальный образ на Alpine
FROM alpine:3.19

# Устанавливаем необходимые библиотеки для запуска objectbox.so
RUN apk add --no-cache libstdc++ bash

WORKDIR /app

# Копируем собранное приложение и зависимости
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/
COPY --from=build /app/lib/libobjectbox.so /app/lib/
COPY --from=build /app/config/config.json /app/config/

# (опционально) для отладки:
RUN ls -l /app/lib/

EXPOSE 80
ENTRYPOINT ["/app/bin/server"]
