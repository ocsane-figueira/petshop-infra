# 🐾 Petshop Microservices Architecture

Bem-vindo ao projeto do Petshop distribuído! Este repositório contém a implementação de uma arquitetura de Microsserviços.

O projeto foi construído utilizando **Java 21**, **Quarkus**, **CQRS (Command Query Responsibility Segregation)**, e **Clean Architecture**, sendo orquestrado via Docker.

---

## 🎯 Objetivo do Projeto

Demonstrar na prática os conceitos avançados de sistemas distribuídos:
1. **Desacoplamento Extremo:** Microsserviços que não compartilham o mesmo banco de dados.
2. **Arquitetura Orientada a Eventos:** Comunicação assíncrona utilizando RabbitMQ.
3. **CQRS:** Separação entre a base de "Escrita" (Command) e a base de "Leitura" (Query).
4. **API Gateway:** Centralização de chamadas e validação de segurança, utilizando Kong.
5. **Containerização "All-in-One":** Capacidade de iniciar todo o ecossistema com um único comando Docker, sem necessidade de dependências locais nas máquinas (Maven ou Java).

---

## 🏗️ Ecossistema de Microsserviços

O projeto é dividido nos seguintes componentes:

1. **`auth-service` (Porta 8081)**
   * **Papel**: Responsável pela autenticação.
   * **Tecnologia**: Quarkus SmallRye JWT. Gera tokens assinados via RSA (Pares de Chaves Pública/Privada).

2. **`registration-service` (Porta 8082)**
   * **Papel**: Lado *Command* (Escrita) do CQRS para Entidades Base.
   * **Responsabilidade**: Cadastrar Clientes e Animais, aplicando validações essenciais (ex: impedir CPF duplicado).
   * **Banco de Dados**: PostgreSQL.
   * **Mensageria**: Emite eventos `ClientCreatedEvent` e `AnimalCreatedEvent` para o RabbitMQ após sucesso no banco.

3. **`appointment-service` (Porta 8083)**
   * **Papel**: Lado *Command* (Escrita) para Agendamentos.
   * **Responsabilidade**: Validar disponibilidade de agenda. Garante que não haja sobreposição de horários de forma global na loja e que um mesmo animal não possua mais de um agendamento futuro ativo.
   * **Banco de Dados**: PostgreSQL.
   * **Mensageria**: Emite o evento `AppointmentScheduledEvent`.

4. **`query-service` (Porta 8084)**
   * **Papel**: Lado *Query* (Leitura) do CQRS.
   * **Responsabilidade**: "Escutar" constantemente as filas do RabbitMQ. Quando eventos chegam, ele constrói e salva "Views" ricas (Desnormalizadas). Exemplo: Junta os dados do Agendamento + Nome do Animal + Nome do Cliente.
   * **Banco de Dados**: MongoDB (NoSQL, focado em leitura rápida e documentos aninhados).

5. **Infraestrutura Extra**
   * **Kong API Gateway (DB-less)**: Porta 8000.
   * **RabbitMQ**: Message Broker (Porta 5672).
   * **Bancos**: PostgreSQL (5432) e MongoDB (27017).

---

## 🧠 Decisões Arquiteturais e o "Por Quê"

Durante o desenvolvimento, as seguintes decisões foram consideradas:

### 1. Ausência de Chaves Estrangeiras (Foreign Keys) entre Serviços
**Decisão:** O `appointment-service` armazena apenas um `Long animalId`, sem ter uma tabela de animais física atrelada.
**Por quê?** Essa decisão é fundamental nos microsserviços. Se um serviço falhar ou mudar de banco, o outro não pode quebrar. Os dados são ligados apenas logicamente.

### 2. Tratamento Global de Exceções (`BusinessExceptionHandler`)
**Decisão:** Usamos `@Provider` para capturar exceções de negócio customizadas (como `TimeOverlapException`).
**Por quê?** Para evitar misturar lógica HTTP dentro da camada de Serviço (Clean Architecture). O serviço apenas lança a exceção Java, e o Handler transforma isso automaticamente em um JSON amigável com HTTP 400 ou 409 (Conflict).

### 3. Padrão Multi-stage no Dockerfile
**Decisão:** Os microsserviços são compilados por um Maven dentro do próprio Docker, e depois o binário é transferido para uma imagem JRE vazia.
**Por quê?** Para atender o requisito de ter um `docker-compose` integrado e isolado. O professor/avaliador não precisa ter Java 21 ou Maven instalado; basta dar `docker-compose up` e a aplicação inteira será construída e ligada a partir do zero.

### 4. Estratégia do MongoDB Desnormalizado no CQRS
**Decisão:** O `query-service` monta um `AppointmentViewDocument` que já possui os nomes formatados do Animal e do Cliente.
**Por quê?** Para performance de leitura (Dashboard). Quando o Frontend pede os agendamentos do dia, o MongoDB não faz nenhuma operação pesada de `JOIN`, ele entrega o dado em custo computacional `O(1)`.

