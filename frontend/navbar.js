// Navbar Component - Inject navbar HTML into all pages

const API_URL = 'http://localhost:3000/api';

// Get current page for active state
function getCurrentPage() {
    const path = window.location.pathname;
    const page = path.substring(path.lastIndexOf('/') + 1) || 'index.html';
    return page;
}

// Check API status
async function checkAPIStatus() {
    const statusDot = document.querySelector('.status-dot');
    const statusText = document.querySelector('.status-text');
    
    try {
        const response = await fetch(`${API_URL}/health`, { 
            method: 'GET',
            timeout: 3000 
        });
        
        if (response.ok) {
            statusDot.classList.remove('status-offline');
            statusText.textContent = 'Online';
        } else {
            throw new Error('API error');
        }
    } catch (error) {
        statusDot.classList.add('status-offline');
        statusText.textContent = 'Offline';
    }
}

// Create navbar HTML
function createNavbar() {
    const currentPage = getCurrentPage();
    
    const navbarHTML = `
        <nav class="navbar">
            <div class="nav-container">
                <a href="index.html" class="nav-brand">
                    <div class="nav-logo">💧</div>
                    <div>
                        <h1>AguadaPy</h1>
                        <small>Sistema Supervisório</small>
                    </div>
                </a>

                <ul class="nav-menu" id="navMenu">
                    <li class="nav-item">
                        <a href="index.html" class="nav-link ${currentPage === 'index.html' ? 'active' : ''}">
                            <span class="icon">🏠</span>
                            Início
                        </a>
                    </li>

                    <li class="nav-item">
                        <a href="dashboard.html" class="nav-link ${currentPage === 'dashboard.html' ? 'active' : ''}">
                            <span class="icon">📊</span>
                            Dashboard
                        </a>
                    </li>

                    <li class="nav-item">
                        <a href="#" class="nav-link">
                            <span class="icon">⚙️</span>
                            Configuração
                            <span style="font-size: 10px;">▼</span>
                        </a>
                        <div class="dropdown-menu">
                            <a href="config.html" class="dropdown-item ${currentPage === 'config.html' ? 'active' : ''}">
                                <span>📝</span>
                                Configuração Completa
                            </a>
                            <a href="tabela-config.html" class="dropdown-item ${currentPage === 'tabela-config.html' ? 'active' : ''}">
                                <span>✏️</span>
                                Edição Rápida
                            </a>
                            <div class="dropdown-divider"></div>
                            <a href="config.html?tab=sensores" class="dropdown-item">
                                <span>📡</span>
                                Sensores
                            </a>
                            <a href="config.html?tab=atuadores" class="dropdown-item">
                                <span>🔌</span>
                                Atuadores
                            </a>
                            <a href="config.html?tab=conexoes" class="dropdown-item">
                                <span>🔗</span>
                                Conexões
                            </a>
                        </div>
                    </li>

                    <li class="nav-item">
                        <a href="debug.html" class="nav-link ${currentPage === 'debug.html' ? 'active' : ''}">
                            <span class="icon">🐞</span>
                            Debug
                        </a>
                    </li>

                    <li class="nav-item">
                        <a href="#" class="nav-link">
                            <span class="icon">📄</span>
                            Relatórios
                            <span style="font-size: 10px;">▼</span>
                        </a>
                        <div class="dropdown-menu">
                            <a href="relatorios.html?tipo=diario" class="dropdown-item">
                                <span>📅</span>
                                Relatório Diário
                            </a>
                            <a href="relatorios.html?tipo=eventos" class="dropdown-item">
                                <span>⚡</span>
                                Histórico de Eventos
                            </a>
                            <a href="relatorios.html?tipo=consumo" class="dropdown-item">
                                <span>💧</span>
                                Análise de Consumo
                            </a>
                            <div class="dropdown-divider"></div>
                            <a href="relatorios.html?tipo=export" class="dropdown-item">
                                <span>📥</span>
                                Exportar Dados
                            </a>
                        </div>
                    </li>

                    <li class="nav-item">
                        <div class="status-indicator">
                            <div class="status-dot"></div>
                            <span class="status-text">Verificando...</span>
                        </div>
                    </li>
                </ul>

                <div class="nav-toggle" id="navToggle">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
            </div>
        </nav>
    `;

    return navbarHTML;
}

// Initialize navbar
function initNavbar() {
    const placeholder = document.getElementById('navbar-placeholder');
    
    if (placeholder) {
        placeholder.innerHTML = createNavbar();
        
        // Check API status on load
        setTimeout(checkAPIStatus, 500);
        
        // Check API status every 30 seconds
        setInterval(checkAPIStatus, 30000);
        
        // Mobile menu toggle
        const navToggle = document.getElementById('navToggle');
        const navMenu = document.getElementById('navMenu');
        
        if (navToggle && navMenu) {
            navToggle.addEventListener('click', () => {
                navToggle.classList.toggle('active');
                navMenu.classList.toggle('active');
            });
        }
        
        // Close mobile menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.navbar')) {
                navToggle?.classList.remove('active');
                navMenu?.classList.remove('active');
            }
        });
    }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initNavbar);
} else {
    initNavbar();
}
