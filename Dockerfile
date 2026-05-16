# ─────────────────────────────────────────────
# Stage 1: Download PaperMC JAR
# ─────────────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS builder

ARG PAPER_VERSION=1.21.4
ARG PAPER_BUILD=latest

WORKDIR /build

RUN apk add --no-cache curl jq

RUN set -eux; \
    if [ "${PAPER_BUILD}" = "latest" ]; then \
        PAPER_BUILD=$(curl -fsSL \
            "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds" \
            | jq -r '.builds[-1].build'); \
    fi; \
    echo "Downloading PaperMC ${PAPER_VERSION} build ${PAPER_BUILD}..."; \
    curl -fsSL -o paper.jar \
        "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${PAPER_BUILD}/downloads/paper-${PAPER_VERSION}-${PAPER_BUILD}.jar"

# ─────────────────────────────────────────────
# Stage 2: Runtime image
# ─────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="lsgadminlab" \
      org.opencontainers.image.title="PaperMC" \
      org.opencontainers.image.version="1.21.4" \
      org.opencontainers.image.source="https://github.com/lsgadminlab/PaperMC-K8s-Resources"

ENV MC_RAM_MIN=1G \
    MC_RAM_MAX=4G \
    MC_EXTRA_OPTS=""

RUN addgroup -S minecraft && adduser -S minecraft -G minecraft

WORKDIR /server

COPY --from=builder /build/paper.jar paper.jar

RUN echo "eula=true" > eula.txt

COPY --chown=minecraft:minecraft . .

RUN chown -R minecraft:minecraft /server

USER minecraft

EXPOSE 25565

ENTRYPOINT ["sh", "-c", \
    "exec java \
        -Xms${MC_RAM_MIN} \
        -Xmx${MC_RAM_MAX} \
        -XX:+UseG1GC \
        -XX:+ParallelRefProcEnabled \
        -XX:MaxGCPauseMillis=200 \
        -XX:+UnlockExperimentalVMOptions \
        -XX:+DisableExplicitGC \
        -XX:+AlwaysPreTouch \
        -XX:G1NewSizePercent=30 \
        -XX:G1MaxNewSizePercent=40 \
        -XX:G1HeapRegionSize=8M \
        -XX:G1ReservePercent=20 \
        -XX:G1HeapWastePercent=5 \
        -XX:G1MixedGCCountTarget=4 \
        -XX:InitiatingHeapOccupancyPercent=15 \
        -XX:G1MixedGCLiveThresholdPercent=90 \
        -XX:G1RSetUpdatingPauseTimePercent=5 \
        -XX:SurvivorRatio=32 \
        -XX:+PerfDisableSharedMem \
        -XX:MaxTenuringThreshold=1 \
        ${MC_EXTRA_OPTS} \
        -jar paper.jar \
        --nogui"]
