create table if not exists public.ai_usage_daily (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  scan_count integer not null default 0 check (scan_count >= 0),
  assistant_count integer not null default 0 check (assistant_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

alter table public.ai_usage_daily enable row level security;

drop policy if exists "Users read own ai usage" on public.ai_usage_daily;

create policy "Users read own ai usage"
  on public.ai_usage_daily for select
  using (auth.uid() = user_id);

create or replace function public.consume_ai_quota(
  p_user_id uuid,
  p_feature text,
  p_limit integer
)
returns table (
  allowed boolean,
  used integer,
  limit_value integer,
  reset_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'utc')::date;
  v_reset_at timestamptz := ((now() at time zone 'utc')::date + 1)::timestamptz;
  v_used integer;
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  if p_limit <= 0 then
    return query select false, 0, p_limit, v_reset_at;
    return;
  end if;

  insert into public.ai_usage_daily (user_id, usage_date)
  values (p_user_id, v_today)
  on conflict (user_id, usage_date) do nothing;

  if p_feature = 'scan' then
    update public.ai_usage_daily
    set scan_count = scan_count + 1,
        updated_at = now()
    where user_id = p_user_id
      and usage_date = v_today
      and scan_count < p_limit
    returning scan_count into v_used;

    if v_used is null then
      select scan_count into v_used
      from public.ai_usage_daily
      where user_id = p_user_id and usage_date = v_today;
      return query select false, coalesce(v_used, 0), p_limit, v_reset_at;
      return;
    end if;

    return query select true, v_used, p_limit, v_reset_at;
    return;
  end if;

  if p_feature = 'assistant' then
    update public.ai_usage_daily
    set assistant_count = assistant_count + 1,
        updated_at = now()
    where user_id = p_user_id
      and usage_date = v_today
      and assistant_count < p_limit
    returning assistant_count into v_used;

    if v_used is null then
      select assistant_count into v_used
      from public.ai_usage_daily
      where user_id = p_user_id and usage_date = v_today;
      return query select false, coalesce(v_used, 0), p_limit, v_reset_at;
      return;
    end if;

    return query select true, v_used, p_limit, v_reset_at;
    return;
  end if;

  raise exception 'Unsupported quota feature: %', p_feature;
end;
$$;

revoke all on function public.consume_ai_quota(uuid, text, integer)
  from public, anon, authenticated;
grant execute on function public.consume_ai_quota(uuid, text, integer)
  to service_role;
