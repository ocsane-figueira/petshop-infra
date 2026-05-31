# 🐾 Petshop Distributed System — Arquitetura Global e Infraestrutura

Bem-vindo à documentação central da arquitetura distribuída do **Petshop**! Este repositório (`petshop-infra`) serve como o **hub central de infraestrutura** e o manual operacional global do ecossistema. 

Anteriormente estruturado como um monolito dockerizado local, o projeto foi completamente refatorado em um ecossistema **Multirrepo de Microsserviços**, com pipelines modernos de **CI/CD** automatizados e **Observabilidade centralizada** na nuvem.

---

## 🏗️ Evolução da Arquitetura: Monolito ➡️ Multirrepo

A transição para multirrepo teve como objetivos principais:
1. **Desacoplamento Extremo**: Ciclos de desenvolvimento e de entrega completamente independentes.
2. **Escalabilidade Isolada**: Serviços críticos de escrita ou leitura podem ser escalados de forma independente.
3. **Segregação Física de Dados**: Nenhuma base de dados é compartilhada diretamente entre microsserviços.
4. **Resiliência Arquitetural**: Falhas em um microsserviço de escrita não impedem a leitura ou a autenticação de funcionar.

### Diagrama de Fluxo e Componentes Globais

O ecossistema é orquestrado sob o padrão **CQRS** (Command Query Responsibility Segregation) assíncrono mediado por eventos:

```mermaid
flowchart TD
    Client((Cliente / API Consumer)) -->|HTTP Request| Gateway[Kong API Gateway]
    
    subgraph Gateway Routing
        Gateway -->|/api/auth/*| AuthSvc[auth-service]
        Gateway -->|/api/clients/* & /api/animals/*| RegSvc[registration-service]
        Gateway -->|/api/appointments/*| ApptSvc[appointment-service]
        Gateway -->|/api/query/*| QuerySvc[query-service]
    end

    subgraph Write Domain (Commands)
        RegSvc -->|PostgreSQL Schema: registration_db| DB_Reg[(PostgreSQL)]
        ApptSvc -->|PostgreSQL Schema: appointment_db| DB_Appt[(PostgreSQL)]
    end

    subgraph Event Broker
        RegSvc -->|Publish Event| RabbitMQ{RabbitMQ Message Broker}
        ApptSvc -->|Publish Event| RabbitMQ
    end

    subgraph Read Domain (Queries)
        RabbitMQ -->|Consume Event| QuerySvc
        QuerySvc -->|MongoDB Collection: views| DB_Query[(MongoDB NoSQL)]
    end

    subgraph Observabilidade
        Prometheus[Prometheus Scraper] -->|Scrape /q/metrics| AuthSvc
        Prometheus -->|Scrape /q/metrics| RegSvc
        Prometheus -->|Scrape /q/metrics| ApptSvc
        Prometheus -->|Scrape /q/metrics| QuerySvc
        Prometheus -->|Remote Write / Basic Auth| Grafana[Grafana Cloud Dashboard]
    end
```

---

## 🗂️ Inventário de Repositórios e Serviços

O ecossistema é composto por **5 repositórios independentes**:

1. **[petshop-infra]** *(Este Repositório)*
   * **Papel**: Centralização de infraestrutura local (Docker Compose), gateway de desenvolvimento (Kong) e templates de coleta de métricas (Prometheus).
   * **Hospedagem Render**: `petshop-infra` (Prod) & `petshop-infra-dev` (Dev) — Kong DB-less.

2. **[petshop-auth-service]**
   * **Papel**: Autenticação e Emissão de Tokens JWT auto-contidos com criptografia RSA (Pares de chaves pública e privada).
   * **Porta Local**: `8081` | **Hospedagem Render**: `petshop-auth-service` & `petshop-auth-service-dev`.

