-- Run once in the Supabase SQL Editor before using the homepage and product popup managers.
create table if not exists public.site_promotions (
  id uuid primary key default gen_random_uuid(),
  placement text not null check (placement in ('homepage', 'product_popup')),
  media_type text not null check (media_type in ('image', 'video')),
  media_url text not null,
  media_path text,
  title text not null default '',
  alt text not null default '',
  link text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint site_promotions_media_url_length check (char_length(media_url) between 1 and 2000),
  constraint site_promotions_link_length check (char_length(link) <= 2000)
);

alter table public.site_promotions enable row level security;
grant select on public.site_promotions to anon, authenticated;
grant insert, update, delete on public.site_promotions to authenticated;

drop policy if exists "Anyone can view site promotions" on public.site_promotions;
create policy "Anyone can view site promotions"
  on public.site_promotions for select
  to anon, authenticated
  using (true);

drop policy if exists "Only ALEE hosts can manage site promotions" on public.site_promotions;
create policy "Only ALEE hosts can manage site promotions"
  on public.site_promotions for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'))
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'site-promotion-media',
  'site-promotion-media',
  true,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif', 'video/mp4', 'video/webm', 'video/quicktime']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- The bucket is public so known media URLs can be displayed on the site.
-- Do not add a public SELECT policy: visitors should not be able to list its objects.
drop policy if exists "Public can view site promotion media" on storage.objects;

drop policy if exists "Only ALEE hosts can upload site promotion media" on storage.objects;
create policy "Only ALEE hosts can upload site promotion media"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'site-promotion-media'
    and lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  );

drop policy if exists "Only ALEE hosts can update site promotion media" on storage.objects;
create policy "Only ALEE hosts can update site promotion media"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'site-promotion-media'
    and lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  )
  with check (
    bucket_id = 'site-promotion-media'
    and lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  );

drop policy if exists "Only ALEE hosts can delete site promotion media" on storage.objects;
create policy "Only ALEE hosts can delete site promotion media"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'site-promotion-media'
    and lower(coalesce(auth.jwt() ->> 'email', '')) in ('aleeshopping2026@gmail.com', 'aleeshopping@gmail.com')
  );

-- Seed the current homepage slides so the site keeps its existing banners after setup.
insert into public.site_promotions (placement, media_type, media_url, title, alt, sort_order)
select 'homepage', 'image', 'assets/alee-banner2.jpg',
       'aleeshopping Panda — Fast & Safe Delivery',
       'aleeshopping Panda — Fast & Safe Delivery', 0
where not exists (select 1 from public.site_promotions where placement = 'homepage');

insert into public.site_promotions (placement, media_type, media_url, title, alt, sort_order)
select 'homepage', 'image', 'assets/alee-banner.jpg',
       'aleeshopping promotion', 'aleeshopping promotion', 1
where not exists (select 1 from public.site_promotions where placement = 'homepage' and sort_order = 1);
