# ============================================================
#  REFLEX - Despliegue a GitHub + Vercel (costo $0)
#  Uso:  .\deploy.ps1                 (repo "reflex-trainer")
#        .\deploy.ps1 -Repo mi-repo   (nombre personalizado)
#  Ejecutar en la carpeta que contiene index.html
# ============================================================
param([string]$Repo = "reflex-trainer")

function Need($cmd, $winget) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Host "Falta '$cmd'. Instalando con winget ($winget)..." -ForegroundColor Yellow
    winget install --id $winget -e --accept-source-agreements --accept-package-agreements
    Write-Host "Cierra y vuelve a abrir PowerShell, luego ejecuta de nuevo .\deploy.ps1" -ForegroundColor Yellow
    exit 1
  }
}

Write-Host "`n== 1/5 Verificando herramientas ==" -ForegroundColor Cyan
Need git  "Git.Git"
Need gh   "GitHub.cli"
Need node "OpenJS.NodeJS.LTS"

if (-not (Test-Path ".\index.html")) { Write-Host "No encuentro index.html en esta carpeta." -ForegroundColor Red; exit 1 }

# vercel.json: cabeceras para permitir micrófono y evitar caché vieja
if (-not (Test-Path ".\vercel.json")) {
@'
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Permissions-Policy", "value": "microphone=(self)" },
        { "key": "Cache-Control", "value": "public, max-age=0, must-revalidate" }
      ]
    }
  ]
}
'@ | Set-Content -Encoding utf8 .\vercel.json
}
if (-not (Test-Path ".\.gitignore")) { ".vercel`nnode_modules" | Set-Content -Encoding utf8 .\.gitignore }

Write-Host "`n== 2/5 Sesion de GitHub ==" -ForegroundColor Cyan
gh auth status 2>$null
if ($LASTEXITCODE -ne 0) { gh auth login --web --git-protocol https }

Write-Host "`n== 3/5 Commit local ==" -ForegroundColor Cyan
if (-not (Test-Path ".git")) { git init -b main | Out-Null }
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { git commit -m "REFLEX: entrenador reactivo de reflejos" | Out-Null; Write-Host "Commit creado." }
else { Write-Host "Sin cambios nuevos." }

Write-Host "`n== 4/5 Repositorio en GitHub ==" -ForegroundColor Cyan
git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  gh repo create $Repo --public --source . --remote origin --push
} else {
  git push -u origin main
}

Write-Host "`n== 5/5 Despliegue en Vercel (produccion) ==" -ForegroundColor Cyan
npx --yes vercel@latest whoami 2>$null
if ($LASTEXITCODE -ne 0) { npx --yes vercel@latest login }
npx --yes vercel@latest --prod --yes
# Conecta el repo para que cada 'git push' redepliegue solo (no es fatal si falla)
npx --yes vercel@latest git connect --yes 2>$null

Write-Host "`nListo. Abre la URL de produccion que imprimio Vercel (termina en .vercel.app)." -ForegroundColor Green
Write-Host "Para actualizar despues:  git add -A; git commit -m 'cambio'; git push" -ForegroundColor Green
