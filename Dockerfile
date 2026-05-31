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
RUN cat <<EOF | tee /server/config/paper-global.yml \
_version: 29 \
block-updates: \
  disable-chorus-plant-updates: false \
  disable-mushroom-block-updates: false \
  disable-noteblock-updates: false \
  disable-tripwire-updates: false \
chunk-loading-advanced: \
  auto-config-send-distance: true \
  player-max-concurrent-chunk-generates: 0 \
  player-max-concurrent-chunk-loads: 0 \
chunk-loading-basic: \
  player-max-chunk-generate-rate: -1.0 \
  player-max-chunk-load-rate: 100.0 \
  player-max-chunk-send-rate: 75.0 \
chunk-system: \
  gen-parallelism: default \
  io-threads: -1 \
  worker-threads: -1 \
collisions: \
  enable-player-collisions: true \
  send-full-pos-for-hard-colliding-entities: true \
commands: \
  fix-target-selector-tag-completion: true \
  suggest-player-names-when-null-tab-completions: true \
  time-command-affects-all-worlds: false \
console: \
  enable-brigadier-completions: true \
  enable-brigadier-highlighting: true \
  has-all-permissions: false \
item-validation: \
  book: \
    author: 8192 \
    page: 16384 \
    title: 8192 \
  book-size: \
    page-max: 2560 \
    total-multiplier: 0.98 \
  display-name: 8192 \
  lore-line: 8192 \
  resolve-selectors-in-books: false \
logging: \
  deobfuscate-stacktraces: true \
messages: \
  kick: \
    authentication-servers-down: <lang:multiplayer.disconnect.authservers_down> \
    connection-throttle: Connection throttled! Please wait before reconnecting. \
    flying-player: <lang:multiplayer.disconnect.flying> \
    flying-vehicle: <lang:multiplayer.disconnect.flying> \
  no-permission: <red>Im sorry, but you do not have permission to perform this command. \
    Please contact the server administrators if you believe that this is in error. \
  use-display-name-in-quit-message: false \
misc: \
  chat-threads: \
    chat-executor-core-size: -1 \
    chat-executor-max-size: -1 \
  client-interaction-leniency-distance: default \
  compression-level: default \
  fix-entity-position-desync: true \
  load-permissions-yml-before-plugins: true \
  max-joins-per-tick: 5 \
  region-file-cache-size: 256 \
  strict-advancement-dimension-check: false \
  use-alternative-luck-formula: false \
  use-dimension-type-for-custom-spawners: false \
packet-limiter: \
  all-packets: \
    action: KICK \
    interval: 7.0 \
    max-packet-rate: 500.0 \
  kick-message: <red><lang:disconnect.exceeded_packet_rate> \
  overrides: \
    ServerboundPlaceRecipePacket: \
      action: DROP \
      interval: 4.0 \
      max-packet-rate: 5.0 \
player-auto-save: \
  max-per-tick: -1 \
  rate: -1 \
proxies: \
  bungee-cord: \
    online-mode: true \
  proxy-protocol: false \
  velocity: \
    enabled: true \
    online-mode: true \
    secret: dj463M9FFnNRpkq3Y4NfvXAtE3gPQGtnBGCLcWNo9JSbM4pW4zJ6dXwFUgvSqdeX \
scoreboards: \
  save-empty-scoreboard-teams: true \
  track-plugin-scoreboards: false \
spam-limiter: \
  incoming-packet-threshold: 300 \
  recipe-spam-increment: 1 \
  recipe-spam-limit: 20 \
  tab-spam-increment: 1 \
  tab-spam-limit: 500 \
spark: \
  enable-immediately: false \
  enabled: true \
timings: \
  enabled: false \
  hidden-config-entries: \
  - database \
  - proxies.velocity.secret \
  history-interval: 300 \
  history-length: 3600 \
  server-name: Unknown Server \
  server-name-privacy: false \
  url: https://timings.aikar.co/ \
  verbose: true \
unsupported-settings: \
  allow-headless-pistons: false \
  allow-permanent-block-break-exploits: false \
  allow-piston-duplication: false \
  allow-tripwire-disarming-exploits: false \
  allow-unsafe-end-portal-teleportation: false \
  compression-format: ZLIB \
  perform-username-validation: true \
  simplify-remote-item-matching: false \
  skip-vanilla-damage-tick-when-shield-blocked: false \
watchdog: \
  early-warning-delay: 10000 \
  early-warning-every: 5000 \
 \
EOF

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
