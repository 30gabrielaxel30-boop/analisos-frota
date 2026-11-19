# AnalisOS: painel de manutenção da frota (versão online)

Painel da Rodovitor Transportes, num arquivo HTML único (`index.html`). Os dados ficam no Supabase, no projeto `analisos-frota` (região São Paulo, plano gratuito).

## Como funciona

- **Login:** é por e-mail e senha. O primeiro usuário cadastrado vira administrador. Os acessos seguintes entram bloqueados até um administrador liberar, em Dados e critérios › Acessos e atualizações.
- **Base de OS e Tabela de Veículos:** ficam no Supabase. O administrador importa a planilha na aba Dados e critérios, e a base anterior é substituída por inteiro numa operação única. Se a importação falhar no meio, a base antiga continua no banco. Se a planilha nova começar depois da base atual, o painel avisa antes de apagar os meses mais antigos.
- **Preventivas:** cada veículo e revisão é gravado no banco na hora. Todos os usuários liberados veem os mesmos dados.
- **Segurança:** sem login liberado, o banco não devolve nenhum dado. A chave que aparece no `index.html` é a chave pública ("anon") e, sozinha, não acessa nada.

## Arquivos

```
README.md            este arquivo
.gitignore           impede que planilhas, backups e chaves subam
index.html           o painel (versão online, sem dados embutidos)
supabase/schema.sql  tabelas, funções e regras de acesso (já aplicado no projeto)
```

## Publicar no GitHub

1. Crie o repositório em github.com. Ele pode ser **público**, porque o `index.html` não tem dados da empresa, só a chave pública do Supabase.
2. Envie os arquivos desta pasta:
   - pelo GitHub Desktop;
   - ou pelo site: "Add file" › "Upload files", arrastando `index.html`, `README.md`, `.gitignore` e a pasta `supabase`.
3. Em Settings › Pages, escolha "Deploy from a branch", branch `main`, pasta `/ (root)`. O endereço fica parecido com `https://SEU-USUARIO.github.io/NOME-DO-REPOSITORIO/`.
4. No Supabase, em Authentication › URL Configuration, coloque esse endereço em **Site URL**. Assim o link de confirmação do e-mail volta para o painel.

## Atualizar o painel

Cada versão nova do painel substitui o `index.html`. O banco não muda, a menos que a versão traga um script novo em `supabase/`.
