-- AnalisOS · schema do Supabase (projeto analisos-frota, região São Paulo)
-- JÁ APLICADO em 19/11/2026. Este arquivo é a referência para recriar o banco do zero.

-- ========== Usuários e permissões ==========
create table public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  ativo boolean not null default false,   -- novo acesso entra bloqueado
  admin boolean not null default false,
  criado_em timestamptz not null default now()
);

-- novo cadastro entra inativo; o primeiro usuário do sistema vira administrador ativo
create or replace function public.novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare primeiro boolean;
begin
  select not exists(select 1 from public.perfis) into primeiro;
  insert into public.perfis(id,email,ativo,admin) values (new.id,new.email,primeiro,primeiro);
  return new;
end $$;
create trigger ao_criar_usuario after insert on auth.users for each row execute function public.novo_usuario();

create or replace function public.eh_ativo() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce((select ativo from public.perfis where id = auth.uid()), false) $$;
create or replace function public.eh_admin() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce((select ativo and admin from public.perfis where id = auth.uid()), false) $$;

-- ========== Base de OS (substituída a cada importação) ==========
create table public.os_linhas (
  id bigint generated always as identity primary key,
  data text, os text, placa text, tecnico text, minutos text, tempo text, tarefas text
);

-- ========== Tabela de Veículos (substituída a cada importação) ==========
create table public.frota_veiculos (
  id bigint generated always as identity primary key,
  placa text not null, marca text, modelo text
);

-- ========== Registro das importações ==========
create table public.cargas (
  id bigint generated always as identity primary key,
  tipo text not null check (tipo in ('os','frota')),
  arquivo text, linhas integer, periodo_ini date, periodo_fim date,
  feito_por uuid default auth.uid(), feito_por_email text,
  feito_em timestamptz not null default now()
);

