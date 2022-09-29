FROM ghcr.io/evanrichter/cargo-fuzz as builder

ADD . /kcp
WORKDIR /kcp/fuzz
RUN cargo +nightly fuzz build 

FROM debian:bookworm
COPY --from=builder /kcp/fuzz/target/x86_64-unknown-linux-gnu/release/kcp-fuzz /