# Linux Quest — lab containers

Two images built on top of your existing systemd base image
(`base/Dockerfile` is your original file, unchanged, saved here just so
`docker-compose build` has something to build it from).

```
lq-quest/
├── base/Dockerfile          # your original image, verbatim
├── server1/                 # the container the participant SSHes into first
│   ├── Dockerfile
│   └── files/
│       ├── quest.log.template
│       └── fake-apache-worker.service
├── server2/                 # the "second server" container (nginx target)
│   ├── Dockerfile
│   └── files/
│       ├── web_page.conf
│       └── index.html
├── docker-compose.yml       # local test harness wiring the two together
└── README.md
```

## How each task maps to the setup

| Task | Where it lives |
|---|---|
| 0 — connect to server1 | sshd re-enabled on server1, `STUDENT_USER`/`STUDENT_PASS` account |
| 1 — fix permissions | `~/LQ/chest` is `root:root`, mode `700` — student must `sudo chmod`/`chown` |
| 2 — hidden secret | `~/LQ/chest/.secret` contains `SUBDOMAIN` |
| 3 — quest.log line 16 | `server1/files/quest.log.template`, `__DOMAIN__` substituted at build time, lands on line 16 |
| 4 — detective | `fake-apache-worker.service` runs a process renamed to `apache2` owned by `DETECTIVE_USER`, findable via `ps aux \| grep apache` |
| 5 — password.zip | `~/LQ/chest/password.zip` contains `password.txt` with `SERVER2_PASS` |
| 6 — jump to server2 | server2's sshd listens on `SSH_PORT`, account is `DETECTIVE_USER`/`SERVER2_PASS` |
| 7 — configure nginx | `/etc/nginx/conf.d/web_page.conf` ships with `server_name CHANGE_ME;` / `root CHANGE_ME;` placeholders; default site is disabled so only this vhost matters; nginx is installed but **not started** |
| 8 — reward page | `/var/www/web_page/index.html`, served once the vhost + `systemctl start nginx` are done |

## Parameterization

Both Dockerfiles take build args so your platform can generate a fresh
set of credentials per participant instead of using the shared defaults:

```
STUDENT_USER, STUDENT_PASS      # server1 login (Task 0)
DETECTIVE_USER, SERVER2_PASS    # server2 login (Tasks 4-6)
SUBDOMAIN                       # Task 2
DOMAIN                          # Task 3 / SSH target / part of final URL
SSH_PORT                        # server2's sshd port (Task 6, "port from the email")
```

Pass the same values to both `server1` and `server2` builds — they need
to agree (e.g. `DETECTIVE_USER`/`SERVER2_PASS` must match on both sides,
`DOMAIN`/`SUBDOMAIN` must match what's baked into server1's clues and
server2's nginx placeholder comment).

Whatever your platform uses to email participants their credentials
should be fed by the same values passed as build args here, so what's
on the container matches what's on the page.

## Networking note

Task 3's domain has to resolve to server2 from server1 (for the `ssh`
in Task 6), and the subdomain-of-that-domain has to resolve to server2
from wherever the participant's browser is (for Task 8). The included
`docker-compose.yml` handles the first case with a network alias for
local testing; the second (browser-facing) resolution depends on how
your platform exposes containers to participants (wildcard DNS +
reverse proxy, per-instance subdomain routing, etc.) — that part is
platform-specific and isn't something this Dockerfile can solve on its
own, so you'll want to point real DNS at server2's exposed HTTP port.

## Local test

```bash
cd lq-quest
docker compose build
docker compose up -d server1 server2

# Task 0, from your host:
ssh player@localhost -p 2201        # password: changeme

# inside server1, once you've solved tasks 1-5:
ssh watson@chucknorris.quest.local -p 2222   # password: hunter2

# inside server2, after Task 7:
curl -H "Host: vault.chucknorris.quest.local" http://localhost/
```

## A couple of things worth double-checking on your platform

- **Privileged mode / cgroups**: running systemd inside Docker generally
  needs `--privileged` (or at least `--cap-add SYS_ADMIN`) plus a tmpfs
  on `/run` and `/run/lock`, as set in `docker-compose.yml`. Adjust to
  whatever your orchestration layer already does for the base image.
- **sudo password vs NOPASSWD**: Task 7's note ("you will need to use
  sudo") is implemented as normal `sudo` group membership on server2,
  so the participant is prompted for their own password — not a
  NOPASSWD rule.
- **Task 4 realism**: rather than standing up real per-vhost Apache
  users (suexec/mod_ruid2), server2's clue is a lightweight decoy
  process named `apache2` running under the target user. It satisfies
  "found via `ps aux`" without the overhead of a real multi-tenant
  Apache config — swap in a real suexec setup if you want the artifact
  to be more literally accurate.
