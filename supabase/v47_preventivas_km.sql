-- v4.7: Preventivas por km (cronograma de dezembro/2026).
-- Só cria tabelas novas. As tabelas antigas (prev_veiculos, revisoes, planos_config) não são alteradas e ficam como registro.
-- Rodar uma vez no Supabase (SQL Editor) do projeto analisos-frota.
create table public.prev2_veiculos (
  placa text primary key,
  marca text not null,
  modelo text,
  ano integer,
  km integer,
  km_data date,
  atualizado_em timestamptz not null default now()
);
create table public.prev2_planos (
  id text primary key,
  placa text not null,
  tipo text not null,
  ultima integer,
  ult0 integer,
  base text,
  orig text,
  obs text,
  atualizado_em timestamptz not null default now()
);
create index prev2_planos_placa on public.prev2_planos (placa);
create table public.prev2_hist (
  id text primary key,
  k text not null check (k in ('rev','km')),
  placa text not null,
  tipo text,
  data date,
  km integer,
  obs text,
  src text,
  ts bigint not null default 0,
  criado_por uuid default auth.uid(),
  criado_em timestamptz not null default now()
);
create index prev2_hist_placa on public.prev2_hist (placa, k);
create table public.prev2_cfg (
  id integer primary key check (id = 1),
  cfg jsonb not null,
  marcas jsonb not null default '[]'::jsonb,
  bk date,
  atualizado_em timestamptz not null default now()
);
create trigger prev2_veiculos_atualizado before update on public.prev2_veiculos for each row execute function public.tocar_atualizado();
create trigger prev2_planos_atualizado before update on public.prev2_planos for each row execute function public.tocar_atualizado();
create trigger prev2_cfg_atualizado before update on public.prev2_cfg for each row execute function public.tocar_atualizado();
alter table public.prev2_veiculos enable row level security;
alter table public.prev2_planos enable row level security;
alter table public.prev2_hist enable row level security;
alter table public.prev2_cfg enable row level security;
-- mesma regra das preventivas antigas: usuário ativo com a aba Preventivas liberada
create policy prev2_veiculos_tudo on public.prev2_veiculos for all to authenticated using (public.pode_ver('prev')) with check (public.pode_ver('prev'));
create policy prev2_planos_tudo on public.prev2_planos for all to authenticated using (public.pode_ver('prev')) with check (public.pode_ver('prev'));
create policy prev2_hist_tudo on public.prev2_hist for all to authenticated using (public.pode_ver('prev')) with check (public.pode_ver('prev'));
create policy prev2_cfg_tudo on public.prev2_cfg for all to authenticated using (public.pode_ver('prev')) with check (public.pode_ver('prev'));
grant select, insert, update, delete on public.prev2_veiculos, public.prev2_planos, public.prev2_hist, public.prev2_cfg to authenticated;
