<div align="center">

```
 ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ ███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗
 ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
 ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝
 ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗
 ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║
 ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
```

**Learn Docker hands-on. One zone at a time.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash%204.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Git%20Bash-blue.svg)](#requirements)
[![Version](https://img.shields.io/badge/Version-1.1.0-blue.svg)](#)

</div>

---

**dockermaster** is a fully interactive terminal trainer covering Docker fundamentals — Dockerfiles, images, containers, Compose, port mapping, volumes, multi-stage builds, and build cache — with a live file-based lab environment where you write, edit, and fix real Docker files.

No installation. No dependencies. **Docker itself is not required.**

---

## Quick Start

```bash
# Option 1: clone and run
git clone https://github.com/bixson/dockermaster.git
cd dockermaster
bash dockermaster.sh

# Option 2: run directly (curl)
bash <(curl -fsSL https://raw.githubusercontent.com/bixson/dockermaster/master/dockermaster.sh)
```

---

## What You Train

| Zone | Topic | Covers | Lab |
|------|-------|--------|-----|
| 1 | **Core Concepts** | Dockerfile vs Image vs Container, the recipe/cake analogy | |
| 2 | **Dockerfile** | `FROM` `WORKDIR` `COPY` `RUN` `ENTRYPOINT` | ✓ |
| 3 | **Multi-stage Builds** | `AS build` `COPY --from` final image size | ✓ |
| 4 | **Docker Commands** | `build` `run` `ps` `stop` `rm` `rmi` `prune` | |
| 5 | **Docker Compose** | `compose.yaml` services, `up -d`, `down`, volumes | ✓ |
| 6 | **Port Mapping** | `3306:3306` vs `127.0.0.1:3306:3306`, cloud security | ✓ |
| 7 | **Volumes & Cache** | `COPY` vs volumes, build cache layers, optimisation | ✓ |

Zones marked ✓ include hands-on file tasks in the lab environment.

---

## How It Works

dockermaster combines **theory questions** and **hands-on lab tasks**. Lab tasks ask you to write, edit, or fix real Docker files in a sandbox — the script then verifies your work automatically.

### When you get something wrong, it actually helps you

**Multiple choice** — tells you *why your specific pick was wrong*, not just what the right answer is:

```
  WRONG    COPY runs at build time -- it bakes files into the image permanently.
           Volumes inject files at runtime and can change dynamically.
  -> Correct answer: B) COPY bakes files into the image at build time; volumes inject at runtime

  +--[ EXPLANATION ]------------------------------------------+
  |  COPY (build time): files baked into image, always there  |
  |  volumes (runtime): files injected when container starts  |
  |  Secrets in images can be extracted by anyone with access |
  +-----------------------------------------------------------+
  [TIP] COPY = baked in at build. Volumes = injected at runtime.
```

**Typed answers** — a directional hint, then one retry for half points:

```
  Not quite.  [Syntax: COPY --from=STAGE_NAME source destination]

  [RETRY] One more try for half points >
```

**Lab tasks** — the exact solution is shown on failure, then one more attempt for half points:

```
  [x] Verification failed.

  Solution:
    COPY pom.xml .
    RUN mvn dependency:resolve
    COPY src ./src
    RUN mvn clean package -DskipTests

  Why: The mvn dependency:resolve line must appear AFTER 'COPY pom.xml .'
       and BEFORE 'COPY src ./src'.

  Make the fix now, then press ENTER for half points:
```

---

## The Lab Environment

When the session starts, dockermaster creates a sandbox at `~/.dockermaster/lab/` with starter files, intentionally broken files to fix, and a reference card.

**Open a second terminal and work there:**

```bash
cd ~/.dockermaster/lab/
```

Docker does not need to be installed. All lab tasks involve reading and editing text files — Dockerfiles and `compose.yaml` — that are verified by the trainer automatically.

### Lab tasks by zone

| Zone | Task |
|------|------|
| **2a** | Write a complete four-instruction `Dockerfile` from scratch |
| **2b** | Find and remove a malicious `RUN` instruction that reads secrets at build time |
| **3** | Fix a broken multi-stage `Dockerfile` missing `COPY --from=build` |
| **5a** | Write a complete MySQL `compose.yaml` with named volumes and port mapping |
| **5b** | Convert a service from `image:` to a `build:` section |
| **6** | Fix an insecure `3306:3306` port binding to `127.0.0.1:3306:3306` |
| **7a** | Add a read-only volume mount for a config file in `compose.yaml` |
| **7b** | Reorder a `Dockerfile` to cache Maven dependencies separately from source code |

A `REFERENCE.md` cheat sheet covering all Dockerfile instructions, Compose syntax, port mapping rules, and Docker commands is generated in the lab directory at the start of each session.

---

## Scoring

| Score | Level |
|-------|-------|
| 90%+  | **Expert** — Excellent command of Docker fundamentals |
| 75%+  | **Proficient** — Solid knowledge, a few gaps to revisit |
| 55%+  | **Competent** — Good foundation, review weak zones |
| 35%+  | **Beginner** — Getting there, run it again |
| <35%  | **Try again** — Back to basics from zone 1 |

---

## CLI Options

```
bash dockermaster.sh               # full session (all 7 zones)
bash dockermaster.sh --zone 5      # jump straight to zone 5 (Compose)
bash dockermaster.sh --list        # list all zones with topics
bash dockermaster.sh --help        # show help and lab info
bash dockermaster.sh --version     # show version
```

---

## Controls

| Key | Action |
|-----|--------|
| `A` / `B` / `C` / `D` | Answer multiple choice questions |
| `Enter` | Submit typed answer or verify a lab task |
| `Ctrl+N` | Skip question or lab task and mark as correct |
| `Ctrl+B` | Undo the last question |
| `Ctrl+C` | Exit — shows score so far |

---

## Requirements

| Platform | Requirement |
|----------|-------------|
| **macOS** | Terminal.app or iTerm2, bash 3.2+ |
| **Linux** | Any terminal emulator, bash 4.0+ |
| **Windows** | Git Bash (included with Git for Windows) |

Docker does not need to be installed. The trainer detects whether Docker is present and notes it, but all labs are file-based and work without it.

---

## What You Practise (Detail)

<details>
<summary>Zone 1 — Core Concepts</summary>

- The Dockerfile / image / container relationship (recipe → cake → serving)
- What a Dockerfile is: a text file with build instructions
- What a Docker image is: a read-only artifact built from a Dockerfile
- What a container is: a running instance of an image
- The difference between an image and a container (class vs instance analogy)

</details>

<details>
<summary>Zone 2 — Dockerfile Instructions  [+ lab]</summary>

- `FROM` — specifying the base image and why you choose it
- `WORKDIR` — setting the working directory (equivalent to `cd` in Linux)
- `COPY` — copying files from the host into the image at build time
- `RUN` — executing commands during the build (not at runtime)
- `ENTRYPOINT` — defining the default startup command; array syntax vs string syntax
- **Lab 2a:** Write a complete Dockerfile from scratch using all five instructions
- **Lab 2b:** Identify and remove a dangerous `RUN` instruction that reads secrets at build time

</details>

<details>
<summary>Zone 3 — Multi-stage Builds  [+ lab]</summary>

- What a multi-stage build is: multiple `FROM` instructions in one Dockerfile
- Naming a stage with `AS build`
- Referencing a stage with `COPY --from=build`
- Why multi-stage builds keep the final image small and secure
- Build stage (Maven) vs runtime stage (Alpine JDK) for Java applications
- Only the last stage ends up in the final image
- **Lab 3:** Fix a broken multi-stage Dockerfile where `COPY --from=build` is missing

</details>

<details>
<summary>Zone 4 — Docker Commands</summary>

- `docker build .` and `docker build --tag name:version .`
- `docker run -it image` — starting an interactive container
- `docker run --rm` — auto-removing the container on exit
- `docker ps` vs `docker ps -a` — running vs all containers
- `docker stop` vs `docker rm` — stopping vs removing
- `docker rmi` — removing images
- `docker container prune` / `docker image prune` / `docker system prune`

</details>

<details>
<summary>Zone 5 — Docker Compose  [+ lab]</summary>

- Why Docker Compose exists: replacing many `docker run` commands with one file
- What a service is in `compose.yaml`
- `restart: always` — auto-restart on crash and Docker startup
- `docker compose up -d` — starting all services in the background
- `docker compose down` — stopping and removing containers
- Named volumes: declaring at the bottom, using inside services
- `MYSQL_` environment variables and why they only work on first start
- **Lab 5a:** Write a complete MySQL `compose.yaml` from scratch
- **Lab 5b:** Convert a service from `image:` to a `build:` section

</details>

<details>
<summary>Zone 6 — Port Mapping & Security  [+ lab]</summary>

- Port mapping syntax: `HOST_PORT:CONTAINER_PORT`
- `3306:3306` — binds to `0.0.0.0` (all interfaces), accessible from anywhere
- `127.0.0.1:3306:3306` — binds to localhost only, safe
- Why `3306:3306` on a cloud server without a firewall is a direct security exposure
- Recommended practice: always use `127.0.0.1` in development
- **Lab 6:** Fix an insecure port binding in a `compose.yaml`

</details>

<details>
<summary>Zone 7 — Volumes, COPY & Build Cache  [+ lab]</summary>

- `COPY` (build time) vs volumes (runtime): when to use each
- Why secrets must never be baked into images with `COPY`
- How Docker's build cache works: each instruction = one layer
- Cache invalidation: one change rebuilds that layer and all layers after it
- Ordering Dockerfile instructions to maximise cache reuse
- Separating dependency download (`mvn dependency:resolve`) from compilation
- The `:ro` flag on volume mounts for read-only access
- **Lab 7a:** Add a read-only volume mount for a config file in `compose.yaml`
- **Lab 7b:** Reorder a Dockerfile to cache Maven dependencies separately from source code

</details>

---

## Contributing

Contributions are welcome — new zones, improved questions, better lab tasks.

1. Fork the repo
2. Create a branch: `git checkout -b zone/networking` or `git checkout -b fix/typo-zone5`
3. Make your changes
4. Open a PR with a short description

---

## Roadmap

- [ ] `--quick` mode: theory questions only, no labs
- [ ] `--drill` mode: rapid-fire questions, no explanations between
- [ ] Zone 8: Docker networking (`bridge`, `host`, `overlay`)
- [ ] Zone 9: Docker security (non-root users, read-only filesystems, secret management)
- [ ] Score history: track improvement across multiple runs

---

## Related

If you want to train Linux terminal fundamentals alongside Docker, check out [dojomaster](https://github.com/bixson/dojomaster) — the same format, covering `cd`, `grep`, `chmod`, `ssh`, and more.

---

## License

MIT

---

<div align="center">

Made for anyone learning Docker from the command line.

If this helped you — consider leaving a star.

</div>