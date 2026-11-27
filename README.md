# AnalisOS: painel de manutenção da frota

Painel da Rodovitor Transportes num arquivo HTML único (index.html). Os dados ficam no Supabase, no projeto analisos-frota (São Paulo, plano gratuito).

Endereço: https://30gabrielaxel30-boop.github.io/analisos-frota/

## Acesso

O login é por usuário e senha. O acesso é restrito e não existe cadastro livre. Usuários: Admin (administrador), Redig e Pedro.

Para criar um usuário novo, vá no Supabase em Authentication > Users > Add user > Create new user. Use como e-mail nome@rodovitor.local e marque Auto Confirm User. Depois libere o usuário no painel, em Dados e critérios > Acessos e atualizações.

Sem login liberado, o banco não devolve nenhum dado. A chave no index.html é a pública (anon).

Desde a v4.1, o administrador escolhe quais abas cada usuário vê, no quadro "O que cada usuário vê" (Dados e critérios > Acessos e atualizações). Sem a aba Custos, o usuário não vê nenhum valor em R$; sem Preventivas, não lê nem grava revisões. Esses dois bloqueios também valem no banco (função pode_ver). As outras abas usam a mesma base de OS, então escondê-las vale só no painel.

## Bases

São 5 bases:
1. Ordens de Serviço.
2. Tabela de Veículos, com tipo, proprietário e ano.
3. Movimentações de Estoque: dão o custo de peças por veículo e por OS (desde a v4.0).
4. Diesel: abastecimentos do tanque próprio (desde a v4.6).
5. ARLA: abastecimentos do tanque próprio (desde a v4.6).

As bases 4 e 5 dão o custo de combustível por veículo. Na aba Custos, o seletor "Custo considerado" mostra o total, só a manutenção ou só o combustível.

O administrador importa as planilhas na aba Dados e critérios. A base anterior é substituída por inteiro numa operação única: se falhar, a antiga continua. Diesel e ARLA são substituídos cada um por si, e o painel recusa a planilha colocada no espaço errado, conferindo pelo preço do litro.

Preventivas: são gravadas no banco na hora e todos os usuários veem os mesmos dados.

## Arquivos

index.html é o painel. supabase/schema.sql tem as tabelas, funções e regras de acesso. O .gitignore impede subir planilhas, backups e chaves.

Para publicar uma versão nova, substitua o index.html. O site atualiza em cerca de 1 minuto.