-- ========== Preventivas ==========
create table public.prev_veiculos (
  placa text primary key,
  tipo text not null check (tipo in ('CAVALO 6X2','CAVALO 6X4','CAMINHÃO TRUCK','FURGÃO','FROTA LEVE','CARRETA 13 M','CARRETA 15 M','CARRETA SIDER')),
  km_atual integer check (km_atual >= 0),
  km_data date,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create table public.revisoes (
  id uuid primary key default gen_random_uuid(),
  placa text not null references public.prev_veiculos(placa) on update cascade on delete cascade,
  plano text not null check (plano in ('MP1','MP2','MP3','INT','RP1','RP2')),
  data date not null,
  km integer check (km >= 0),
  os text, obs text,
  nao_executados text[] not null default '{}',
  criado_em timestamptz not null default now(),
  criado_por uuid default auth.uid()
);
create index revisoes_placa_plano_data on public.revisoes (placa, plano, data desc);
create table public.planos_config (
  plano text primary key check (plano in ('MP1','MP2','MP3','INT')),
  km integer check (km > 0), meses integer check (meses > 0),
  atualizado_em timestamptz not null default now()
);

create or replace function public.tocar_atualizado() returns trigger language plpgsql set search_path = public as
$$ begin new.atualizado_em := now(); return new; end $$;
create trigger prev_veiculos_atualizado before update on public.prev_veiculos for each row execute function public.tocar_atualizado();
create trigger planos_config_atualizado before update on public.planos_config for each row execute function public.tocar_atualizado();

-- ========== Troca segura das bases (tudo ou nada, só administrador) ==========
create or replace function public.substituir_os(p_linhas jsonb, p_arquivo text, p_ini date, p_fim date)
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.eh_admin() then raise exception 'Somente administradores podem atualizar a base de OS'; end if;
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'Base vazia: nada foi alterado'; end if;
  delete from public.os_linhas where true;
  insert into public.os_linhas(data,os,placa,tecnico,minutos,tempo,tarefas)
    select e->>0, e->>1, e->>2, e->>3, e->>4, e->>5, e->>6 from jsonb_array_elements(p_linhas) e;
  get diagnostics n = row_count;
  insert into public.cargas(tipo,arquivo,linhas,periodo_ini,periodo_fim,feito_por_email)
    values ('os',p_arquivo,n,p_ini,p_fim,(select email from public.perfis where id = auth.uid()));
  return n;
end $$;

create or replace function public.substituir_frota(p_linhas jsonb, p_arquivo text)
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.eh_admin() then raise exception 'Somente administradores podem atualizar a tabela de veículos'; end if;
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'Tabela vazia: nada foi alterado'; end if;
  delete from public.frota_veiculos where true;
  insert into public.frota_veiculos(placa,marca,modelo)
    select e->>0, e->>1, e->>2 from jsonb_array_elements(p_linhas) e;
  get diagnostics n = row_count;
  insert into public.cargas(tipo,arquivo,linhas,feito_por_email)
    values ('frota',p_arquivo,n,(select email from public.perfis where id = auth.uid()));
  return n;
end $$;

-- quem pode chamar cada função
revoke execute on function public.substituir_os(jsonb,text,date,date) from public, anon;
revoke execute on function public.substituir_frota(jsonb,text) from public, anon;
grant execute on function public.substituir_os(jsonb,text,date,date) to authenticated;
grant execute on function public.substituir_frota(jsonb,text) to authenticated;
revoke execute on function public.novo_usuario() from public, anon, authenticated;
revoke execute on function public.eh_ativo() from public, anon;
revoke execute on function public.eh_admin() from public, anon;
grant execute on function public.eh_ativo() to authenticated;
grant execute on function public.eh_admin() to authenticated;
revoke execute on function public.tocar_atualizado() from public, anon, authenticated;

-- ========== Segurança (RLS): sem login liberado, nada é lido nem gravado ==========
alter table public.perfis enable row level security;
alter table public.os_linhas enable row level security;
alter table public.frota_veiculos enable row level security;
alter table public.cargas enable row level security;
alter table public.prev_veiculos enable row level security;
alter table public.revisoes enable row level security;
alter table public.planos_config enable row level security;

create policy perfis_ver on public.perfis for select to authenticated using (id = auth.uid() or public.eh_admin());
create policy perfis_admin on public.perfis for update to authenticated using (public.eh_admin()) with check (public.eh_admin());
create policy os_ver on public.os_linhas for select to authenticated using (public.eh_ativo());
create policy frota_ver on public.frota_veiculos for select to authenticated using (public.eh_ativo());
create policy cargas_ver on public.cargas for select to authenticated using (public.eh_ativo());
create policy prev_veiculos_tudo on public.prev_veiculos for all to authenticated using (public.eh_ativo()) with check (public.eh_ativo());
create policy revisoes_tudo on public.revisoes for all to authenticated using (public.eh_ativo()) with check (public.eh_ativo());
create policy planos_config_tudo on public.planos_config for all to authenticated using (public.eh_ativo()) with check (public.eh_ativo());

-- ======================================================================
-- v4.0 (APLICADO em 25/11/2026, migração v40_estoque_e_cadastro_veiculos)
-- ======================================================================
-- Tabela de Veículos: tipo, proprietário e ano (a v3.x continua funcionando: as colunas ficam vazias)
alter table public.frota_veiculos add column if not exists tipo text, add column if not exists proprietario text, add column if not exists ano text;

-- Movimentações de Estoque (substituída a cada importação)
create table if not exists public.estoque_mov (
  id bigint generated always as identity primary key,
  data date not null,
  saida boolean not null,          -- true = saída para veículo (custo); false = entrada (compra)
  placa text, os text, codigo text, peca text,
  quantidade numeric, valor_unit numeric, valor_total numeric,
  motivo text, local text, fornecedor text
);
alter table public.estoque_mov enable row level security;
create policy estoque_ver on public.estoque_mov for select to authenticated using (public.eh_ativo());

alter table public.cargas drop constraint if exists cargas_tipo_check;
alter table public.cargas add constraint cargas_tipo_check check (tipo in ('os','frota','estoque'));

-- substituir_frota passa a gravar tipo, proprietário e ano (posições 3, 4 e 5 de cada linha)
create or replace function public.substituir_frota(p_linhas jsonb, p_arquivo text)
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.eh_admin() then raise exception 'Somente administradores podem atualizar a tabela de veículos'; end if;
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'Tabela vazia: nada foi alterado'; end if;
  delete from public.frota_veiculos where true;
  insert into public.frota_veiculos(placa,marca,modelo,tipo,proprietario,ano)
    select e->>0, e->>1, e->>2, nullif(e->>3,''), nullif(e->>4,''), nullif(e->>5,'') from jsonb_array_elements(p_linhas) e;
  get diagnostics n = row_count;
  insert into public.cargas(tipo,arquivo,linhas,feito_por_email)
    values ('frota',p_arquivo,n,(select email from public.perfis where id = auth.uid()));
  return n;
end $$;

-- estoque: troca a base inteira (tudo ou nada, só administrador)
-- cada linha: [data, saida, placa, os, codigo, peca, quantidade, valor_unit, valor_total, motivo, local, fornecedor]
create or replace function public.substituir_estoque(p_linhas jsonb, p_arquivo text, p_ini date, p_fim date)
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.eh_admin() then raise exception 'Somente administradores podem atualizar a base de estoque'; end if;
  if jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then raise exception 'Base vazia: nada foi alterado'; end if;
  delete from public.estoque_mov where true;
  insert into public.estoque_mov(data,saida,placa,os,codigo,peca,quantidade,valor_unit,valor_total,motivo,local,fornecedor)
    select (e->>0)::date, (e->>1)::boolean, nullif(e->>2,''), nullif(e->>3,''), nullif(e->>4,''), e->>5,
           (e->>6)::numeric, (e->>7)::numeric, (e->>8)::numeric, nullif(e->>9,''), nullif(e->>10,''), nullif(e->>11,'')
    from jsonb_array_elements(p_linhas) e;
  get diagnostics n = row_count;
  insert into public.cargas(tipo,arquivo,linhas,periodo_ini,periodo_fim,feito_por_email)
    values ('estoque',p_arquivo,n,p_ini,p_fim,(select email from public.perfis where id = auth.uid()));
  return n;
end $$;

revoke execute on function public.substituir_estoque(jsonb,text,date,date) from public, anon;
grant execute on function public.substituir_estoque(jsonb,text,date,date) to authenticated;
revoke execute on function public.substituir_frota(jsonb,text) from public, anon;
grant execute on function public.substituir_frota(jsonb,text) to authenticated;

-- ======================================================================
-- v4.1 (APLICADO em 25/11/2026, migração v41_abas_por_usuario)
-- ======================================================================
-- O administrador escolhe as abas de cada usuário. null = todas as abas.
alter table public.perfis add column if not exists abas text[];

-- pode_ver(aba): usuário ativo e (administrador, ou sem restrição, ou com a aba liberada)
create or replace function public.pode_ver(p_aba text) returns boolean
language sql stable security definer set search_path = public as
$$ select coalesce((select ativo and (admin or abas is null or p_aba = any(abas)) from public.perfis where id = auth.uid()), false) $$;
revoke execute on function public.pode_ver(text) from public, anon;
grant execute on function public.pode_ver(text) to authenticated;

-- Custos: o estoque (valores em R$) só para quem tem a aba Custos
drop policy if exists estoque_ver on public.estoque_mov;
create policy estoque_ver on public.estoque_mov for select to authenticated using (public.pode_ver('custos'));

-- Preventivas: veículos, revisões e planos só para quem tem a aba Preventivas
drop policy if exists prev_veiculos_tudo on public.prev_veiculos;
create policy prev_veiculos_tudo on public.prev_veiculos for all to authenticated using (public.pode_ver('prev')) with check (public.pode_ver('prev'));
drop policy if exists revisoes_tudo on public.revisoes;
create policy revisoes_tudo on public.revisoes for all to authenticated using (public.pode_ver('prev')) with check (public.pode_ver('prev'));
drop policy if exists planos_config_tudo on public.planos_config;
create policy planos_config_tudo on public.planos_config for all to authenticated using (public.pode_ver('prev')) with check (public.pode_ver('prev'));
-- As demais abas usam a base de OS (os_linhas), que continua liberada para todo usuário ativo:
-- esconder essas abas vale só no painel. Só o administrador altera perfis (política perfis_admin).