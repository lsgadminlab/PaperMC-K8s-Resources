# Multi-stage Dockerfile for building PaperMC with the included Gradle wrapper
# Java 25: builder stage uses OpenJDK 25 to run the Gradle build and collects produced jars
# runtime stage: small OpenJDK 25 runtime image that contains the build artifacts

FROM openjdk:25-jdk-slim AS builder

WORKDIR /workspace

# Copy the full repository into the image
COPY . .

# Install small tools used by the build and artifact collection
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git findutils \
    && rm -rf /var/lib/apt/lists/*

# Ensure the Gradle wrapper is executable
RUN chmod +x ./gradlew

# Allow Gradle/Java to use more memory if available
ENV JAVA_TOOL_OPTIONS="-Xmx2g"

# Run the Gradle build. Use --no-daemon for CI friendliness.
RUN ./gradlew --no-daemon clean build

# Collect any produced jars from modules under their build/libs directories
RUN mkdir -p /workspace/artifacts \
    && find . -type f -path "*/build/libs/*.jar" -exec cp {} /workspace/artifacts/ \;


FROM openjdk:25-jre-slim AS runtime

WORKDIR /opt/app

# Copy artifacts from the builder stage into the runtime image
COPY --from=builder /workspace/artifacts/ /opt/app/

# Default command: show the artifacts and keep the container alive so Jenkins or users
# can copy files out (docker cp) or run the server manually. If you want the container
# to run the server automatically, replace this CMD with the specific jar execution.
CMD ["sh", "-c", "ls -la /opt/app && echo 'Artifacts are in /opt/app' && sleep infinity"]


