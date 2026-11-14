ALEE SHOPPING

Complete static storefront with shops, product details, cart, customer email/password accounts, and product comments. shops.html is the standalone shop directory opened by the Shops button.

For Supabase setup and publishing instructions, see SETUP.txt. Add shops with shop-manager.html and products with product-manager.html. Keep index.html, manifest.webmanifest, shops.html, shop.html, shops.js, products.js, backend-config.js, assets/, and images/ together. The ALEE logo is also configured as the installable home-screen app icon.

Banner Ad Pricing: the aleeshopping host can open the pricing manager from My Account → Banner Ad Pricing or Content Managers. Run banner-pricing-schema.sql once in the Supabase SQL Editor. Country ad, popup ad, banner, and verified badge rates then load from Supabase and can be changed without editing the site files.

Product recommendations: see RECOMMENDATION-SYSTEM-SETUP-SI.txt for the Supabase schema and setup steps. Run product-recommendations-schema.sql, enable pg_cron for hourly ranking, and publish index.html plus sponsored-products-manager.html. The existing Supabase/Postgres backend computes rankings; no separate server is needed.
