# ExtremeRouter Railway Deployment Files

## 📦 Files Included

- `Dockerfile` — Multi-stage production build (no git clone, langsung COPY source)
- `railway.toml` — Railway deployment config
- `.dockerignore` — Docker build optimization

## 🚀 Quick Deploy

### 1. Fork/Clone ExtremeRouter

```bash
git clone https://github.com/rsalmn/extremerouter.git
cd extremerouter
```

Atau fork via GitHub UI, lalu clone fork lu.

### 2. Copy Files ke Root Repo

```bash
# Extract zip deployment files
# Copy 3 files ini ke root extremerouter/:
cp Dockerfile extremerouter/
cp railway.toml extremerouter/
cp .dockerignore extremerouter/
```

**Final structure:**
```
extremerouter/
├── src/
├── public/
├── package.json
├── next.config.js
├── ... (semua file original)
├── Dockerfile          ← ADDED
├── railway.toml        ← ADDED
└── .dockerignore       ← ADDED
```

### 3. Push ke GitHub

```bash
git add Dockerfile railway.toml .dockerignore
git commit -m "Add Railway deployment config"
git push origin main
```

### 4. Deploy ke Railway

**Via Railway Dashboard:**

1. Buka [railway.app](https://railway.app)
2. New Project → Deploy from GitHub repo
3. Pilih repo `extremerouter` lu
4. Railway auto-detect `railway.toml` dan mulai build

**Add Volume:**
- Settings → Volumes → Add Volume
- Mount Path: `/data`
- Size: 1GB

**Set Environment Variables:**
- Settings → Variables → Bulk Import from Raw Text:

```bash
JWT_SECRET=<openssl rand -base64 32>
INITIAL_PASSWORD=<your-strong-password>
HOSTNAME=0.0.0.0
NODE_ENV=production
DATA_DIR=/data
NEXT_TELEMETRY_DISABLED=1
```

**Update Base URL** (setelah deploy pertama):
```bash
NEXT_PUBLIC_BASE_URL=https://<your-app>.up.railway.app
BASE_URL=https://<your-app>.up.railway.app
```

### 5. Access Dashboard

```
https://<your-app>.up.railway.app/dashboard
```

Login dengan `INITIAL_PASSWORD` yang lu set.

---

## 🔧 Build Details

**Dockerfile stages:**
1. **deps** — npm ci production deps
2. **builder** — npm run build (Next.js compile)
3. **runner** — minimal runtime image, non-root user

**Build time:** ~4-6 menit (pertama kali), ~1-2 menit (cached)  
**Image size:** ~400MB  
**Runtime RAM:** ~300MB idle, ~500MB active

---

## 📊 Resource Requirements

**Railway Free Tier:**
- ✅ Build: 1-2GB RAM (lolos)
- ✅ Runtime: 300-500MB RAM (nyaman)
- ✅ Volume: 1GB (cukup)
- ⚠️ Build cost: ~$0.50 credit per deploy

**Recommended:** Railway Pro ($5/month) untuk production.

---

## 🐛 Troubleshooting

### Build OOM

Add env var:
```bash
NODE_OPTIONS=--max-old-space-size=1536
```

### Health Check Failed

Check Railway logs:
```bash
railway logs
```

Common issues:
- `/data` volume not mounted
- `DATA_DIR` env var missing
- Port binding error

### SQLite Permission Denied

Pastikan volume `/data` mounted dan env `DATA_DIR=/data` set.

---

## 📝 Notes

- Dockerfile ini **tanpa git clone** — langsung pakai source repo lu
- Update ExtremeRouter: merge upstream, commit, push → Railway auto-redeploy
- Security: container run sebagai non-root user (UID 1001)
- Health check: `/api/health` endpoint

---

**Built by Abuser ⚙️ for Klingon**
