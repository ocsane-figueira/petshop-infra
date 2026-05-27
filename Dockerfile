FROM kong:3.4.0-ubuntu

USER root
RUN mkdir -p /kong/declarative && chown -R kong:kong /kong/declarative

COPY .kong/kong.yml /kong/declarative/kong.yml

ENV KONG_DATABASE=off
ENV KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yml

# --- CONFIGURAÇÕES DE OTIMIZAÇÃO PARA O RENDER (Limitar RAM) ---
ENV KONG_NGINX_WORKER_PROCESSES=1
ENV KONG_MEM_CACHE_SIZE=128m

# Logs
ENV KONG_PROXY_ACCESS_LOG=/dev/stdout
ENV KONG_PROXY_ERROR_LOG=/dev/stderr
ENV KONG_ADMIN_ACCESS_LOG=/dev/stdout
ENV KONG_ADMIN_ERROR_LOG=/dev/stderr

# Portas
ENV KONG_PROXY_LISTEN="0.0.0.0:8000"
EXPOSE 8000

USER kong