# OSGARD World — direct VPS deployment runbook

This project deploys to the existing Contabo VPS. Do not use Render or replace the current hosting stack as part of a routine release.

## Production target

- Public site: https://osgard.world
- VPS address: configured in the GitHub Actions secret `OSGARD_DEPLOY_HOST`
- Deployment container: `osgard-world`
- Workflow: `.github/workflows/deploy-frontend.yml`
- Remote activation script: `scripts/activate-frontend-remote.sh`

## Required GitHub Actions secrets

In **Settings → Secrets and variables → Actions**, create or update these repository secrets:

| Secret | Value |
| --- | --- |
| `OSGARD_DEPLOY_HOST` | VPS hostname or IP address |
| `OSGARD_DEPLOY_USER` | Linux account permitted to SSH and run the required Docker commands |
| `OSGARD_DEPLOY_KEY` | Complete private SSH key matching a public key in that account's `~/.ssh/authorized_keys` |

Never commit a private key, paste it into an issue/PR, or print it in workflow logs. Do not reuse a personal SSH key; use a dedicated deployment key. Prefer a dedicated, least-privilege deployment account with only the permissions required by the release script.

## Prepare SSH access

Generate a dedicated Ed25519 key pair on a trusted administrator computer:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/osgard_deploy -C osgard-world-deploy
```

Install the **public** key (`~/.ssh/osgard_deploy.pub`) in the deployment user's `~/.ssh/authorized_keys`. Keep the private key (`~/.ssh/osgard_deploy`) secret and store its full contents in `OSGARD_DEPLOY_KEY`.

Verify key login in a separate terminal before closing the existing administrative session:

```bash
ssh -i ~/.ssh/osgard_deploy DEPLOY_USER@DEPLOY_HOST
```

On Windows PowerShell, use the corresponding paths under `$HOME\.ssh\`.

## Run a release

1. Confirm the intended changes are merged into `master`.
2. Open **Actions → OSGARD frontend deploy**.
3. Select **Run workflow** on branch `master`.
4. Wait for every job step to finish successfully. A green workflow is necessary but not sufficient; inspect the final production checks too.
5. Verify the live site and the routes listed in the workflow's production checks.

The workflow builds the frontend, runs project smoke tests, exports the Godot web game, packages the site and Nginx configuration, validates archive checksums, transfers the release over SSH, activates it in the existing container, and performs production checks. Routine deployment should use this workflow rather than manually copying files into the live web root.

## Safe read-only diagnostics

SSH to the VPS with the deployment/admin account, then run:

```bash
hostname
df -h
free -h
docker ps -a
docker inspect osgard-world --format '{{.State.Status}}'
docker inspect osgard-world --format '{{json .Mounts}}'
docker exec osgard-world nginx -t
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' https://osgard.world/
```

These commands inspect server/container status; they do not intentionally change the deployment.

## If deployment fails

- **Missing secret:** create/update the named secret in repository Actions settings; never put the value in chat or logs.
- **SSH key rejected:** confirm the public key is installed for the exact user in `OSGARD_DEPLOY_USER`, and that the private key secret contains the full matching private key.
- **Host key scan fails:** confirm the IP/hostname and SSH service/network access. Do not disable host-key checking as a workaround.
- **Docker permission denied:** correct the deployment account's narrowly scoped permissions rather than switching to an unrestricted account without review.
- **Activation or production checks fail:** read the failing step logs. The activation script attempts to restore the prior site/config on its handled failure path; still verify the live site before retrying.
- **Never run destructive cleanup, replace Nginx configuration, or delete containers/volumes as a first troubleshooting step.**

## Recovery checklist

1. Stop and read the first failing workflow step.
2. Check that the currently served homepage and critical routes still return expected responses.
3. Inspect container status and Nginx configuration syntax.
4. Correct the underlying issue before retrying the workflow.
5. After a successful run, verify the homepage, Academy, game pages, SkillCred page, and the API health/readiness routes.

## Security hygiene

- Treat server passwords and private SSH keys as credentials. If a credential was shared in chat or another untrusted place, rotate it.
- Keep private keys out of the repository and terminal transcripts.
- Do not expose environment files, database credentials, API tokens, or `authorized_keys` contents in screenshots.
- Use the smallest practical set of permissions for the deploy account and GitHub token.
