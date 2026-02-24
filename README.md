<div align="center">

```
 ____   ___   ____ _  _______ ____  __  __    _    ____ _____ _____ ____  
|  _ \ / _ \ / ___| |/ / ____|  _ \|  \/  |  / \  / ___|_   _| ____|  _ \ 
| | | | | | | |   | ' /|  _| | |_) | |\/| | / _ \ \___ \ | | |  _| | |_) |
| |_| | |_| | |___| . \| |___|  _ <| |  | |/ ___ \ ___) || | | |___|  _ < 
|____/ \___/ \____|_|\_\_____|_| \_\_|  |_/_/   \_\____/ |_| |_____|_| \_\
```

**Master Docker for the KEA exam. One zone at a time.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash%204.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Git%20Bash-blue.svg)](#requirements)

</div>

---

**dockermaster** is a fully interactive terminal game that trains you on Docker — Dockerfiles, images, containers, Compose, port mapping, volumes, multi-stage builds, and build cache optimisation.

No installation. No dependencies. Just bash.

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

| Zone | Topic | Covers |
|------|-------|--------|
| 1 | **Core Concepts** | Dockerfile vs Image vs Container, the recipe/cake analogy |
| 2 | **Dockerfile** | `FROM` `WORKDIR` `COPY` `RUN` `ENTRYPOINT` |
| 3 | **Multi-stage Builds** | `AS build` `COPY --from` why it matters for image size |
| 4 | **Docker Commands** | `build` `run` `ps` `stop` `rm` `rmi` `prune` |
| 5 | **Docker Compose** | `compose.yaml` services, `up -d`, `down`, volumes, environment |
| 6 | **Port Mapping** | `3306:3306` vs `127.0.0.1:3306:3306`, cloud security implications |
| 7 | **Volumes & Cache** | `COPY` vs volumes, build cache layers, Dockerfile optimisation |

---

## How It Works

dockermaster is pure theory questions — multiple choice and typed answers — with detailed feedback on every wrong answer.

### When you get something wrong, it actually helps you

**Multiple choice** — tells you *why your specific pick was wrong*, not just what the right answer is:

```
  WRONG    COPY runs at build time -- it bakes files into the image permanently.
           Volumes inject files at runtime and can change dynamically.
  -> Correct answer: B) COPY bakes files into the image at build time; volumes inject at runtime

  +--[ TEACHING MOMENT ]--------------------------------------+
  |  COPY (build time): files baked into image, always there |
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

---

## Scoring

| Score | Grade |
|-------|-------|
| 90%+  | **12** — Outstanding |
| 75%+  | **10** — Excellent |
| 55%+  | **7**  — Good pass |
| 35%+  | **4**  — Passing |
| <35%  | **02** — Try again |

---

## CLI Options

```
bash dockermaster.sh               # full game (all 7 zones)
bash dockermaster.sh --zone 3      # jump straight to zone 3 (multi-stage)
bash dockermaster.sh --list        # list all zones with topics
bash dockermaster.sh --help        # show help
bash dockermaster.sh --version     # show version
```

---

## Requirements

| Platform | Requirement |
|----------|-------------|
| **macOS** | Terminal.app or iTerm2, bash 3.2+ |
| **Linux** | Any terminal emulator, bash 4.0+ |
| **Windows** | Git Bash (included with Git for Windows) |

No external packages needed. No Docker installation required to run the game itself.

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
<summary>Zone 2 — Dockerfile Instructions</summary>

- `FROM` — specifying the base image and why you choose it
- `WORKDIR` — setting the working directory (equivalent to `cd` in Linux)
- `COPY` — copying files from the host into the image at build time
- `RUN` — executing commands during the build (not at runtime)
- `ENTRYPOINT` — defining the default startup command for the container
- Array syntax vs string syntax for `ENTRYPOINT`

</details>

<details>
<summary>Zone 3 — Multi-stage Builds</summary>

- What a multi-stage build is: multiple `FROM` instructions in one Dockerfile
- Naming a stage with `AS build`
- Referencing a stage with `COPY --from=build`
- Why multi-stage builds keep the final image small and secure
- Build stage (Maven) vs runtime stage (Alpine JDK) for Java applications
- Only the last stage ends up in the final image

</details>

<details>
<summary>Zone 4 — Docker Commands</summary>

- `docker build .` — building an image from a Dockerfile
- `docker build --tag name:version .` — tagging an image
- `docker run -it image` — starting an interactive container
- `docker run --rm` — auto-removing the container on exit
- `docker ps` vs `docker ps -a` — running vs all containers
- `docker stop` vs `docker rm` — stopping vs removing
- `docker rmi` — removing images
- `docker container prune` / `docker image prune` / `docker system prune`

</details>

<details>
<summary>Zone 5 — Docker Compose</summary>

- Why Docker Compose exists: replacing many `docker run` commands with one file
- What a service is in `compose.yaml`
- `restart: always` — auto-restart on crash and Docker startup
- `docker compose up -d` — starting all services in the background
- `docker compose down` — stopping and removing containers
- Named volumes: declaring at the bottom, using inside services
- `MYSQL_` environment variables and why they only work on first start

</details>

<details>
<summary>Zone 6 — Port Mapping & Security</summary>

- Port mapping syntax: `HOST_PORT:CONTAINER_PORT`
- `3306:3306` — binds to `0.0.0.0` (all interfaces), accessible from anywhere
- `127.0.0.1:3306:3306` — binds to localhost only, safe
- Why `3306:3306` on a cloud server without a firewall is dangerous
- Recommended practice: always use `127.0.0.1` in development
- Connecting from outside: always use the HOST port, not the container port

</details>

<details>
<summary>Zone 7 — Volumes, COPY & Build Cache</summary>

- `COPY` (build time) vs volumes (runtime): when to use each
- Why secrets must never be baked into images with `COPY`
- How Docker's build cache works: each instruction = one layer
- Cache invalidation: one change rebuilds that layer and all after it
- Ordering Dockerfile instructions to maximise cache reuse
- Separating dependency download (`mvn dependency:resolve`) from compilation
- The `:ro` flag on volume mounts for read-only access

</details>

---

## Controls

| Key | Action |
|-----|--------|
| `A` / `B` / `C` / `D` | Answer multiple choice questions |
| `Ctrl+N` | Skip question and mark as correct |
| `Ctrl+B` | Undo the last question |
| `Enter` | Continue to next question |

---

## Contributing

Contributions are welcome — new zones, corrections, or better question explanations.

1. Fork the repo
2. Create a branch: `git checkout -b zone/cicd` or `git checkout -b fix/typo-zone5`
3. Make your changes
4. Open a PR with a short description

---

## Roadmap

- [ ] `--quick` mode: theory questions only, no extended explanations
- [ ] `--drill` mode: rapid-fire questions with no feedback between
- [ ] Zone 8: CI/CD & GitHub Actions integration with Docker
- [ ] Zone 9: Docker networking (`bridge`, `host`, `overlay`)
- [ ] Score history: track improvement across multiple runs
- [ ] Companion script: `linuxmaster` for Linux terminal fundamentals

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