---

## 🚀 Como Rodar o Projeto

É necessário possuir o **Docker** e o **Docker Compose** instalados na sua máquina.

1. Abra o terminal na raiz do projeto (onde está o `docker-compose.yml`).
2. Execute o comando:
   ```bash
   docker-compose up --build -d
   ```
3. Aguarde (a primeira execução fará o download da internet das imagens e bibliotecas do Maven).
4. Verifique no painel do seu Docker Desktop (ou usando `docker ps`) se todos os contêineres subiram.

---

## 🧪 Como Testar o Fluxo (Passo-a-Passo)

Recomendamos usar o Postman ou Insomnia para testar os endpoints REST.

1. **Gere o Token (Auth Service)**
   * Faça um `POST` em `http://localhost:8000/api/auth/login` (Corpo JSON: `{"username": "admin", "password": "admin123"}`). Copie o Token JWT retornado

2. **Crie um Cliente (Registration Service)**
   * Faça um `POST` em `http://localhost:8000/api/clients`
   * Corpo: `{"name": "Ocsane Figueira", "cpf": "12345678900", "email": "ocsane@gmail.com", "phone": "47999999999"}`
   * *Imediatamente após retornar 201 Created, um evento entrará em uma fila no RabbitMQ.*

3. **Crie um Animal (Registration Service)**
   * Faça um `POST` em `http://localhost:8000/api/animals`
   * Corpo: `{"name": "Zeus", "species": "Cachorro", "breed": "Dachshund", "clientId": 1}`

4. **Agende um Serviço (Appointment Service)**
   * Faça um `POST` em `http://localhost:8000/api/appointments`
   * Corpo:
     ```json
     {
       "animalId": 1,
       "type": "BANHO",
       "startTime": "2026-05-10T14:00:00",
       "endTime": "2026-05-10T15:00:00"
     }
     ```

5. **A Prova do CQRS (Query Service)**
   * Agora o teste de fogo: Faça um `GET` no painel de leitura ultra-rápida.
   * `GET http://localhost:8000/api/query/appointments`
   * **Resultado esperado:** O MongoDB vai te devolver o agendamento completo, incluindo as chaves `animalName: "Rex"` e `clientName: "João"`, mesmo que o MongoDB nunca tenha falado diretamente com o Postgres, pois foi tudo sincronizado de forma reativa pelo RabbitMQ.

6. **Consultar Clientes Sincronizados (Query Service)**
   * Faça um `GET` em `http://localhost:8000/api/query/clients`
   * **Resultado esperado:** Retornará a lista de clientes (ex: "João") lida de forma rápida do MongoDB.

7. **Cancelar um Agendamento (Appointment Service)**
   * Faça um `DELETE` em `http://localhost:8000/api/appointments/1` (substitua `1` pelo ID gerado).
   * **A mágica continua:** O evento de cancelamento será processado pelo RabbitMQ. Se você refazer o passo 5, verá que a View do agendamento foi removida do MongoDB de forma automática.
---

## 🧪 Testes Unitários e Cobertura (Jacoco)

O projeto utiliza **JUnit 5**, **Mockito** e **RestAssured** para garantir a qualidade do código. A cobertura é monitorada via **Jacoco**, com uma meta mínima estabelecida de **50%**.

### Como Rodar os Testes

Os testes devem ser executados individualmente para cada microsserviço:
Execute os testes usando o seguinte comando:
```bash
./mvnw clean verify -f [nome-do-servico]/pom.xml
```

### ⚠️ Observação para os Testes Locais

Para executar os testes automatizados dos microsserviços **`appointment-service`** e **`registration-service`** localmente (fora do ambiente Docker), é necessário realizar um pequeno ajuste na configuração para que o Quarkus utilize o banco de testes em memória (Testcontainers).

**Passo a passo:**

1. Navegue até o diretório do serviço desejado.
2. Abra o arquivo de propriedades: `src/main/resources/application.properties`.
3. Comente a linha de configuração da URL do banco de dados principal (adicionando um `#` no início da linha).
   > **Exemplo:** Comente a linha `quarkus.datasource.jdbc.url=...` (localizada na linha 5).
4. Em seguida, execute o comando de verificação na raiz do projeto:

```bash
./mvnw clean verify -f <nome-do-servico>/pom.xml
```

### Como Visualizar os Resultados de Cobertura

Após a execução dos testes, o Quarkus e o Jacoco geram um relatório visual em HTML:

1. O relatório estará em: `[nome-do-servico]/target/jacoco-report/index.html`
2. Localize esse arquivo no seu explorador de arquivos.
3. Abra-o no navegador (Chrome, Edge, Firefox, etc.) para ver os detalhes de cobertura por classe e método.