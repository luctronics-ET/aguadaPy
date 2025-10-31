# Sistema de Navegação - AguadaPy Frontend

## � Links Rápidos de Acesso

### Páginas Principais
- 🏠 [Página Inicial](index.html)
- 📊 [Dashboard](dashboard.html)
- ⚙️ [Configuração Completa](config.html)
- ✏️ [Edição Rápida (Tabela)](tabela-config.html)
- 🐞 [Debug](debug.html)

### Configurações por Tipo
- 📦 [Elementos](config.html)
- 📡 [Sensores](config.html?tab=sensores)
- 🔌 [Atuadores](config.html?tab=atuadores)
- 🔗 [Conexões](config.html?tab=conexoes)
- 👥 [Usuários](config.html?tab=usuarios)

### Exemplos de Ficha Técnica
- 🏺 [Elemento ID 1](elemento.html?id=1)
- 🏺 [Elemento ID 2](elemento.html?id=2)
- 🏺 [Elemento ID 3](elemento.html?id=3)

### API Backend
- 🔧 [API Health Check](http://localhost:3000/api/health)
- 📋 [API Elementos](http://localhost:3000/api/elementos)
- 📊 [API Estatísticas](http://localhost:3000/api/elementos/stats)

---

## �📋 Estrutura de Páginas

### Páginas Principais

1. **[index.html](index.html)** - Página inicial
   - Hero section com apresentação do sistema
   - Cards de funcionalidades principais
   - Estatísticas do sistema
   - Links rápidos para todas as seções

2. **[dashboard.html](dashboard.html)** - Dashboard de monitoramento
   - Status da API e banco de dados em tempo real
   - Visualização de sensores ativos
   - Gráficos e métricas (em desenvolvimento)
   - Auto-refresh a cada 5 segundos

3. **[config.html](config.html)** - Configuração completa
   - Sistema de tabs (Elementos, Sensores, Atuadores, Conexões, Usuários)
   - Modal para edição detalhada de elementos
   - Formulário completo com validação
   - Operações CRUD completas
   - **Atalhos:**
     - [Sensores](config.html?tab=sensores)
     - [Atuadores](config.html?tab=atuadores)
     - [Conexões](config.html?tab=conexoes)
     - [Usuários](config.html?tab=usuarios)

4. **[tabela-config.html](tabela-config.html)** - Edição rápida
   - Tabela com edição inline (clique para editar)
   - Rastreamento de alterações (destaque verde)
   - Operações em lote (selecionar múltiplas linhas)
   - Paginação (20 registros por página)
   - Exportação CSV

5. **[elemento.html](elemento.html?id=1)** - Ficha técnica do elemento
   - Visualização detalhada de um elemento específico
   - Mapa interativo (OpenStreetMap)
   - Histórico de leituras e eventos
   - Conexões e equipamentos vinculados
   - Opção de impressão
   - **Uso:** `elemento.html?id={elemento_id}`

6. **[debug.html](debug.html)** - Painel de debug
   - Dados brutos dos sensores
   - Status online/offline em tempo real
   - Auto-refresh a cada 5 segundos
   - Interface monospace para desenvolvedores

## 🧭 Componente de Navegação

### Arquivos do Navbar

**navbar.css**
- Estilos do menu de navegação
- Design responsivo (mobile e desktop)
- Animações de hover e dropdown
- Indicador de status (online/offline)
- Breakpoint mobile: 768px

**navbar.js**
- Injeção dinâmica do HTML do navbar
- Verificação de status da API (endpoint /health)
- Highlight da página atual
- Toggle do menu mobile
- Auto-verificação a cada 30 segundos

### Estrutura do Menu

```
🏠 Início (index.html)
📊 Dashboard (dashboard.html)
⚙️ Configuração (dropdown)
   ├─ 📝 Configuração Completa (config.html)
   ├─ ✏️ Edição Rápida (tabela-config.html)
   ├─ ──────────────
   ├─ 📡 Sensores (config.html?tab=sensores)
   ├─ 🔌 Atuadores (config.html?tab=atuadores)
   └─ 🔗 Conexões (config.html?tab=conexoes)
🐞 Debug (debug.html)
📄 Relatórios (dropdown)
   ├─ 📅 Relatório Diário
   ├─ ⚡ Histórico de Eventos
   ├─ 💧 Análise de Consumo
   ├─ ──────────────
   └─ 📥 Exportar Dados
[Status Online/Offline]
```

## 🔧 Integração nas Páginas

### Como o navbar é adicionado:

**1. No `<head>` da página:**
```html
<link rel="stylesheet" href="navbar.css">
```

**2. No início do `<body>`:**
```html
<div id="navbar-placeholder"></div>
```

**3. Antes do fechamento do `</body>`:**
```html
<script src="navbar.js"></script>
```

**4. Ajuste do padding do body:**
```css
body {
    padding: 0; /* Remove padding para o navbar fixo */
}
.main-content {
    padding: 20px; /* Adiciona padding ao conteúdo */
}
```

### Páginas com navbar integrado:
- ✅ index.html
- ✅ dashboard.html
- ✅ config.html
- ✅ tabela-config.html
- ✅ elemento.html
- ✅ debug.html

## 📡 Verificação de Status da API

O navbar verifica automaticamente o status da API:

**Endpoint de Health Check:**
```
GET http://localhost:3000/api/health
```

**Estados visuais:**
- 🟢 **Online**: Ponto verde pulsante + texto "Online"
- 🔴 **Offline**: Ponto vermelho + texto "Offline"

**Frequência de verificação:**
- Ao carregar a página: 500ms
- Intervalos: A cada 30 segundos

## 📱 Responsividade Mobile

**Desktop (> 768px):**
- Menu horizontal
- Dropdowns aparecem ao passar o mouse
- Todos os itens visíveis

**Mobile (≤ 768px):**
- Menu hamburger (3 linhas)
- Menu vertical em overlay
- Dropdowns expandem inline
- Toque para abrir/fechar

**Interações mobile:**
- Toque no hamburger: abre/fecha menu
- Toque fora do menu: fecha automaticamente
- Dropdowns: toque no item para expandir

## 🎨 Design System

**Cores principais:**
- Primary: `#667eea` (roxo)
- Background navbar: `rgba(255,255,255,0.95)`
- Hover: `#f3f4f6` (cinza claro)
- Active: `#667eea` (roxo - texto branco)
- Status online: `#10b981` (verde)
- Status offline: `#ef4444` (vermelho)

**Tipografia:**
- Font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif
- Nav links: 14px, peso 500
- Brand title: 24px, peso 700

**Espaçamento:**
- Altura do navbar: 70px
- Padding interno: 20px
- Gap entre itens: 5px
- Gap ícone-texto: 8px

## 🚀 Próximos Passos

### Funcionalidades planejadas:
- [ ] Página de relatórios (relatorios.html)
- [ ] Sistema de alertas e notificações
- [ ] Perfil do usuário (autenticação)
- [ ] Configurações do sistema
- [ ] Temas claro/escuro
- [ ] Gráficos no dashboard (Chart.js)
- [ ] Notificações push para eventos críticos

### Backend necessário:
- [ ] Endpoint /api/health (verificação de status)
- [ ] Endpoint /api/elementos/stats (estatísticas)
- [ ] CRUD completo de elementos
- [ ] CRUD de sensores e atuadores
- [ ] Sistema de eventos em tempo real
- [ ] Geração de relatórios
- [ ] Autenticação JWT

## 📝 Notas de Desenvolvimento

**Convenções:**
- Todos os arquivos HTML devem incluir o navbar
- Use ícones emoji consistentes (🏠📊⚙️🐞📄)
- Mantenha o design system (cores, tipografia, espaçamento)
- Teste responsividade em mobile e desktop
- Sempre use a classe `.main-content` para o conteúdo principal

**Manutenção do navbar:**
- Para adicionar novo item: edite `navbar.js` na função `createNavbar()`
- Para alterar estilos: edite `navbar.css`
- Para mudar frequência de verificação: edite a linha `setInterval(checkAPIStatus, 30000)`

**Debugando:**
- Abra o console do navegador (F12)
- Verifique se navbar.js foi carregado
- Confirme que o placeholder existe: `document.getElementById('navbar-placeholder')`
- Teste o endpoint de health manualmente: `curl http://localhost:3000/api/health`
