[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/openseo-1?utm_medium=integration&utm_source=button&utm_campaign=openseo)

# OpenSEO on Railway

This repo packages [OpenSEO](https://github.com/every-app/open-seo) **v0.1.29** as a Railway template. OpenSEO is an open-source SEO workspace: keyword research, domain overview, backlinks, rank tracking, site audits, Local SEO, AI visibility tracking and an AI assistant (SAM), with your own data provider keys.

The template runs upstream's **standalone edition** (`ghcr.io/every-app/open-seo-standalone`), which has real email and password accounts. The service builds from this repo's `Dockerfile`, which pins the image by version **and** digest.

## What it deploys

| Service | Source | Role | Storage |
| --- | --- | --- | --- |
| **OpenSEO** (public) | this repo, `Dockerfile` | Runtime (`celld`), first-start setup and migrations, crawl gateway and Nginx, all in one container | Volume at `/var/lib/openseo` (`config/`: secrets generated on first start, `data/`: runtime state) |
| **Bucket** | Railway Bucket | S3 storage for the app's databases and files | Railway's managed bucket |

Upstream's Compose file runs five containers (storage, runtime, init, crawl-gateway, web) that share volumes and a network namespace. Railway services can't share either, so this image runs the runtime, init, crawl gateway and Nginx in one service, and uses a Railway Bucket instead of the RustFS container. The bucket passed `celld diagnose` (conditional create and overwrite), which the runtime needs.

On every start the container:

1. prepares the volume folders and drops to the image's unprivileged `node` user;
2. starts the runtime on `127.0.0.1:8080`;
3. runs upstream's `init.sh`: generates the app secrets on the first start (kept in `/var/lib/openseo/config`), loads the app and runs the database migrations;
4. starts the crawl gateway and Nginx on `PORT` (3001), with WebSocket upgrades for SAM.

The health check is `/api/health`. It answers 200 once sign-in is configured and the database is up, usually under a minute after the first start.

## Variables

The deploy form asks for one value: `DATAFORSEO_API_KEY`. Everything else has a default or is optional.

| Variable | Default | Notes |
| --- | --- | --- |
| `S3_ENDPOINT`, `CELLD_BUCKET`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | references to the Bucket | Storage wiring. Railway creates the bucket and its keys |
| `BETTER_AUTH_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public address used for sign-in links and cookies. Change it if you add a custom domain |
| `PORT` | `3001` | Nginx listens here; the public domain points to it |
| `DATAFORSEO_API_KEY` | **required**, no default | Base64 of `login:password` from [DataForSEO API Access](https://app.dataforseo.com/api-access): `printf '%s' 'LOGIN:PASSWORD' \| base64`. Keyword, backlink, rank and site data |
| `TREG_API_TOKEN` | empty, optional | treg token: the same DataForSEO data, paid per call. Used only while `DATAFORSEO_API_KEY` is empty, so after deploy you would clear that key to switch to treg |
| `OPENROUTER_API_KEY` | empty, optional | SAM conversations, website research and summaries |
| `OPENROUTER_BASE_URL`, `OPENROUTER_MODEL` | empty, optional | Another OpenAI-compatible server, and the model to use |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | empty, optional | Search Console and Analytics linking with your own Google OAuth app |
| `GOOGLE_MAPS_API_KEY` | empty, optional | Map in Local SEO |
| `CONTEXT_API_KEY` | empty, optional | JavaScript rendering for site audits |
| `CRAWLER_ACCESS_SECRET` | generated (48 chars) | Encrypts saved Shopify crawler signatures |

### Getting the DataForSEO key

`DATAFORSEO_API_KEY` is not the key shown on DataForSEO's dashboard. It is the base64 of your API login and API password:

1. Open [DataForSEO API Access](https://app.dataforseo.com/api-access) and copy your API login and API password (DataForSEO emails them on request).
2. On your computer, run `printf '%s' 'LOGIN:PASSWORD' | base64` with your own login and password.
3. Paste the output into the `DATAFORSEO_API_KEY` field of the deploy form.

To change it later: in Railway, open the **OpenSEO** service, then **Variables**, edit `DATAFORSEO_API_KEY` and deploy the change. The app reads it again on start, about a minute later.

OpenSEO's own in-app help page for the key only describes Cloudflare Workers. On Railway, use the steps above.

Fixed settings are in `start.sh` (`AUTH_MODE=password` and upstream's runtime limits). Any of them can be overridden with a variable on the service. Provider keys can be added or changed later; Railway redeploys the service and init applies them.

## After deploy

1. **Create the admin account right away.** Open the public URL: the first visitor creates the administrator's account, and registration then closes. Until you do it, anyone with the URL could take it.
2. Add teammates from invitation links in the app.
3. The DataForSEO key you entered at deploy powers keyword, domain, backlink and rank data. If the app shows "Setup needed", the key is empty: set it as described in [Getting the DataForSEO key](#getting-the-dataforseo-key). OpenSEO's in-app help page only covers Cloudflare.
4. For Google Search Console or Analytics, register your own OAuth app with the redirect URLs `https://YOUR-DOMAIN/api/gsc/oauth/callback` and `https://YOUR-DOMAIN/api/ga4/oauth/callback`. See upstream's [Search Console guide](https://github.com/every-app/open-seo/blob/main/docs/SELF_HOSTING_GOOGLE_SEARCH_CONSOLE.md).
5. With a custom domain, set `BETTER_AUTH_URL` to `https://YOUR-DOMAIN`.

## Resources

Upstream asks for about 2 GB of memory for the runtime (its `CELLD_MAX_RSS_MB` limit is 1536). In our tests the service used about 430 MB with one user and a few projects.

## Updates

Railway sends deployers an "update available" notice when this repo's `main` branch changes. Each change bumps the pinned version and digest and adds an entry to [`CHANGELOG.md`](CHANGELOG.md), with breaking changes listed first. Read it before you apply an update.

Database migrations run on start, and an older image doesn't undo them. Before you apply an update, back up the volume and the bucket (Railway volume backups, and a copy of the bucket with any S3 tool). The `config/` folder on the volume holds the generated secrets: keep it with the bucket, because the data can't be read without it.

## Not included

- **The legacy single-container image** (`ghcr.io/every-app/open-seo`, no accounts). Moving data from it needs upstream's one-time `migrate` service; see "Move from the old Docker image" in upstream's [self-hosting guide](https://github.com/every-app/open-seo/blob/main/docs/SELF_HOSTING_DOCKER.md).
- **Several replicas.** The runtime keeps local state on the volume, so run one instance.
- **Signing in with Google.** Upstream offers email and password accounts only.

## Local test

`docker build -t openseo-railway .`, then run it with an S3 store that supports conditional writes (for example RustFS, as upstream's Compose file does), the variables above, and a volume at `/var/lib/openseo`. Set `BETTER_AUTH_URL=http://localhost:3001` and publish port 3001. The template was tested this way and on Railway before publishing.

## License

The template files are MIT. OpenSEO is MIT.
