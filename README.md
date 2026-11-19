# AnalisOS: painel de manutenção da frota

Painel da Rodovitor Transportes num arquivo HTML único (index.html). Os dados ficam no Supabase, no projeto analisos-frota (São Paulo, plano gratuito).

Endereço: https://30gabrielaxel30-boop.github.io/analisos-frota/

## Acesso

O login é por usuário e senha. O acesso é restrito e não existe cadastro livre. Usuários: Admin (administrador), Redig e Pedro.

Para criar um usuário novo, vá no Supabase em Authentication > Users > Add user > Create new user. Use como e-mail nome@rodovitor.local e marque Auto Confirm User. Depois libere o usuário no painel, em Dados e critérios > Acessos e atualizações.

Sem login liberado, o banco não devolve nenhum dado. A chave no index.html é a pública (anon).

## Bases

Base de OS e Tabela de Veículos: o administrador importa a planilha na aba Dados e critérios. A base anterior é substituída por inteiro numa operação única: se falhar, a antiga continua.

Preventivas: são gravadas no banco na hora e todos os usuários veem os mesmos dados.

## Arquivos

index.html é o painel. supabase/schema.sql tem as tabelas, funções e regras de acesso. O .gitignore impede subir planilhas, backups e chaves.

Para publicar uma versão nova, substitua o index.html. O site atualiza em cerca de 1 minuto.
