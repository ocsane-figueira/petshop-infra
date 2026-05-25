# Usa a imagem oficial do Kong (versão baseada em Ubuntu)
FROM kong:3.4.0-ubuntu

# Muda para o usuário root temporariamente para criar pastas e dar permissões
USER root
RUN mkdir -p /kong/declarative && chown -R kong:kong /kong/declarative

# Copia o seu arquivo de rotas (kong.yml) para dentro do contêiner
# ATENÇÃO: Se o seu arquivo estiver solto na raiz do projeto, use: COPY kong.yml /kong/declarative/kong.yml
# Se estiver dentro da pasta .kong, deixe como abaixo:
COPY .kong/kong.yml /kong/declarative/kong.yml

# Configura o Kong para rodar no modo DB-less (sem precisar de um banco de dados próprio para ele)
ENV KONG_DATABASE=off
ENV KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yml

# Redireciona os logs para a saída padrão (Isso é essencial para você ver os logs lá no painel do Render depois)
ENV KONG_PROXY_ACCESS_LOG=/dev/stdout
ENV KONG_PROXY_ERROR_LOG=/dev/stderr
ENV KONG_ADMIN_ACCESS_LOG=/dev/stdout
ENV KONG_ADMIN_ERROR_LOG=/dev/stderr

# Define a porta que o Kong vai escutar (o Render exige que a aplicação escute no 0.0.0.0)
ENV KONG_PROXY_LISTEN="0.0.0.0:8000"

# Expõe a porta 8000 (onde as requisições do frontend/postman vão bater)
EXPOSE 8000

# Volta para o usuário seguro do Kong para rodar a aplicação
USER kong