# Guia para Agentes de IA - Sistema Supervisório Hídrico (aguadaPy)

Este documento fornece o contexto essencial para trabalhar no projeto `aguadaPy`. O sistema monitora e gerencia uma rede hídrica usando sensores IoT, um backend em Python, um banco de dados PostgreSQL e um frontend para visualização.

## 1. Arquitetura "Big Picture"

O sistema é dividido em quatro componentes principais, orquestrados com `docker-compose.yml`:

1.  **`frontend/`**: Aplicação de visualização (HTML/JS/CSS vanilla) que consome a API do backend. Exibe o mapa interativo, dashboards e tabelas de configuração.
2.  **`backend/` (Python/FastAPI)**: O cérebro do sistema.
    *   Recebe dados dos sensores IoT.
    *   Processa e armazena os dados no banco de dados.
    *   Expõe uma API REST para o frontend.
    *   Localizado em `backend/src/main.py`.
3.  **`database/` (PostgreSQL)**: Armazena todos os dados.
    *   **`schema.sql`** é a fonte da verdade para a estrutura do banco de dados. Contém a lógica de negócio principal.
    *   Utiliza um esquema de compressão inteligente para reduzir o volume de dados.
4.  **`firmware/`**: Código para os microcontroladores (ESP32, Arduino) que coletam os dados dos sensores.
    *   Os firmwares se comunicam com o endpoint `/api/leituras` do backend.

## 2. Fluxo de Dados Crítico: Da Leitura à Visualização

Entender este fluxo é fundamental para a maioria das tarefas:

1.  **Coleta (Firmware)**: Um sensor (ex: `firmware/node-01-con`) lê um valor (ex: nível de um reservatório) a cada 30 segundos.
2.  **Ingestão (Backend)**: O firmware envia a leitura para o endpoint `POST /api/leituras` no backend.
3.  **Armazenamento Bruto (Database)**: O backend insere a leitura na tabela `leituras_raw`. Esta tabela armazena **todas** as leituras, sem exceção, para fins de auditoria.
4.  **Processamento e Compressão (Database)**: Um `TRIGGER` no PostgreSQL (definido em `database/triggers.sql`) é acionado após a inserção em `leituras_raw`.
    *   Este trigger executa uma função (definida em `database/functions.sql`) que aplica um algoritmo de mediana e *deadband*.
    *   Se a nova leitura for considerada uma "mudança significativa", um novo registro é criado na tabela `leituras_processadas`. Caso contrário, o `data_fim` do último registro é apenas atualizado.
    *   **Este mecanismo reduz o armazenamento de dados em ~90%.**
5.  **Visualização (Frontend)**: O frontend consulta a API (que por sua vez consulta a tabela `leituras_processadas`) para exibir gráficos e estados atualizados, mostrando apenas os dados relevantes.

## 3. O Banco de Dados é o Coração

A maior parte da lógica de negócio reside no banco de dados para garantir consistência e performance.

*   **Fonte da Verdade**: `database/schema.sql` define toda a estrutura. Sempre consulte este arquivo antes de fazer alterações no modelo de dados.
*   **Tabelas Chave**:
    *   `elemento`: Representa qualquer componente físico (reservatório, bomba, válvula).
    *   `leituras_raw`: Dados brutos, alta frequência.
    *   `leituras_processadas`: Dados comprimidos, baixa frequência, usados para visualização.
    *   `eventos`: Registra ocorrências importantes detectadas automaticamente (vazamentos, abastecimentos).
*   **Lógica de Compressão**: A lógica principal está nas funções PL/pgSQL em `database/functions.sql` e é acionada por `database/triggers.sql`. Qualquer alteração no processamento de dados provavelmente precisará ser feita aqui.

## 4. Workflows de Desenvolvimento

O ambiente de desenvolvimento é gerenciado inteiramente com Docker.

*   **Iniciar o sistema**:
    ```bash
    ./deploy.sh start
    ```
    Isso sobe os contêineres do `postgres`, `backend` e `frontend`.
    *   Frontend: `http://localhost`
    *   Backend API: `http://localhost:3000`

*   **Parar o sistema**:
    ```bash
    ./deploy.sh stop
    ```

*   **Ver logs**:
    ```bash
    # Logs de todos os serviços
    ./deploy.sh logs

    # Logs de um serviço específico (ex: backend)
    docker-compose logs -f backend
    ```

*   **Testar a API**: O arquivo `test_api.http` contém exemplos de requisições para interagir com a API. Use a extensão "REST Client" do VS Code para executá-las.

*   **Backup e Restore**: Os scripts `backup.sh` e `restore.sh` são usados para criar e restaurar um snapshot completo do sistema (banco de dados e configurações), útil para migração.

## 5. Padrões e Convenções

*   **Backend**: O backend em Python (`backend/src/main.py`) é relativamente simples. Sua principal responsabilidade é servir como um gateway entre os sensores/frontend e o banco de dados. A validação de dados ocorre aqui, mas o processamento pesado é delegado ao banco de dados.
*   **Frontend**: O frontend é construído com HTML, CSS e JavaScript puros. Não há frameworks complexos. A interatividade é adicionada via `navbar.js` e scripts inline que fazem chamadas `fetch` para a API do backend.
*   **Firmware**: Os firmwares são escritos em C/C++ para plataformas Arduino/ESP-IDF. Eles são projetados para serem robustos e eficientes, com lógicas de medição (mediana) e reconexão. As configurações de rede (IP do servidor) são os principais pontos a serem ajustados.
