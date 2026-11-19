# Changelog

Breaking changes are listed first in each entry.

## v0.1.29-railway.1 (2026-11-19)

- **Deploy form change (new deploys only):** `DATAFORSEO_API_KEY` is now a required field on the deploy form, with no default. Enter the base64 of your DataForSEO `login:password` (`printf '%s' 'LOGIN:PASSWORD' | base64`). Existing deployments keep their current variables; applying this update changes nothing in them.
- README: variable table and first steps say the key is required and give the Railway steps for setting or changing it. `TREG_API_TOKEN` and the other provider keys stay optional.
- No change to the image, the pinned version (OpenSEO v0.1.29) or the start scripts.

## v0.1.29 (2026-11-18)

- First release: OpenSEO standalone `v0.1.29` (`ghcr.io/every-app/open-seo-standalone:v0.1.29@sha256:5817dd88b16be5250eed170369c94b882f8ab40fb645f75dbd0da7c047207702`), one service plus a Railway Bucket, email and password accounts.
