# Cloudflare IaC (windots redirect)

This Terraform stack manages only `windots.ilegna.dev`:

- proxied placeholder DNS records (`A 192.0.2.1`, `AAAA 100::`)
- dynamic redirect at Cloudflare edge to:
  - `https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1`

`cloudflare_ruleset.windots_redirect` manages the zone dynamic redirect ruleset for this phase. Keep other dynamic redirects in the same Terraform config to avoid dashboard drift.

## Inputs

Required at runtime:

- `CLOUDFLARE_API_TOKEN`
- `TF_VAR_zone_id`

Static config lives in `env/prod.tfvars`.

## Local commands

```bash
terraform -chdir=infra/cloudflare init
terraform -chdir=infra/cloudflare plan -var-file=env/prod.tfvars
terraform -chdir=infra/cloudflare apply -var-file=env/prod.tfvars
```

## GitHub Actions + Bitwarden

Workflow: `.github/workflows/infra-cloudflare.yml`.

Expected GitHub environment (`production`) values:

- `BWS_ACCESS_TOKEN`
- `BWS_CLOUDFLARE_ILEGNA_DEV_API_TOKEN`
- `BWS_CLOUDFLARE_ILEGNA_DEV_ZONE_ID`

The workflow retrieves Cloudflare runtime secrets via `bitwarden/sm-action@v2`, imports existing records/ruleset when present, then runs `terraform plan/apply`.

## Credential rotation

Current credentials expire on `2027-02-26`.

- Rotate `CLOUDFLARE_API_TOKEN` in Bitwarden before expiry.
- Rotate `BWS_ACCESS_TOKEN` (machine access token) before expiry.
- Keep secret IDs the same when possible to avoid workflow changes.
- After rotation, run `workflow_dispatch` once to confirm successful access.

GitHub automation reminder: `.github/workflows/credential-rotation-alert.yml` opens a reminder issue when less than 60 days remain.
