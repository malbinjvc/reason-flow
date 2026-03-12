FROM alpine:3.20 AS builder

RUN apk add --no-cache curl tar xz

RUN curl -L https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar -xJ -C /opt && \
    ln -s /opt/zig-linux-x86_64-0.15.2/zig /usr/local/bin/zig

WORKDIR /app
COPY src/ src/
COPY build.zig .
COPY build.zig.zon .

RUN zig build -Doptimize=ReleaseSafe

FROM alpine:3.20

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=builder /app/zig-out/bin/reason-flow /app/reason-flow
RUN chown -R appuser:appgroup /app

USER appuser

ENTRYPOINT ["/app/reason-flow"]
CMD ["health"]