3. **[petshop-registration-service]**
   * **Papel**: Domínio de Escrita (*Command*) de Clientes e Animais.
   * **Tecnologias**: Quarkus, Hibernate ORM com Panache, PostgreSQL.
   * **Mensageria**: Emite `ClientCreatedEvent` e `AnimalCreatedEvent` para as exchanges do RabbitMQ.
   * **Porta Local**: `8082` | **Hospedagem Render**: `petshop-registration-service` & `petshop-registration-service-dev`.

4. **[petshop-appointment-service]**
   * **Papel**: Domínio de Escrita (*Command*) de Agendamentos. Contém regras rígidas de validação de negócios (sobreposição de horário global de loja, unicidade de agendamento futuro ativo por pet).
   * **Tecnologias**: Quarkus, PostgreSQL.
   * **Mensageria**: Emite `AppointmentScheduledEvent` e `AppointmentCancelledEvent` para o RabbitMQ.
   * **Porta Local**: `8083` | **Hospedagem Render**: `petshop-appointment-service` & `petshop-appointment-service-dev`.

5. **[petshop-query-service]**
   * **Papel**: Domínio de Leitura (*Query*). Consome em tempo real os eventos das filas do RabbitMQ e consolida Views desnormalizadas e ricas para consultas de alta performance instantânea.
   * **Tecnologias**: Quarkus, MongoDB (NoSQL ideal para armazenamento de estruturas de documentos aninhadas).
   * **Porta Local**: `8084` | **Hospedagem Render**: `petshop-query-service` & `petshop-query-service-dev`.

---

## 🚀 Análise Técnica de CI/CD (Integração e Entrega Contínua)

Cada repositório de microsserviço possui uma estrutura moderna e automatizada de pipelines construída no GitHub Actions:

```
[Push/PR] ➡️ [CI Pipeline] ➡️ [SonarCloud Analysis] ➡️ [Docker Hub Build & Push (main)] ➡️ [CD Pipeline (Trigger)] ➡️ [Render Deploy Webhooks]
```

### 1. Fluxo de Continuous Integration (CI)
* **Gatilho**: Qualquer `push` ou `pull_request` nas branches `main` e `develop`.
* **Ambiente**: Máquina virtual Ubuntu executando JDK 21 (Temurin) com cache inteligente do Maven habilitado.
* **Validação**: Execução completa dos testes automatizados via `mvn clean verify`.
* **Análise de Qualidade (SonarCloud)**: Integração profunda com o SonarCloud para análise estática e controle de cobertura de código (Project Key: `ocsane-figueira_petshop-<servico>`).

### 2. Versionamento e Liberação Automatizada (Semantic Release)
* Executado exclusivamente na branch `main` após sucesso no pipeline de CI.
* Utiliza a especificação de **Conventional Commits** para analisar mensagens de commit, calcular automaticamente o próximo incremento SemVer (Patch, Minor ou Major), gerar notas de release e criar tags de versão correspondentes diretamente no GitHub.

### 3. Publicação de Artefatos no Docker Hub
* Após o sucesso dos testes em `main`, o pipeline de CI executa o login seguro no Docker Hub (`username: ocsane`).
* Monta a imagem final baseada no arquivo multi-stage da aplicação e realiza o push automático da nova imagem com tags do hash SHA curto do Git e a tag `main` (`ocsane/petshop-<service-name>`).

### 4. Continuous Deployment (CD) Decoupled
* Para evitar acoplamento no pipeline de testes, criamos um fluxo reativo usando a feature `workflow_run` do GitHub Actions.
* O arquivo `cd.yml` escuta a conclusão do workflow `CI Pipeline`. Caso seja bem-sucedido:
  * Se a branch de origem for `develop`: Executa uma chamada REST segura via `curl` para o **Webhook de Deploy Dev** do Render (`RENDER_DEPLOY_HOOK_DEV`). A infraestrutura correspondente `-dev` no Render puxará o código atualizado e realizará o build automaticamente.
  * Se a branch de origem for `main`: Dispara o deploy de Homologação/Produção no Render usando o webhook principal (`RENDER_DEPLOY_HOOK`).

