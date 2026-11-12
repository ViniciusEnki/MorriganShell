# Roadmap

## 🐛 Bug Fixes & Estabilidade

- [ ] **Persistência de Shaders (`hyprshader`):** Investigar e corrigir o comportamento de recarregamento forçado do compositor após alterações de configuração, que atualmente sobrescreve ou desativa os shaders ativos.
- [ ] **Compatibilidade de Blur (Wayland):** Validar o suporte a `ext-background-effect-v1` por compositor e manter fallback seguro nos compositores incompatíveis.
- [ ] **Overflow de Texto (Audio Settings):** Implementar truncamento de texto (_ellipsize_ / `max-width`) nos rótulos de dispositivos em `Settings > System > Audio` para evitar quebra de layout com nomes extensos.

## ✨ Novas Funcionalidades & Arquitetura

- [ ] **Sistema de Persistência e Estado Global:** Implementar um mecanismo centralizado de armazenamento de dados e estado da aplicação (preferências, configurações, wallpaper ativo, etc.).
- [ ] **Novo Menu de Configurações:** Desenvolver e integrar uma nova interface centralizada de _Settings_.
- [ ] **Integração com `awww`:** Migrar o backend de gerenciamento de papéis de parede para utilizar o `awww` como daemon padrão do sistema.
- [ ] **Menu Interativo no Relógio:** Transformar o widget `topbar/widget/clock` em um gatilho interativo com abertura de menu ao passar o cursor (_hover_).
- [ ] **Calculadora / Contas no Spotlight:** Adicionar suporte à avaliação de expressões matemáticas diretamente na barra de busca do Spotlight.
- [ ] **Blacklist de Aplicações (Spotlight):** Implementar suporte a uma lista de bloqueio (_ignore list_) para filtrar e ocultar aplicativos específicos dos resultados do Spotlight.

## 🎨 UI/UX & Refatoração

- [ ] **Redesign do Spotlight:** Reformular o layout, espaçamento e identidade visual do lançador de aplicativos.
- [ ] **Redesign do Polkit Agent:** Reconstruir a interface do diálogo de autenticação do Polkit para alinhá-la à identidade visual do shell.
- [ ] **Refinamento de Notificações:** Aprimorar o layout, hierarquia visual e animações dos pop-ups e do centro de notificações.
- [ ] **Workspace Switcher Minimalista:** Redesenhar os indicadores do seletor de áreas de trabalho para um formato circular (_dots_).
- [ ] **Padronização de Nomenclatura:** Renomear o componente `dankbar` para `topbar` em toda a base de código e documentação para maior clareza semântica.

## 🔍 Backlog & Revisão Futura

- [ ] **Auditoria do Gerenciador de Clipboard:** Revisar a arquitetura, histórico e comportamento atual do módulo de área de transferência.
- [ ] **Novo Módulo de Clima (Weather):** Reimplementar o widget e o provedor de dados meteorológicos do shell.
- [ ] **Customização Avançada do Relógio:** Expandir as opções de formatação e personalização visual do widget de relógio.
- [ ] **Atualização de Dependência (`DankCommon`):** Sincronizar o diretório `quickshell/DankCommon` com as atualizações do repositório upstream [`dux-qml-common`](https://github.com/duxlabs-dev/dux-qml-common/tree/1ae722232da7110d26cd2c355b6615e078e94197).