---

## 📊 Análise da Arquitetura de Observabilidade

Para monitorar os microsserviços sem sobrecarregar a infraestrutura limitada, projetamos uma coleta híbrida com envio centralizado de métricas:

### 1. Exposição de Métricas nos Microsserviços
Cada microsserviço Java foi equipado com a extensão **Quarkus Micrometer** e o registro do Prometheus.
* **Endpoint**: `/q/metrics` expõe em formato aberto métricas detalhadas da JVM (Heap, CPU, GC, Threads) e da camada HTTP/Bancos de Dados.
* **API Gateway (Kong)**: Expõe no endpoint `/metrics` latências de tráfego, contagens de requisições por rota e códigos HTTP.

### 2. Prometheus Collector (Hospedado no Render)
O serviço `petshop-infra-prometheus` roda o container oficial do Prometheus com uma estratégia leve:
* **Finalidade**: O Prometheus não armazena os dados localmente em volumes pesados na nuvem. Ele atua como um **agente coletor reativo**.
* **Templates Dinâmicos**: O arquivo [prometheus.yml](file:///c:/Users/willi/Documents/Devops%20oc/petshop/infra/prometheus/prometheus.yml) possui seções declarativas separadas para coletar dados dos targets de **DEV** (`*-dev.onrender.com`) e **HOMOL/PROD** (`*.onrender.com`).
* **Segurança de Segredos**: O `Dockerfile` do Prometheus injeta a variável de ambiente secreta `${GRAFANA_TOKEN}` em tempo de execução via comando `sed` sobre um arquivo de template, mantendo credenciais seguras fora do controle de versão.

### 3. Grafana Cloud Integration (Push Telemetry)
* **Mecanismo**: Através da diretiva `remote_write` no arquivo de configuração do Prometheus, todas as métricas raspadas a cada 60 segundos dos microsserviços em nuvem são enviadas via protocolo de streaming compactado HTTP/Snappy direto para o endpoint central da nossa conta no **Grafana Cloud**:
  * **Destino**: `https://prometheus-prod-40-prod-sa-east-1.grafana.net/api/prom/push`
  * **Autenticação**: ID de Usuário `3255140` + Token Seguro de Gravação.
* **Resultado**: Dashboards visuais premium e de altíssima performance no Grafana Cloud, com consumo zero de disco nos servidores do Render.

---

## 🛠️ Como Iniciar a Infraestrutura de Suporte Local

Se você deseja desenvolver ou testar microsserviços localmente, não precisa instalar bancos ou filas na sua máquina. O repositório de infraestrutura provê um ambiente completo com Kong, PostgreSQL, MongoDB e RabbitMQ prontos para rodar.

### Requisitos
* Docker
* Docker Compose

### Instruções de Execução

1. Navegue até a pasta `infra` deste repositório.
2. Execute o comando para subir todos os contêineres compartilhados:
   ```bash
   docker compose up -d
   ```
3. Os recursos estarão disponíveis nas seguintes portas locais:
   * **Kong API Gateway**: `http://localhost:8000`
   * **PostgreSQL (Databases de Escrita)**: `localhost:5432` (Credenciais: `petshop` / `petshop`)
   * **MongoDB (Leitura CQRS)**: `localhost:27017`
   * **RabbitMQ Message Broker**: `localhost:5672` (Painel de gerenciamento em `http://localhost:15672`)

---

## 🧪 Roteiro de Teste End-to-End (E2E) via API Gateway

Você pode testar todo o fluxo CQRS distribuído disparando as chamadas de API através do gateway Kong configurado. O mesmo roteiro de testes pode ser executado localmente ou nas nuvens do Render, bastando alterar a **URL base** das requisições.

### 🌐 Ambientes Disponíveis e URLs Base

Para facilitar os testes em ferramentas como **Postman** ou **Insomnia**, configure uma variável global de ambiente `{{BASE_URL}}` utilizando uma das URLs abaixo:

| Ambiente | Descrição | URL Base (`{{BASE_URL}}`) |
| :--- | :--- | :--- |
| **Local** | Executando via Docker Compose local | `http://localhost:8000` |
| **Desenvolvimento (DEV)** | Ambiente integrado Dev no Render | `https://petshop-infra-dev.onrender.com` |
| **Homologação/Produção (PROD)** | Ambiente estável de produção no Render | `https://petshop-infra.onrender.com` |

---

### 1. Autenticação (Geração de JWT)
* **Método**: `POST`
* **URL**: `{{BASE_URL}}/api/auth/login`
* **JSON Request**:
  ```json
  {
    "username": "admin",
    "password": "admin123"
  }
  ```
* **Resposta Esperada (200 OK)**: Retornará um Token JWT. Copie este token e configure-o como cabeçalho `Authorization: Bearer <TOKEN>` (ou do tipo *Bearer Token* na aba Auth do Postman) para as próximas chamadas.

### 2. Cadastro de Cliente (registration-service)
* **Método**: `POST`
* **URL**: `{{BASE_URL}}/api/clients`
* **Headers**: `Authorization: Bearer <TOKEN>`
* **JSON Request**:
  ```json
  {
    "name": "Ocsane Figueira",
    "cpf": "12345678900",
    "email": "ocsane@gmail.com",
    "phone": "47999999999"
  }
  ```
* **Resposta Esperada (201 Created)**: Retorna a confirmação de criação do cliente com o ID (ex: `1`). *Neste instante, um evento `ClientCreatedEvent` é publicado no RabbitMQ e consumido pelo `query-service`*.

### 3. Cadastro de Animal (registration-service)
* **Método**: `POST`
* **URL**: `{{BASE_URL}}/api/animals`
* **Headers**: `Authorization: Bearer <TOKEN>`
* **JSON Request**:
  ```json
  {
    "name": "Zeus",
    "species": "Cachorro",
    "breed": "Dachshund",
    "clientId": 1
  }
  ```
* **Resposta Esperada (201 Created)**: Retorna o animal registrado associado ao cliente ID. *Neste instante, um evento `AnimalCreatedEvent` é publicado no RabbitMQ*.

### 4. Agendamento de Serviço (appointment-service)
* **Método**: `POST`
* **URL**: `{{BASE_URL}}/api/appointments`
* **Headers**: `Authorization: Bearer <TOKEN>`
* **JSON Request**:
  ```json
  {
    "animalId": 1,
    "type": "BANHO",
    "startTime": "2026-05-10T14:00:00",
    "endTime": "2026-05-10T15:00:00"
  }
  ```
* **Resposta Esperada (201 Created)**: Cria o agendamento caso não existam sobreposições no calendário geral. *Neste instante, um evento `AppointmentScheduledEvent` é publicado e ouvido de forma assíncrona pelo `query-service`*.

### 5. Validação CQRS - Consulta de Agendamentos Consolidados (query-service)
* **Método**: `GET`
* **URL**: `{{BASE_URL}}/api/query/appointments`
* **Headers**: `Authorization: Bearer <TOKEN>`
* **Resposta Esperada (200 OK)**: O `query-service` retorna de maneira instantânea e sem `JOIN` de banco relacional o agendamento completo e consolidado.
* **Exemplo de Retorno Desnormalizado**:
  ```json
  [
    {
      "id": 1,
      "animalId": 1,
      "animalName": "Zeus",
      "clientName": "Ocsane Figueira",
      "type": "BANHO",
      "startTime": "2026-05-10T14:00:00",
      "endTime": "2026-05-10T15:00:00"
    }
  ]
  ```
  *(Isso prova o sucesso da sincronização via RabbitMQ e a robustez do padrão CQRS!)*