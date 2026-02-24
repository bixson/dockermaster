#!/usr/bin/env bash
# =============================================================================
#
#   DOCKERMASTER  --  Learn Docker hands-on. One zone at a time.
#
#   A fully interactive terminal trainer covering Docker fundamentals:
#   Dockerfiles, images, containers, Compose, port mapping, volumes,
#   multi-stage builds, build cache -- with a live file-based lab
#   environment where you write, edit and fix real Docker files.
#
#   Works on: macOS, Linux, Git Bash (Windows)
#   Requires: bash 4.0+  (Docker NOT required to run the trainer)
#
#   Usage:
#     bash dockermaster.sh               # full session
#     bash dockermaster.sh --zone 3      # jump to a specific zone
#     bash dockermaster.sh --list        # show all zones
#     bash dockermaster.sh --help        # show this help
#
#   Lab directory: ~/.dockermaster/lab/
#     Open a second terminal, cd there, and follow the lab prompts.
#
# =============================================================================

VERSION="1.1.0"
GAME_NAME="dockermaster"
GAMEDIR="$HOME/.dockermaster"
LABDIR="$GAMEDIR/lab"
LOGFILE="$GAMEDIR/session.log"

# -- Colours ------------------------------------------------------------------
R=$'\033[0;31m'   RED=$'\033[1;31m'
G=$'\033[0;32m'   GRN=$'\033[1;32m'
Y=$'\033[0;33m'   YLW=$'\033[1;33m'
B=$'\033[0;34m'   BLU=$'\033[1;34m'
M=$'\033[0;35m'   MAG=$'\033[1;35m'
C=$'\033[0;36m'   CYN=$'\033[1;36m'
W=$'\033[1;37m'   DIM=$'\033[2m'
RST=$'\033[0m'    BOLD=$'\033[1m'
BG_RED=$'\033[41m'  BG_GRN=$'\033[42m'  BG_YLW=$'\033[43m'

# -- Game state ---------------------------------------------------------------
SCORE=0
MAX_SCORE=0
CORRECT=0
WRONG=0
RETRIED=0
ZONE=0
START_ZONE=1
PLAYER_NAME=""
LAB_TASKS=0
LAB_CORRECT=0

declare -a QUESTION_HISTORY=()
CURRENT_Q_INDEX=0

# =============================================================================
#  CLI FLAGS
# =============================================================================
show_help() {
  cat << 'HELP'

  dockermaster v1.1.0 -- Learn Docker hands-on. One zone at a time.

  USAGE
    bash dockermaster.sh               Run the full session
    bash dockermaster.sh --zone N      Start at zone N (1-7)
    bash dockermaster.sh --list        List all zones
    bash dockermaster.sh --help        Show this help
    bash dockermaster.sh --version     Show version

  ZONES
    1  Core Concepts     Dockerfile vs Image vs Container
    2  Dockerfile        FROM, WORKDIR, COPY, RUN, ENTRYPOINT  [+ lab]
    3  Multi-stage       AS build, COPY --from, final image size [+ lab]
    4  Docker Commands   build, run, ps, stop, rm, image ls
    5  Docker Compose    compose.yaml, services, up, down       [+ lab]
    6  Port Mapping      3306:3306 vs 127.0.0.1:3306:3306       [+ lab]
    7  Volumes & Cache   COPY vs volumes, build cache, order    [+ lab]

  LAB ENVIRONMENT
    Zones marked [+ lab] include hands-on file tasks.
    A sandbox is created at: ~/.dockermaster/lab/
    Open a second terminal and: cd ~/.dockermaster/lab/
    Docker does NOT need to be installed to complete the labs.

  SCORING
    100-90% = Expert    89-75% = Proficient    74-55% = Competent
     54-35% = Beginner    <35% = Try again

  CONTROLS
    Ctrl+N  -- skip question and mark as correct
    Ctrl+B  -- undo last question

HELP
  exit 0
}

show_list() {
  echo
  echo "  ${BOLD}${CYN}dockermaster v${VERSION}${RST}"
  echo
  echo "  ${YLW}1${RST}  Core Concepts     Dockerfile vs Image vs Container"
  echo "  ${YLW}2${RST}  Dockerfile        FROM, WORKDIR, COPY, RUN, ENTRYPOINT  ${DIM}[+ lab]${RST}"
  echo "  ${YLW}3${RST}  Multi-stage       AS build, COPY --from, image size      ${DIM}[+ lab]${RST}"
  echo "  ${YLW}4${RST}  Docker Commands   build, run, ps, stop, rm, image ls"
  echo "  ${YLW}5${RST}  Docker Compose    compose.yaml, services, up, down       ${DIM}[+ lab]${RST}"
  echo "  ${YLW}6${RST}  Port Mapping      3306:3306 vs 127.0.0.1:3306:3306       ${DIM}[+ lab]${RST}"
  echo "  ${YLW}7${RST}  Volumes & Cache   COPY vs volumes, build cache, order    ${DIM}[+ lab]${RST}"
  echo
  echo "  Lab directory: ~/.dockermaster/lab/"
  echo "  Run: bash dockermaster.sh --zone N  to jump to a zone"
  echo
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)    show_help ;;
      --list|-l)    show_list ;;
      --version|-v) echo "dockermaster v${VERSION}"; exit 0 ;;
      --zone|-z)
        if [[ -z "$2" || ! "$2" =~ ^[1-7]$ ]]; then
          echo "  Error: --zone requires a number 1-7"; exit 1
        fi
        START_ZONE="$2"; shift ;;
      *) echo "  Unknown option: $1. Try --help"; exit 1 ;;
    esac
    shift
  done
}

# =============================================================================
#  VISUAL HELPERS
# =============================================================================
sep()    { printf "\n  ${DIM}${C}%s${RST}\n" "-----------------------------------------------------------"; }
bigcap() { printf "  ${BOLD}${C}%s${RST}\n"  "==========================================================="; }
pause()  { echo; printf "  ${DIM}[ Press ENTER to continue ]${RST}"; read -r; }
blank()  { echo; }

typeit() {
  local text="$1" delay="${2:-18}"
  local i char
  for (( i=0; i<${#text}; i++ )); do
    char="${text:$i:1}"
    printf "%s" "$char"
    sleep "0.0${delay}" 2>/dev/null || true
  done
  echo
}

pbar() {
  local cur="$1" max="$2" width="${3:-40}"
  local filled=$(( (cur * width) / max ))
  local bar="" i
  for ((i=0; i<filled; i++));     do bar+="#"; done
  for ((i=filled; i<width; i++)); do bar+="-"; done
  local pct=$(( (cur * 100) / max ))
  printf "  [%s] %d%%\n" "$bar" "$pct"
}

zone_header() {
  local num="$1" name="$2" sub="$3"
  clear; ZONE="$num"
  bigcap
  printf "  ${BOLD}${CYN}ZONE %s // %s${RST}\n" "$num" "$name"
  printf "  ${DIM}%s${RST}\n" "$sub"
  bigcap; blank
}

lab_header() {
  blank; sep
  printf "  ${BOLD}${MAG}[ LAB ] %s${RST}\n" "$1"
  printf "  ${DIM}%s${RST}\n" "$2"
  printf "  ${DIM}Working directory: ${W}~/.dockermaster/lab/${RST}\n"
  sep; blank
}

# -- Feedback boxes -----------------------------------------------------------
teach() {
  blank
  printf "  ${BOLD}${BLU}+--[ EXPLANATION ]%s+${RST}\n" "----------------------------------------"
  for line in "$@"; do
    printf "  ${BLU}|${RST}  %-56s  ${BLU}|${RST}\n" "$line"
  done
  printf "  ${BOLD}${BLU}+%s+${RST}\n" "-------------------------------------------------------------"
}

tip()           { echo "  ${BOLD}${YLW}[TIP]${RST}${YLW} ${1}${RST}"; }
correct_box()   { echo "  ${BOLD}${BG_GRN}  CORRECT  ${RST}${GRN}  ${1:-}${RST}"; }
wrong_box()     { echo "  ${BOLD}${BG_RED}  WRONG    ${RST}${R}  ${1}${RST}"; }
answer_reveal() { echo "  ${BOLD}${CYN}  -> Correct answer:${RST}${W} ${1}${RST}"; }
lab_pass()      { echo "  ${BOLD}${BG_GRN}  LAB PASS ${RST}${GRN}  ${1:-File verified.}${RST}"; }
lab_fail()      { echo "  ${BOLD}${BG_RED}  LAB FAIL ${RST}${R}  ${1}${RST}"; }

# -- Score helpers ------------------------------------------------------------
_award() {
  local p="$1"
  SCORE=$((SCORE + p)); MAX_SCORE=$((MAX_SCORE + p)); CORRECT=$((CORRECT + 1))
  printf "  ${GRN}${BOLD}+%d pts${RST}\n" "$p"
}

_miss() {
  local p="$1"
  MAX_SCORE=$((MAX_SCORE + p)); WRONG=$((WRONG + 1))
  printf "  ${RED}${BOLD}+0 pts${RST}\n"
}

_half() {
  local p="$1" half
  half=$(( p / 2 )); [[ $half -lt 1 ]] && half=1
  SCORE=$((SCORE + half)); MAX_SCORE=$((MAX_SCORE + p)); RETRIED=$((RETRIED + 1))
  printf "  ${YLW}${BOLD}+%d pts${RST}${YLW} (half credit -- correct on retry)${RST}\n" "$half"
}

# =============================================================================
#  ask_mc -- Multiple choice with per-wrong-option explanations
# =============================================================================
ask_mc() {
  local q="$1"
  local oa="$2" ob="$3" oc="$4" od="$5"
  local correct="${6^^}" pts="$7"
  local wa="$8" wb="$9" wc="${10}" wd="${11}"
  local teaching="${12}" memtip="${13}"

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank
  echo "  ${W}${q}${RST}"
  blank
  echo "  ${YLW}A)${RST} $oa"
  echo "  ${YLW}B)${RST} $ob"
  echo "  ${YLW}C)${RST} $oc"
  echo "  ${YLW}D)${RST} $od"
  blank

  local ans ans2
  while true; do
    printf "  ${CYN}Your answer [A/B/C/D]: ${RST}"
    read -rsn1 ans

    if [[ "$ans" == $'\x0e' ]]; then
      echo; printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
      correct_box; _award "$pts"; return 0
    elif [[ "$ans" == $'\x02' ]]; then
      echo; printf "  ${YLW}[UNDO - Question reset]${RST}\n"
      SCORE="$score_before"; MAX_SCORE="$max_before"; CORRECT="$correct_before"
      WRONG="$wrong_before"; RETRIED="$retried_before"
      unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
      return 0
    fi

    ans="${ans^^}"
    case "$ans" in A|B|C|D) break ;; esac
    echo; echo "  ${R}  Please type A, B, C or D${RST}"
  done

  echo
  printf "  ${DIM}You chose: %s${RST}\n" "$ans"

  if [[ "$ans" == "$correct" ]]; then
    correct_box; _award "$pts"; return
  fi

  local why_theirs
  case "$ans" in
    A) why_theirs="$wa" ;; B) why_theirs="$wb" ;;
    C) why_theirs="$wc" ;; D) why_theirs="$wd" ;;
  esac
  wrong_box "${why_theirs:-That option is incorrect.}"

  local correct_text
  case "$correct" in
    A) correct_text="A) $oa" ;; B) correct_text="B) $ob" ;;
    C) correct_text="C) $oc" ;; D) correct_text="D) $od" ;;
  esac

  # One retry for half points (do not reveal the answer yet)
  while true; do
    printf "  ${YLW}  [RETRY] One more try for half points [A/B/C/D]: ${RST}"
    read -rsn1 ans2
    ans2="${ans2^^}"
    case "$ans2" in A|B|C|D) break ;; esac
    echo; echo "  ${R}  Please type A, B, C or D${RST}"
  done

  echo
  printf "  ${DIM}You chose: %s${RST}\n" "$ans2"

  if [[ "$ans2" == "$correct" ]]; then
    correct_box "Correct on retry!"; _half "$pts"; return
  fi

  wrong_box "Still not right. Moving on."
  answer_reveal "$correct_text"
  _miss "$pts"

  if [[ -n "$teaching" ]]; then
    IFS='|' read -ra tlines <<< "$teaching"
    teach "${tlines[@]}"
  fi
  [[ -n "$memtip" ]] && tip "$memtip"
}

# =============================================================================
#  ask_typed -- Free-text with ONE retry at half points
# =============================================================================
ask_typed() {
  local q="$1" expected="$2" pts="$3"
  local retry_hint="${4:-}" teaching="${5:-}" memtip="${6:-}" mode="${7:-exact}"

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank; echo "  ${W}${q}${RST}"
  printf "  ${CYN}> ${RST}"

  read -rsn1 ans_first
  if [[ "$ans_first" == $'\x0e' ]]; then
    echo; printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
    correct_box; _award "$pts"; return 0
  elif [[ "$ans_first" == $'\x02' ]]; then
    echo; printf "  ${YLW}[UNDO - Question reset]${RST}\n"
    SCORE="$score_before"; MAX_SCORE="$max_before"; CORRECT="$correct_before"
    WRONG="$wrong_before"; RETRIED="$retried_before"
    unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
    return 0
  fi

  # Echo first character so input is visible
  printf "%s" "$ans_first"

  local ans ans2
  read -r ans_rest
  ans="${ans_first}${ans_rest}"
  ans="$(echo "$ans" | xargs 2>/dev/null || echo "$ans")"

  _typed_match() {
    local a="${1,,}" e="${2,,}"
    if [[ "$mode" == "contains" ]]; then echo "$a" | grep -qiF "$e"
    else [[ "$a" == "$e" ]]; fi
  }

  if _typed_match "$ans" "$expected"; then
    correct_box; _award "$pts"; return
  fi

  echo "  ${R}  Not quite.${RST}  ${DIM}${retry_hint}${RST}"
  blank
  printf "  ${YLW}  [RETRY] One more try for half points > ${RST}"; read -r ans2
  ans2="$(echo "$ans2" | xargs 2>/dev/null || echo "$ans2")"

  if _typed_match "$ans2" "$expected"; then
    correct_box "Correct on retry!"; _half "$pts"; return
  fi

  wrong_box "Still not right. Moving on."
  answer_reveal "$expected"; _miss "$pts"
  if [[ -n "$teaching" ]]; then
    IFS='|' read -ra tlines <<< "$teaching"; teach "${tlines[@]}"
  fi
  [[ -n "$memtip" ]] && tip "$memtip"
}

# =============================================================================
#  do_task -- Hands-on lab task: user acts in second terminal, we verify here
#
#  do_task  "instruction text"
#           "shell check expression (runs in LABDIR context)"
#           pts
#           "exact solution to show on failure"
#           "explanation why"
# =============================================================================
do_task() {
  local instr="$1" check="$2" pts="$3"
  local solution="${4:-}" explanation="${5:-}"

  LAB_TASKS=$((LAB_TASKS + 1))

  local score_before="$SCORE" max_before="$MAX_SCORE" correct_before="$CORRECT" wrong_before="$WRONG" retried_before="$RETRIED"
  QUESTION_HISTORY+=("${score_before}|${max_before}|${correct_before}|${wrong_before}|${retried_before}|${pts}")

  blank
  printf "  ${MAG}${BOLD}[ TASK ]${RST} ${W}%s${RST}\n" "$instr"
  blank
  printf "  ${DIM}-> Do this in your lab terminal (cd ~/.dockermaster/lab/)${RST}\n"
  printf "  ${DIM}-> When done, press ENTER here to verify.${RST}\n"

  local input
  read -rsn1 input

  if [[ "$input" == $'\x0e' ]]; then
    echo; printf "  ${YLW}[SKIPPED - Mark as correct]${RST}\n"
    lab_pass "Task accepted."; _award "$pts"; LAB_CORRECT=$((LAB_CORRECT + 1))
    return 0
  elif [[ "$input" == $'\x02' ]]; then
    echo; printf "  ${YLW}[UNDO - Task reset]${RST}\n"
    SCORE="$score_before"; MAX_SCORE="$max_before"; CORRECT="$correct_before"
    WRONG="$wrong_before"; RETRIED="$retried_before"; LAB_TASKS=$((LAB_TASKS - 1))
    unset 'QUESTION_HISTORY[-1]'; QUESTION_HISTORY=("${QUESTION_HISTORY[@]}")
    return 0
  fi

  # Run check in LABDIR context
  if (cd "$LABDIR" && eval "$check" &>/dev/null 2>&1); then
    lab_pass; _award "$pts"; LAB_CORRECT=$((LAB_CORRECT + 1)); return
  fi

  blank
  printf "  ${RED}${BOLD}  [x] Verification failed.${RST}\n"
  blank
  if [[ -n "$solution" ]]; then
    printf "  ${W}  Solution:${RST}\n"
    IFS='|' read -ra slines <<< "$solution"
    for sline in "${slines[@]}"; do
      printf "  ${BOLD}${CYN}    %s${RST}\n" "$sline"
    done
  fi
  [[ -n "$explanation" ]] && printf "\n  ${DIM}  Why: %s${RST}\n" "$explanation"
  blank
  printf "  ${YLW}  Make the fix now, then press ENTER for half points:${RST}\n"
  read -r

  if (cd "$LABDIR" && eval "$check" &>/dev/null 2>&1); then
    lab_pass "Correct after hint!"; _half "$pts"; LAB_CORRECT=$((LAB_CORRECT + 1)); return
  fi

  lab_fail "Still not verified. Moving on."; _miss "$pts"
}

# =============================================================================
#  SETUP -- creates lab environment with starter / broken files
# =============================================================================
log() { echo "$(date '+%H:%M:%S') $*" >> "$LOGFILE" 2>/dev/null; }

setup_game() {
  rm -rf "$GAMEDIR"
  mkdir -p "$LABDIR"
  log "Session started v${VERSION}"

  # -- Zone 2 lab: write a Dockerfile from scratch (empty starter) -----------
  cat > "$LABDIR/Dockerfile" << 'EOF'
# ZONE 2 LAB -- Complete this Dockerfile
# Task: Fill in the missing instructions below.
# When done, the file should:
#   1. Start FROM alpine:latest
#   2. Set WORKDIR to /app
#   3. RUN echo "dockermaster" > welcome.txt
#   4. ENTRYPOINT ["cat", "/app/welcome.txt"]

EOF

  # -- Zone 3 lab: broken multi-stage (missing COPY --from) ------------------
  mkdir -p "$LABDIR/multistage"
  cat > "$LABDIR/multistage/Dockerfile" << 'EOF'
# ZONE 3 LAB -- Fix this multi-stage Dockerfile
# The COPY --from line in the runtime stage is missing.
# Add it so the compiled jar is copied from the build stage.

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jdk-alpine
WORKDIR /app
# <<< ADD COPY --from=build HERE: copy /app/target/*.jar to app.jar >>>
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

  # -- Zone 5 lab: write compose.yaml from scratch (empty starter) -----------
  mkdir -p "$LABDIR/myapp"
  cat > "$LABDIR/myapp/compose.yaml" << 'EOF'
# ZONE 5 LAB -- Write a compose.yaml for a MySQL service
# Requirements:
#   service name: mysql
#   image: mysql:latest
#   container_name: my-mysql
#   restart: always
#   environment:
#     MYSQL_ROOT_PASSWORD: secret
#     MYSQL_DATABASE: appdb
#   ports: 127.0.0.1:3307:3306
#   volume: mysql_data:/var/lib/mysql
# Don't forget the top-level volumes: section

EOF

  # -- Zone 6 lab: insecure port mapping to fix ------------------------------
  mkdir -p "$LABDIR/insecure"
  cat > "$LABDIR/insecure/compose.yaml" << 'EOF'
# ZONE 6 LAB -- Fix the insecure port mapping below
# The port mapping exposes MySQL to all network interfaces.
# Change it so it only listens on localhost (127.0.0.1).

services:
  mysql:
    image: mysql:latest
    container_name: secure-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: secret
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
EOF

  # -- Zone 7 lab: unoptimised Dockerfile to fix layer order -----------------
  mkdir -p "$LABDIR/cache"
  cat > "$LABDIR/cache/Dockerfile" << 'EOF'
# ZONE 7 LAB -- Optimise the build cache layer order
# Problem: src is copied before dependencies are resolved,
# so every source code change re-downloads all Maven dependencies.
#
# Fix: reorder so dependencies are downloaded in a separate
# RUN mvn dependency:resolve step BEFORE copying src.

FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jdk-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

  # -- Zone 7 lab 2: add a volume mount to compose.yaml ----------------------
  mkdir -p "$LABDIR/volumes"
  cat > "$LABDIR/volumes/compose.yaml" << 'EOF'
# ZONE 7 LAB -- Add a volume mount for the config file
# The backend service needs application.properties injected at runtime.
# Add a volumes: entry that mounts:
#   ./application.properties -> /app/application.properties (read-only)

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      SPRING_CONFIG_LOCATION: file:/app/application.properties
EOF

  # Create the config file they'll be mounting
  cat > "$LABDIR/volumes/application.properties" << 'EOF'
server.port=8080
database.url=jdbc:mysql://127.0.0.1:3307/appdb
database.username=appuser
database.password=changeme
EOF

  # -- Cheat sheet reference (read-only helper) ------------------------------
  cat > "$LABDIR/REFERENCE.md" << 'EOF'
# dockermaster -- Lab Reference Card

## Dockerfile Instructions
FROM image:tag              Base image
WORKDIR /path               Set working directory
COPY source dest            Copy files from host into image (build time)
RUN command                 Execute during build
ENTRYPOINT ["cmd","arg"]    Default startup command (runtime)

## Multi-stage
FROM image AS stagename     Name a build stage
COPY --from=stagename src   Copy artifact from named stage

## compose.yaml Structure
services:
  servicename:
    image: name:tag
    build:
      context: .
      dockerfile: Dockerfile
    container_name: name
    restart: always
    ports:
      - "127.0.0.1:HOST:CONTAINER"
    volumes:
      - namedvol:/container/path
      - ./hostfile:/container/file:ro
    environment:
      KEY: value

volumes:
  namedvol:

## Port Mapping Security
3306:3306              UNSAFE -- binds to all interfaces (0.0.0.0)
127.0.0.1:3306:3306    SAFE  -- binds to localhost only

## Docker Commands
docker build --tag name:ver .     Build and tag an image
docker run -it image              Start interactive container
docker run --rm -it image         Auto-remove container on exit
docker ps                         List running containers
docker ps -a                      List all containers
docker stop <name>                Graceful stop
docker rm <name>                  Remove stopped container
docker rmi <image>                Remove image
docker compose up -d              Start all services in background
docker compose down               Stop and remove containers
EOF

  log "Lab environment created at ${LABDIR}"
}

# =============================================================================
#  DETECT ENVIRONMENT
# =============================================================================
detect_env() {
  local os
  case "$(uname -s 2>/dev/null)" in
    Darwin)  os="macOS" ;;
    Linux)   os="Linux" ;;
    MINGW*|MSYS*|CYGWIN*) os="Windows (Git Bash)" ;;
    *)       os="Unknown" ;;
  esac
  local docker_status
  if command -v docker &>/dev/null; then
    docker_status="${GRN}installed${RST}"
  else
    docker_status="${YLW}not found${DIM} (labs still work -- no Docker needed)${RST}"
  fi
  printf "  ${DIM}System: %s  |  Shell: bash %s${RST}\n" "$os" "${BASH_VERSION%%(*}"
  printf "  ${DIM}Docker: %b${RST}\n" "$docker_status"
}

# =============================================================================
#  INTRO
# =============================================================================
intro() {
  clear
  printf "${BOLD}${BLU}"
  cat << 'BANNER'

                  º|/°
                  º\|                   '(`·¸·´)
               /¯¯º¯¯¯¯¯¯` · ¸           ,' ',
              |    @           ` · - · ´   ¸'
               \¸__¸.·''               ¸,·'
                '' ··--------·''·¸¸)· - ·“

  ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗
  ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
  ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝
  ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
  ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║
  ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
  ███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗
  ████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
  ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝
  ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗
  ██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║
  ╚═╝     ╚═╝╚╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝

BANNER
  printf "${RST}"
  printf "  ${BOLD}${W}Learn Docker hands-on. One zone at a time.${RST}\n"
  printf "  ${DIM}Theory questions + live file-based labs  |  v%s${RST}\n" "$VERSION"
  blank; detect_env; sep; blank

  printf "  ${W}Your name: ${RST}"
  read -r PLAYER_NAME
  [[ -z "$PLAYER_NAME" ]] && PLAYER_NAME="Learner"

  blank
  printf "  ${CYN}Welcome, ${BOLD}%s${RST}${CYN}.${RST}\n" "$PLAYER_NAME"
  blank

  printf "  ${W}How this works:${RST}\n"
  blank
  printf "  ${YLW}Theory questions${RST} -- multiple choice and typed answers.\n"
  printf "  ${YLW}Lab tasks${RST}        -- real file work in a sandbox. Two modes:\n"
  blank
  printf "  ${DIM}  Option A: Open a second terminal and run:${RST}\n"
  printf "  ${BOLD}${W}            cd ~/.dockermaster/lab/${RST}\n"
  printf "  ${DIM}  Option B: If you prefer, do lab tasks in this terminal first,${RST}\n"
  printf "  ${DIM}            then come back here and press ENTER to verify.${RST}\n"
  blank
  printf "  ${DIM}  A REFERENCE.md cheat sheet is available in the lab directory.${RST}\n"
  printf "  ${DIM}  Docker does NOT need to be installed to complete labs.${RST}\n"
  blank
}

# =============================================================================
#  ZONE 1 -- CORE CONCEPTS
# =============================================================================
zone_concepts() {
  zone_header 1 "CORE CONCEPTS" "Dockerfile vs Image vs Container -- the recipe/cake analogy"

  ask_mc "What is the correct analogy for the relationship between Dockerfile, Docker image, and container?" \
    "Dockerfile = cake, image = recipe, container = serving" \
    "Dockerfile = recipe, image = cake, container = serving of the cake" \
    "Dockerfile = serving, image = recipe, container = cake" \
    "Dockerfile = oven, image = serving, container = recipe" \
    "B" 10 \
    "The Dockerfile is the instruction set (recipe), not the final product." \
    "" \
    "The serving is the running instance (container), not the static artifact." \
    "The oven is not a useful part of this analogy." \
    "Dockerfile = recipe (instructions)|Image = cake (the built artifact)|Container = serving the cake (a running instance)|One image can produce many containers.|One Dockerfile builds one image." \
    "Dockerfile=recipe, Image=cake, Container=serving."

  ask_mc "What is a Dockerfile?" \
    "A running Linux process that hosts your application" \
    "A compressed binary that contains your application and its runtime" \
    "A text file containing instructions to build a Docker image" \
    "A YAML file that defines which containers to start" \
    "C" 10 \
    "A running process describes a container, not a Dockerfile." \
    "A compressed binary with runtime describes a Docker image." \
    "" \
    "A YAML file that starts containers describes compose.yaml, not a Dockerfile." \
    "Dockerfile = text file with build instructions|It tells Docker: which base image, which files to copy, which commands to run, how to start the app.|You build a Dockerfile -> you get an image." \
    "Dockerfile = text file with build instructions = produces an image."

  ask_mc "What is a Docker image?" \
    "A set of instructions written in a text file used to define the build process" \
    "A running instance of a containerised application" \
    "A read-only artifact built from a Dockerfile that can be used to start containers" \
    "A YAML configuration file for Docker Compose" \
    "C" 10 \
    "That describes a Dockerfile, not an image." \
    "A running instance describes a container, not an image." \
    "" \
    "That describes compose.yaml." \
    "Docker image = read-only artifact|Built from a Dockerfile|Stored locally or on Docker Hub|One image -> many containers|Like a class in OOP; containers are instances." \
    "Image = read-only artifact built from Dockerfile. Containers run from it."

  ask_mc "What is a Docker container?" \
    "A text file describing how to build an environment" \
    "A read-only snapshot of an application and its dependencies" \
    "A running instance created from a Docker image" \
    "A configuration file used to coordinate multiple services" \
    "C" 10 \
    "That describes a Dockerfile." \
    "Read-only snapshot describes a Docker image." \
    "" \
    "Coordinating multiple services describes Docker Compose / compose.yaml." \
    "Container = running instance of an image|Isolated process on the host|Has its own filesystem, network, process space|Ephemeral by default: stops -> data is lost unless you use volumes" \
    "Container = a running image. Stops = gone (unless volumes)."

  ask_mc "What is the difference between a Docker image and a container?" \
    "An image is running; a container is stopped" \
    "An image is a build artifact you can run; a container is the running instance" \
    "They are the same thing, just different names used in different contexts" \
    "A container is stored on Docker Hub; an image runs locally" \
    "B" 12 \
    "It is the opposite: images are static artifacts, containers are running." \
    "" \
    "They are fundamentally different things with different lifecycles." \
    "Images can be on Docker Hub; containers always run locally." \
    "Image vs Container:|Image = static, read-only, can be shared|Container = dynamic, running, has state|Analogy: image = class, container = instance|You can run many containers from one image." \
    "Image = static blueprint. Container = running instance from that blueprint."

  blank; echo "  ${GRN}${BOLD}Zone 1 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 2 -- DOCKERFILE INSTRUCTIONS  [+ lab]
# =============================================================================
zone_dockerfile() {
  zone_header 2 "DOCKERFILE INSTRUCTIONS" "FROM, WORKDIR, COPY, RUN, ENTRYPOINT -- plus a live writing lab"

  ask_mc "What does the FROM instruction do in a Dockerfile?" \
    "Copies files from the host machine into the container image" \
    "Defines the command to run when the container starts" \
    "Specifies the base image Docker should start from" \
    "Sets the working directory inside the container" \
    "C" 10 \
    "Copying files is COPY, not FROM." \
    "The startup command is ENTRYPOINT, not FROM." \
    "" \
    "Setting the working directory is WORKDIR, not FROM." \
    "FROM = specifies base image|Example: FROM maven:3.9.9-eclipse-temurin-21|The base image provides the OS, runtime, and tools|You pick it for what it includes (Maven+Java) or how small it is (Alpine)|Every Dockerfile starts with FROM." \
    "FROM = base image. Every Dockerfile starts with it."

  ask_mc "What does WORKDIR do?" \
    "Downloads dependencies from the internet into the image" \
    "Sets the working directory inside the container -- like cd in Linux" \
    "Copies a file from the host machine into the image" \
    "Runs a shell command during the container build" \
    "B" 10 \
    "Downloading dependencies is done with RUN, not WORKDIR." \
    "" \
    "Copying files is COPY, not WORKDIR." \
    "Running shell commands is RUN, not WORKDIR." \
    "WORKDIR /app:|Sets current directory inside container to /app|Subsequent COPY and RUN commands execute relative to /app|Similar to cd /app in Linux|If /app does not exist, Docker creates it." \
    "WORKDIR = cd inside the container."

  ask_mc "What does the COPY instruction do?" \
    "Runs a command inside the container during the build" \
    "Sets the startup command for the container" \
    "Copies files from your host machine into the container image at build time" \
    "Mounts a host directory into a running container" \
    "C" 10 \
    "Running commands during build is RUN, not COPY." \
    "Setting startup command is ENTRYPOINT, not COPY." \
    "" \
    "Mounting at runtime is done with volumes in compose.yaml, not COPY." \
    "COPY copies at build time:|COPY pom.xml .  -> copies pom.xml to WORKDIR|COPY src ./src  -> copies src/ directory|COPY --from=build ... -> copies from another build stage|Files copied become part of the image permanently." \
    "COPY = copies host files INTO the image at build time."

  ask_mc "What does the RUN instruction do?" \
    "Starts the application when a container is created from the image" \
    "Copies a file from the host into the container image" \
    "Executes a shell command during the image build process" \
    "Pulls a base image from Docker Hub" \
    "C" 10 \
    "Starting the application at runtime is ENTRYPOINT, not RUN." \
    "Copying files is COPY, not RUN." \
    "" \
    "Pulling a base image is FROM, not RUN." \
    "RUN executes at BUILD time, not runtime:|RUN mvn clean package -DskipTests|RUN apk add --no-cache bash wget|The result is baked into the image layer.|RUN != what happens when a container starts." \
    "RUN = executes during BUILD. Not when the container starts."

  ask_mc "What does ENTRYPOINT define?" \
    "The base image to use for the container" \
    "A shell command to execute during the image build" \
    "The default command that runs when a container is started from the image" \
    "The working directory inside the container" \
    "C" 10 \
    "The base image is FROM, not ENTRYPOINT." \
    "Build-time commands are RUN, not ENTRYPOINT." \
    "" \
    "The working directory is WORKDIR, not ENTRYPOINT." \
    "ENTRYPOINT = what runs when a container starts:|ENTRYPOINT [\"java\", \"-jar\", \"app.jar\"]|It is a default -- you can override it at runtime|Without ENTRYPOINT, the container starts and immediately exits|Use array syntax [\"cmd\", \"arg\"] not string syntax." \
    "ENTRYPOINT = container startup command. Runs at runtime, not build time."

  ask_typed "What Dockerfile instruction would you write to set the working directory to /app?" \
    "WORKDIR /app" 10 \
    "Use the WORKDIR keyword followed by the path." \
    "WORKDIR /app|Sets the current directory inside the container to /app|All following COPY and RUN are relative to this path." \
    "WORKDIR /app -- the instruction and the path, that's it."

  ask_typed "Write the ENTRYPOINT instruction to run 'java -jar app.jar' inside a container:" \
    "ENTRYPOINT [\"java\", \"-jar\", \"app.jar\"]" 12 \
    "Use array syntax: ENTRYPOINT [\"cmd\", \"arg1\", \"arg2\"]" \
    "ENTRYPOINT uses exec form (array syntax):|ENTRYPOINT [\"java\", \"-jar\", \"app.jar\"]|Quotes around each argument, comma-separated.|Do not use string form for ENTRYPOINT -- use the array." \
    "ENTRYPOINT [\"java\", \"-jar\", \"app.jar\"] -- array syntax, every token quoted."

  # -------------------------------------------------------------------------
  #  LAB 2A -- Write a complete Dockerfile from scratch
  # -------------------------------------------------------------------------
  lab_header "Write a Dockerfile" \
    "Complete the starter file: ~/.dockermaster/lab/Dockerfile"

  printf "  ${W}The file already exists with comments explaining what to add.${RST}\n"
  printf "  ${DIM}  Open it with: nano ~/.dockermaster/lab/Dockerfile${RST}\n"
  blank
  printf "  ${YLW}Your Dockerfile must contain all four of these instructions:${RST}\n"
  printf "  ${CYN}    FROM alpine:latest${RST}\n"
  printf "  ${CYN}    WORKDIR /app${RST}\n"
  printf "  ${CYN}    RUN echo \"dockermaster\" > welcome.txt${RST}\n"
  printf "  ${CYN}    ENTRYPOINT [\"cat\", \"/app/welcome.txt\"]${RST}\n"

  do_task \
    "Write the four required instructions into ~/.dockermaster/lab/Dockerfile" \
    "grep -qF 'FROM alpine:latest' Dockerfile &&
     grep -q 'WORKDIR /app' Dockerfile &&
     grep -q 'RUN echo' Dockerfile &&
     grep -qF 'ENTRYPOINT [\"cat\"' Dockerfile" \
    15 \
    'FROM alpine:latest|WORKDIR /app|RUN echo "dockermaster" > welcome.txt|ENTRYPOINT ["cat", "/app/welcome.txt"]' \
    "All four instructions must appear in the file. Check for typos and correct capitalisation."

  # -------------------------------------------------------------------------
  #  LAB 2B -- Identify and remove a bad RUN instruction
  # -------------------------------------------------------------------------
  lab_header "Clean a Dockerfile" \
    "Remove the bad line from ~/.dockermaster/lab/Dockerfile"

  # Plant a bad line into the file they just wrote
  printf '\nRUN cat /etc/secret_keys 2>/dev/null\n' >> "$LABDIR/Dockerfile"

  printf "  ${W}A rogue RUN instruction has appeared in your Dockerfile:${RST}\n"
  blank
  printf "  ${RED}    RUN cat /etc/secret_keys 2>/dev/null${RST}\n"
  blank
  printf "  ${DIM}  In production Dockerfiles, instructions that read secrets or${RST}\n"
  printf "  ${DIM}  private files at build time are a security risk -- the output${RST}\n"
  printf "  ${DIM}  may appear in build logs visible to your whole team.${RST}\n"
  blank
  printf "  ${YLW}Delete that line. Your Dockerfile must NOT contain 'secret_keys'.${RST}\n"

  do_task \
    "Remove the 'RUN cat /etc/secret_keys' line from the Dockerfile" \
    "! grep -q 'secret_keys' Dockerfile" \
    10 \
    "Open the file and delete the RUN cat /etc/secret_keys line." \
    "grep -v can remove a line: grep -v 'secret_keys' Dockerfile > tmp && mv tmp Dockerfile"

  blank; echo "  ${GRN}${BOLD}Zone 2 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 3 -- MULTI-STAGE BUILDS  [+ lab]
# =============================================================================
zone_multistage() {
  zone_header 3 "MULTI-STAGE BUILDS" "AS build, COPY --from, why only the last stage ships"

  ask_mc "What is a multi-stage build in Docker?" \
    "A build that uses multiple Dockerfiles chained together via scripts" \
    "A Dockerfile with multiple FROM instructions, each defining a build stage" \
    "A Docker Compose setup that builds multiple services simultaneously" \
    "A process where a base image is downloaded from multiple registries" \
    "B" 12 \
    "Multi-stage builds use one Dockerfile with multiple FROM, not multiple Dockerfiles." \
    "" \
    "Docker Compose orchestrates containers -- it is separate from multi-stage Dockerfiles." \
    "Downloading from multiple registries is unrelated to multi-stage builds." \
    "Multi-stage build:|Multiple FROM instructions in one Dockerfile|Each FROM = a new stage|Stages can share artifacts via COPY --from|Only the LAST stage ends up in the final image|Build tools (Maven) stay in the build stage only." \
    "Multi-stage = multiple FROM in one Dockerfile. Only last stage ships."

  ask_mc "In a multi-stage build, what does 'AS build' do in the line 'FROM maven:3.9.9 AS build'?" \
    "It pushes the resulting image to Docker Hub under the name 'build'" \
    "It gives the build stage a name so it can be referenced later with COPY --from=build" \
    "It forces Docker to build the image in the background" \
    "It sets the working directory to a folder named 'build'" \
    "B" 12 \
    "AS build does not push to Docker Hub. It is just a label." \
    "" \
    "Background building is done with docker build, not AS." \
    "AS build does not affect WORKDIR at all." \
    "AS build = name a stage:|FROM maven:3.9.9 AS build  <- named stage|You can then reference it:|COPY --from=build /app/target/*.jar app.jar|This copies the compiled JAR from the build stage into the final image.|Without AS, you cannot reference the stage." \
    "AS build = a label for the stage. Used in COPY --from=build."

  ask_mc "Why do we use multi-stage builds for Java applications?" \
    "Because Java requires two JDKs to compile and run simultaneously" \
    "To keep the final Docker image small by excluding build tools like Maven from it" \
    "Because Docker Hub requires all images to be built in two stages" \
    "To allow the application to restart automatically when code changes" \
    "B" 12 \
    "Java does not require two JDKs. The point is to separate build from runtime." \
    "" \
    "Docker Hub has no such requirement. Multi-stage is a best practice." \
    "Auto-restart on code changes is not related to multi-stage builds." \
    "Multi-stage build purpose:|Stage 1: Use maven image -> compile .jar file|Stage 2: Use lightweight alpine image -> only copy .jar|Maven is NOT in the final image|Result: final image is much smaller and more secure|Build tools with known vulnerabilities do not ship to production." \
    "Multi-stage = exclude build tools from final image. Smaller + safer."

  ask_typed "Write the COPY instruction to copy the compiled JAR from the 'build' stage to the current directory as 'app.jar':" \
    "COPY --from=build /app/target/*.jar app.jar" 12 \
    "Syntax: COPY --from=STAGE_NAME source destination" \
    "COPY --from=build /app/target/*.jar app.jar|--from=build references the named build stage|Source is the path inside the build stage|Destination is relative to WORKDIR in the current stage" \
    "COPY --from=build [source_in_build_stage] [destination_here]"

  ask_mc "In the Java multi-stage Dockerfile, what is the purpose of the second FROM (eclipse-temurin:21-jdk-alpine)?" \
    "To download Alpine Linux as a second base for error recovery" \
    "To define the runtime stage -- a lightweight image that only runs the compiled JAR" \
    "To allow Maven to compile the project a second time for verification" \
    "To create a backup copy of the build stage in case of failure" \
    "B" 12 \
    "Alpine is used for its small size at runtime, not for error recovery." \
    "" \
    "Maven is only in the build stage. The second stage does not use Maven." \
    "There is no backup mechanism in multi-stage builds." \
    "Second FROM (eclipse-temurin:21-jdk-alpine):|Lightweight Alpine-based Java runtime|No Maven, no compiler, no build tools|Only contains the JDK and the app.jar|Makes the final container image much smaller|Alpine Linux is popular specifically for this use in Docker." \
    "Second FROM = lean runtime image. No Maven. Just JDK + app.jar."

  # -------------------------------------------------------------------------
  #  LAB 3 -- Fix a broken multi-stage Dockerfile
  # -------------------------------------------------------------------------
  lab_header "Fix a Multi-stage Dockerfile" \
    "The COPY --from line is missing from ~/.dockermaster/lab/multistage/Dockerfile"

  printf "  ${W}Open the file and examine it:${RST}\n"
  blank
  printf "  ${DIM}    cat ~/.dockermaster/lab/multistage/Dockerfile${RST}\n"
  blank
  printf "  ${YLW}The runtime stage is missing the line that copies the compiled JAR${RST}\n"
  printf "  ${YLW}from the build stage. Add it between the WORKDIR and ENTRYPOINT.${RST}\n"
  blank
  printf "  ${CYN}    COPY --from=build /app/target/*.jar app.jar${RST}\n"

  do_task \
    "Add 'COPY --from=build /app/target/*.jar app.jar' to multistage/Dockerfile" \
    "grep -qF 'COPY --from=build' multistage/Dockerfile &&
     grep -q 'app.jar' multistage/Dockerfile" \
    15 \
    "COPY --from=build /app/target/*.jar app.jar" \
    "This line must appear in the runtime stage (after the second FROM), before ENTRYPOINT."

  blank; echo "  ${GRN}${BOLD}Zone 3 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 4 -- DOCKER COMMANDS
# =============================================================================
zone_commands() {
  zone_header 4 "DOCKER COMMANDS" "build, run, ps, stop, rm, rmi, prune -- the essential toolkit"

  ask_mc "What does 'docker build .' do?" \
    "Starts all containers defined in compose.yaml" \
    "Downloads an image from Docker Hub" \
    "Builds a Docker image using the Dockerfile in the current directory" \
    "Lists all locally available Docker images" \
    "C" 10 \
    "Starting compose services is docker compose up, not docker build." \
    "Downloading from Hub happens automatically via docker run or docker pull." \
    "" \
    "Listing images is docker image ls." \
    "docker build .:|The dot (.) is the build context -- the current directory|Docker looks for a file named 'Dockerfile' in that location|Result: a new image is created locally|Add --tag to name it: docker build --tag myapp:latest ." \
    "docker build . = build Dockerfile in current directory into an image."

  ask_typed "Write the command to build a Docker image and tag it as 'myapp:latest':" \
    "docker build --tag myapp:latest ." 10 \
    "Use --tag name:version and the build context path at the end." \
    "docker build --tag name:version context_path|--tag sets the name and version (tag)|Dot at the end = use current directory as build context|'latest' is Docker's default version label." \
    "docker build --tag name:version . -- dot is always needed at the end."

  ask_typed "Write the command to start an interactive container from the 'bashcrawl' image:" \
    "docker run -it bashcrawl" 10 \
    "Use docker run -it imagename. -i = interactive, -t = tty (terminal)." \
    "docker run -it imagename|-i = --interactive: keep STDIN open|-t = --tty: allocate a terminal|Together they let you use the container like a shell session|Without -it, the container exits immediately if it has no foreground task." \
    "docker run -it = interactive terminal session inside the container."

  ask_mc "What does 'docker ps' show?" \
    "All Docker images stored locally" \
    "Only currently running containers" \
    "All containers including stopped ones" \
    "The build history of the last image" \
    "B" 10 \
    "Locally stored images are shown by docker image ls." \
    "" \
    "All containers including stopped ones is docker ps -a." \
    "Build history is docker image history, not docker ps." \
    "docker ps vs docker ps -a:|docker ps      -> only RUNNING containers|docker ps -a   -> ALL containers (running + stopped)|Tip: after a crash, use docker ps -a to see what failed|Container status: Up, Exited, Created" \
    "docker ps = running only. docker ps -a = all containers."

  ask_mc "You have a running container named 'my-mysql'. Which command stops it?" \
    "docker kill my-mysql" \
    "docker pause my-mysql" \
    "docker stop my-mysql" \
    "docker rm my-mysql" \
    "C" 10 \
    "docker kill sends SIGKILL immediately -- no graceful shutdown. docker stop is preferred." \
    "docker pause freezes the container but does not stop it." \
    "" \
    "docker rm removes a stopped container. It does not stop a running one." \
    "docker stop vs docker rm:|docker stop <n>  -> gracefully stops the container|docker rm <n>    -> removes a stopped container|To delete: stop first, then rm|Or use docker rm -f to force-remove a running one." \
    "docker stop = graceful stop. docker rm = delete (must be stopped first)."

  ask_mc "Which command removes a Docker IMAGE (not a container)?" \
    "docker rm myimage" \
    "docker delete myimage" \
    "docker container prune" \
    "docker rmi myimage" \
    "D" 10 \
    "docker rm removes containers, not images." \
    "docker delete does not exist." \
    "docker container prune removes stopped containers, not images." \
    "" \
    "Cleanup commands:|docker rm <container>      -> removes one container|docker rmi <image>         -> removes one image|docker container prune     -> removes ALL stopped containers|docker image prune         -> removes ALL unused images|docker system prune        -> removes everything unused" \
    "rmi = remove image. rm = remove container. Different commands."

  ask_mc "What does the --rm flag do in 'docker run --rm -it myimage'?" \
    "It prevents the container from being stopped manually" \
    "It automatically removes the container when it exits" \
    "It runs the container with root privileges removed" \
    "It tags the image as 'rm' version after building" \
    "B" 10 \
    "--rm does not lock the container. It is a cleanup flag." \
    "" \
    "--rm is about lifecycle cleanup, not privileges." \
    "--rm is a runtime flag, not a tagging mechanism." \
    "docker run --rm:|Container is automatically deleted when it exits|Useful for one-off commands where you do not want leftover containers|Example: docker run --rm -it jonlabelle/network-tools dig kea.dk|Without --rm: container stays in 'Exited' state after stop." \
    "--rm = auto-delete container on exit. Good for one-off commands."

  blank; echo "  ${GRN}${BOLD}Zone 4 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 5 -- DOCKER COMPOSE  [+ lab]
# =============================================================================
zone_compose() {
  zone_header 5 "DOCKER COMPOSE" "compose.yaml, services, up -d, down, restart, named volumes"

  ask_mc "What problem does Docker Compose solve?" \
    "It replaces the Dockerfile and compiles your application automatically" \
    "It removes the need for Docker Hub by storing images locally" \
    "It lets you define and start multiple containers with one configuration file instead of many separate docker run commands" \
    "It creates a virtual machine to isolate Docker from the host OS" \
    "C" 12 \
    "Docker Compose does not replace Dockerfiles. They work together." \
    "Docker Compose does not replace Docker Hub." \
    "" \
    "Docker already runs in isolated containers -- no VM needed." \
    "Docker Compose solves:|1. Hard to remember many docker run commands with many arguments|2. Easy to make a mistake from run to run|Solution: write it down in compose.yaml|One file describes all services, ports, volumes, environment variables|docker compose up starts everything." \
    "Compose = one file replaces many docker run commands. Repeatable."

  ask_mc "What is a 'service' in Docker Compose terminology?" \
    "A background OS process running on the host machine" \
    "A single container definition in compose.yaml, including its image, ports, and settings" \
    "A paid Docker Hub tier that provides private repositories" \
    "A shell script that automates the docker build command" \
    "B" 10 \
    "An OS process is not a Compose service." \
    "" \
    "Docker Hub tiers are not related to Compose services." \
    "Shell scripts are not Compose services." \
    "Service in compose.yaml:|A service = one container definition|Has: image (or build), ports, volumes, environment, restart|Example services: mysql, backend, frontend, redis|Each service can scale independently" \
    "Service = one container definition with all its settings."

  ask_mc "What does 'restart: always' do in a compose.yaml service?" \
    "Restarts the container every hour automatically" \
    "Rebuilds the image from the Dockerfile on every startup" \
    "Automatically restarts the container whenever it stops or crashes, including on Docker startup" \
    "Forces the container to restart if a health check fails" \
    "C" 10 \
    "restart: always does not restart on a timer." \
    "Rebuilding images requires docker compose build, not restart: always." \
    "" \
    "restart: always is not specifically tied to health checks." \
    "restart: always:|Container restarts if it stops for any reason|Also starts automatically when Docker starts on the machine|Useful for databases and backend services that must always be running|restart: on-failure = only restart if exit code is non-zero." \
    "restart: always = auto-restart on crash AND on Docker startup."

  ask_typed "Write the docker compose command to start all services in the background:" \
    "docker compose up -d" 10 \
    "-d means detached / background. Without it, containers run in the foreground." \
    "docker compose up -d|-d = detached mode = runs in the background|Without -d: runs in foreground, Ctrl+C stops everything|With -d: terminal is free, containers keep running" \
    "docker compose up -d = start in background (detached)."

  ask_typed "Write the docker compose command to stop and remove all running services:" \
    "docker compose down" 10 \
    "This command stops containers AND removes them. Not the same as just stopping." \
    "docker compose down:|Stops all containers in the compose file|Removes the containers (not volumes by default)|Add --volumes to also remove named volumes|Compare: docker compose stop only stops, does not remove" \
    "docker compose down = stop AND remove containers."

  ask_mc "In the MySQL compose.yaml example, what does the 'volumes' section at the bottom (outside services) do?" \
    "It defines a bind mount to a local folder on the host" \
    "It declares the named volume 'mysql_data' so Docker knows it exists and manages it" \
    "It sets the maximum disk space the MySQL container can use" \
    "It copies database files into the container at build time" \
    "B" 12 \
    "A bind mount uses a relative path like ./data -- a named volume is different." \
    "" \
    "Disk space limits are not set with volumes in compose.yaml." \
    "Copying files at build time is COPY in Dockerfile, not compose volumes." \
    "Named volumes in compose.yaml:|Two occurrences of mysql_data:|1. Under the service: volumes: - mysql_data:/var/lib/mysql|   -> tells this service to USE the volume at that path|2. At the bottom: volumes: mysql_data:|   -> declares the volume so Docker creates and manages it|Named volumes persist across container restarts and removals." \
    "Bottom volumes: section = declare the volume. Service volumes: = use it."

  ask_mc "Why do MYSQL_ environment variables only work the first time the service starts?" \
    "Docker forgets environment variables after each container restart" \
    "MySQL reads them to initialise the database only on first start; existing data is not overwritten" \
    "The compose.yaml file is deleted after first use" \
    "Docker Hub resets environment variables on every pull" \
    "B" 12 \
    "Docker does not forget env vars -- the issue is MySQL's initialisation logic." \
    "" \
    "compose.yaml is never deleted by Docker." \
    "Docker Hub does not interact with running containers." \
    "MYSQL_ env vars:|MYSQL_ROOT_PASSWORD, MYSQL_DATABASE, MYSQL_USER, MYSQL_PASSWORD|MySQL reads these ONLY when initialising a fresh database|If /var/lib/mysql already has data (from a volume), these vars are ignored|To change password: remove the volume first, then restart." \
    "MYSQL_ vars only work on fresh DB init. Existing data = vars ignored."

  # -------------------------------------------------------------------------
  #  LAB 5A -- Write a compose.yaml from scratch
  # -------------------------------------------------------------------------
  lab_header "Write a compose.yaml" \
    "Complete the MySQL service in ~/.dockermaster/lab/myapp/compose.yaml"

  printf "  ${W}The starter file has comments explaining the requirements.${RST}\n"
  printf "  ${DIM}  Open it with: nano ~/.dockermaster/lab/myapp/compose.yaml${RST}\n"
  blank
  printf "  ${YLW}Your compose.yaml must define a mysql service with:${RST}\n"
  printf "  ${CYN}    image: mysql:latest${RST}\n"
  printf "  ${CYN}    container_name: my-mysql${RST}\n"
  printf "  ${CYN}    restart: always${RST}\n"
  printf "  ${CYN}    port: 127.0.0.1:3307:3306${RST}\n"
  printf "  ${CYN}    volume: mysql_data:/var/lib/mysql${RST}\n"
  printf "  ${CYN}    top-level volumes: section${RST}\n"

  do_task \
    "Write the complete MySQL compose.yaml in myapp/compose.yaml" \
    "grep -q 'image: mysql' myapp/compose.yaml &&
     grep -q 'my-mysql' myapp/compose.yaml &&
     grep -q 'restart: always' myapp/compose.yaml &&
     grep -q '127.0.0.1' myapp/compose.yaml &&
     grep -q 'mysql_data' myapp/compose.yaml" \
    20 \
    "services:|  mysql:|    image: mysql:latest|    container_name: my-mysql|    restart: always|    environment:|      MYSQL_ROOT_PASSWORD: secret|      MYSQL_DATABASE: appdb|    ports:|      - \"127.0.0.1:3307:3306\"|    volumes:|      - mysql_data:/var/lib/mysql|volumes:|  mysql_data:" \
    "All five requirements must be present. YAML is indentation-sensitive -- use 2 spaces."

  # -------------------------------------------------------------------------
  #  LAB 5B -- Add a build: section to replace image:
  # -------------------------------------------------------------------------
  lab_header "Switch from image: to build:" \
    "Edit myapp/compose.yaml to build from a local Dockerfile instead of pulling an image"

  printf "  ${W}Change the mysql service so it builds locally instead of pulling.${RST}\n"
  blank
  printf "  ${DIM}  Replace the 'image: mysql:latest' line with a build: section:${RST}\n"
  blank
  printf "  ${CYN}    build:${RST}\n"
  printf "  ${CYN}      context: .${RST}\n"
  printf "  ${CYN}      dockerfile: Dockerfile${RST}\n"
  blank
  printf "  ${DIM}  This tells Compose to build the image from a Dockerfile in the${RST}\n"
  printf "  ${DIM}  current directory, rather than pulling from Docker Hub.${RST}\n"

  do_task \
    "Replace 'image: mysql:latest' with a build: section in myapp/compose.yaml" \
    "grep -q 'build:' myapp/compose.yaml &&
     grep -q 'context:' myapp/compose.yaml &&
     grep -q 'dockerfile: Dockerfile' myapp/compose.yaml" \
    12 \
    "build:|  context: .|  dockerfile: Dockerfile" \
    "The build: section replaces image: when you want to build locally."

  blank; echo "  ${GRN}${BOLD}Zone 5 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 6 -- PORT MAPPING & SECURITY  [+ lab]
# =============================================================================
zone_ports() {
  zone_header 6 "PORT MAPPING & SECURITY" "3306:3306 vs 127.0.0.1:3306:3306 -- why it matters on cloud"

  ask_mc "What does the port mapping '3306:3306' mean in compose.yaml?" \
    "The container uses port 3306 internally and does not expose it externally" \
    "Port 3306 on the host machine is mapped to port 3306 inside the container, on all network interfaces" \
    "The container restarts if port 3306 is unavailable" \
    "Docker uses port 3306 to communicate with Docker Hub" \
    "B" 10 \
    "The port IS exposed externally -- that is the problem with 3306:3306." \
    "" \
    "Port mapping has nothing to do with container restart behaviour." \
    "Port mapping is for host-to-container access, not Docker Hub." \
    "Port mapping format: HOST:CONTAINER|3306:3306 = host port 3306 -> container port 3306|Docker listens on 0.0.0.0 (all interfaces) by default|This means the service is reachable from outside the host machine too|Dangerous on a public cloud server without a firewall!" \
    "3306:3306 = all interfaces. Anyone who can reach the host can reach MySQL."

  ask_mc "What is the security difference between '3306:3306' and '127.0.0.1:3306:3306'?" \
    "127.0.0.1:3306:3306 uses a different port inside the container" \
    "3306:3306 encrypts traffic; 127.0.0.1:3306:3306 does not" \
    "127.0.0.1:3306:3306 restricts access to only the host machine's localhost; external clients cannot connect" \
    "There is no functional difference -- 127.0.0.1 is just a comment" \
    "C" 12 \
    "Both use port 3306 inside the container. The interface binding is different." \
    "Neither option controls encryption. TLS is a separate concern." \
    "" \
    "127.0.0.1 is a real IP address -- it changes which interface Docker binds to." \
    "127.0.0.1:3306:3306:|The 127.0.0.1 binds the host-side to localhost ONLY|External machines cannot connect|Safe for development and services that should not be public|3306:3306 = binds to 0.0.0.0 = all interfaces = dangerous on cloud servers" \
    "127.0.0.1:3306:3306 = localhost only. 3306:3306 = world-accessible."

  ask_mc "You deploy a MySQL container on a cloud server using '3306:3306'. No firewall is configured. What is the security risk?" \
    "The database will run slower because external traffic competes with internal traffic" \
    "The MySQL container could be directly accessible from the public internet, allowing anyone to attempt to connect" \
    "Docker will automatically block external connections on cloud servers" \
    "The container will crash because MySQL only supports localhost connections" \
    "B" 12 \
    "This is not a performance issue -- it is a direct security exposure." \
    "" \
    "Docker does NOT automatically block anything. You must configure the firewall." \
    "MySQL happily accepts remote connections -- that is the danger." \
    "Cloud server + 3306:3306 + no firewall:|Docker binds to 0.0.0.0 (all interfaces)|Your cloud server's public IP is one of those interfaces|Anyone on the internet can attempt to connect to your MySQL|Recommendation: always use 127.0.0.1 unless external access is required|And if external access is required, use a firewall." \
    "0.0.0.0 = all interfaces = public internet can reach your database."

  ask_mc "What is the recommended port mapping for a development environment?" \
    "3306:3306 -- simpler and still fine for development" \
    "0.0.0.0:3306:3306 -- explicitly allows all connections" \
    "127.0.0.1:3306:3306 -- restricts access to localhost only" \
    "No port mapping -- access the database directly inside the container" \
    "C" 10 \
    "Even in development, best practice is to limit exposure. Use 127.0.0.1." \
    "0.0.0.0 explicitly opens to all interfaces -- worse than just 3306:3306." \
    "" \
    "Without port mapping, the database is unreachable from the host machine." \
    "Best practice for port mapping:|Development: 127.0.0.1:HOST_PORT:CONTAINER_PORT|Production: 127.0.0.1:... + firewall, or not exposed at all|Only expose ports externally when absolutely necessary|Principle of least privilege: minimum required exposure." \
    "Always use 127.0.0.1 in development. Expose externally only when required."

  ask_mc "The backend service in compose.yaml maps '127.0.0.1:8080:8080'. A user on the internet tries to access it. What happens?" \
    "They reach the backend because Docker maps 8080 to a public IP automatically" \
    "They are blocked because the port is only accessible via localhost on the host machine" \
    "They are redirected to Docker Hub for authentication first" \
    "The container crashes because external connections are not allowed" \
    "B" 10 \
    "Docker does not map to public IPs automatically when 127.0.0.1 is specified." \
    "" \
    "Docker has no authentication redirect mechanism like that." \
    "The container does not crash -- the connection is simply refused at the network level." \
    "127.0.0.1:8080:8080 result:|Only requests originating FROM the host machine (localhost) reach port 8080|External users hit the server's public IP, where 8080 is not bound|Connection is refused before it ever reaches Docker|To expose externally: remove 127.0.0.1 or use a reverse proxy like nginx." \
    "127.0.0.1 = only reachable from the host itself. External = refused."

  # -------------------------------------------------------------------------
  #  LAB 6 -- Fix an insecure port mapping
  # -------------------------------------------------------------------------
  lab_header "Fix an Insecure Port Mapping" \
    "Harden the compose.yaml in ~/.dockermaster/lab/insecure/"

  printf "  ${W}Open the file and inspect the current port mapping:${RST}\n"
  blank
  printf "  ${DIM}    cat ~/.dockermaster/lab/insecure/compose.yaml${RST}\n"
  blank
  printf "  ${RED}  Current (unsafe):   - \"3306:3306\"${RST}\n"
  printf "  ${GRN}  Required (safe):    - \"127.0.0.1:3306:3306\"${RST}\n"
  blank
  printf "  ${YLW}Edit the file so the port mapping binds to 127.0.0.1 only.${RST}\n"

  do_task \
    "Change the port mapping in insecure/compose.yaml to use 127.0.0.1" \
    "grep -q '127.0.0.1:3306:3306' insecure/compose.yaml &&
     ! grep -q '\"3306:3306\"' insecure/compose.yaml" \
    15 \
    'ports:|  - "127.0.0.1:3306:3306"' \
    "Replace the '3306:3306' entry with '127.0.0.1:3306:3306'. The quotes matter in YAML."

  blank; echo "  ${GRN}${BOLD}Zone 6 complete!${RST}"; pause
}

# =============================================================================
#  ZONE 7 -- VOLUMES, COPY & BUILD CACHE  [+ lab]
# =============================================================================
zone_volumes_cache() {
  zone_header 7 "VOLUMES, COPY & BUILD CACHE" "Build-time vs runtime, cache layers, Dockerfile optimisation"

  ask_mc "What is the core difference between COPY in Dockerfile and volumes in compose.yaml?" \
    "COPY runs at container startup; volumes run during the build" \
    "COPY bakes files into the image at build time; volumes inject files at runtime" \
    "COPY is for directories only; volumes are for individual files" \
    "There is no practical difference -- they both add files to the container" \
    "B" 12 \
    "It is the opposite: COPY runs at build time, volumes apply at runtime." \
    "" \
    "Both COPY and volumes can handle both files and directories." \
    "There is a critical difference: images are immutable; volumes are dynamic." \
    "COPY vs volumes:|COPY (build time): files baked into image, always available, unchangeable|volumes (runtime): files injected when container starts, can change dynamically|Choosing wrong has security and operational consequences." \
    "COPY = baked in at build. Volumes = injected at runtime."

  ask_mc "Why is it a security risk to use COPY to add secrets (API keys, passwords) to a Docker image?" \
    "Docker will print secrets to the terminal when the container starts" \
    "Secrets baked into an image are permanent and can be extracted by anyone with image access" \
    "Docker Hub automatically scans and rejects images containing secrets" \
    "Secrets in images expire after 30 days and cause the container to stop" \
    "B" 12 \
    "Docker does not print secrets automatically at runtime." \
    "" \
    "Docker Hub does not reject images with secrets -- that is the problem." \
    "Secrets in images do not expire. They stay there permanently." \
    "Secrets in Docker images:|Anyone who can access the image can extract every file|docker run --entrypoint cat myimage /app/secret.properties|Also appears in build logs|Well-known attack vector in mobile and frontend development|Solution: use volumes or environment variables for secrets." \
    "Secrets in images = permanent, extractable by anyone with image access."

  ask_mc "When should you use volumes (in compose.yaml) instead of COPY (in Dockerfile) for configuration files?" \
    "When you want the config to be permanently embedded and consistent across all environments" \
    "When the config file changes dynamically, contains secrets, or needs to differ between environments" \
    "When you are building for production and need maximum performance" \
    "When you want the config to be available inside the container without mounting anything" \
    "B" 12 \
    "Permanently embedded config = use COPY. Static, consistent = COPY." \
    "" \
    "Volumes can reduce predictability in production. COPY is better for prod consistency." \
    "If you want config inside without mounting, that IS COPY -- which is the other option." \
    "Use volumes when:|Files change dynamically (e.g. config per environment)|Files contain secrets (passwords, API keys)|You want fast iterations without rebuilding the image|Example: ./application-docker.properties:/app/application.properties:ro|The :ro at the end makes it read-only inside the container." \
    "Dynamic, secret, or env-specific files -> volumes. Static, consistent -> COPY."

  ask_mc "What is Docker's build cache and how does it work?" \
    "It stores the final container image in RAM so it starts faster" \
    "Each Dockerfile instruction creates a layer; if nothing changed in that layer's inputs, Docker reuses the cached layer instead of re-running the instruction" \
    "It is a shared cache on Docker Hub that speeds up downloads of base images" \
    "It stores docker run commands so you do not have to type them again" \
    "B" 12 \
    "Docker cache is about build layers, not RAM for container startup." \
    "" \
    "Docker Hub has a pull cache but that is different from the build cache." \
    "The build cache has nothing to do with storing run commands." \
    "Docker build cache:|Each instruction (FROM, COPY, RUN) = one layer|Docker hashes the inputs of each layer|If inputs unchanged -> layer is reused from cache (fast)|If any input changes -> that layer AND ALL SUBSEQUENT layers are rebuilt|Order matters: put frequently-changing instructions LAST." \
    "Build cache: each layer hashed. Change = rebuild that layer + everything after."

  ask_mc "In a Java Dockerfile, why should 'COPY src ./src' come AFTER 'COPY pom.xml .' and 'RUN mvn dependency:resolve'?" \
    "Because Docker requires COPY instructions to be alphabetically ordered" \
    "Because src changes more often than pom.xml; putting it later preserves the dependency download cache longer" \
    "Because Maven cannot compile code before pom.xml is inside the container" \
    "Because src is a directory and directories must always come last in Dockerfiles" \
    "B" 12 \
    "Docker has no alphabetical requirement for COPY ordering." \
    "" \
    "While Maven does need pom.xml, that is about correctness -- the question is about cache optimisation." \
    "There is no rule that directories must come last in Dockerfiles." \
    "Dockerfile cache optimisation:|pom.xml changes rarely (new dependencies)|src changes very often (every code edit)|If COPY src comes first, every code edit invalidates the dependency download cache|By putting COPY pom.xml + RUN mvn dependency:resolve BEFORE COPY src:|-> Dependency download is cached as long as pom.xml does not change|-> Only source compilation is re-run on each code change|This can save minutes per build." \
    "Put frequently-changing files LAST to maximise cache reuse."

  ask_mc "What is the purpose of 'RUN mvn dependency:resolve' as a separate step before compiling?" \
    "It verifies that the compiled JAR is valid and can be executed" \
    "It downloads and caches all Maven dependencies as a separate layer, so they are not re-downloaded on every source code change" \
    "It cleans the target/ directory before a fresh compilation" \
    "It is a Maven security check that must run before build" \
    "B" 12 \
    "JAR validation is not what dependency:resolve does." \
    "" \
    "Cleaning target/ is mvn clean, not dependency:resolve." \
    "dependency:resolve is a performance optimisation, not a security step." \
    "RUN mvn dependency:resolve:|Downloads ALL dependencies defined in pom.xml|Stored in the Docker layer cache|If pom.xml has not changed, this layer is reused|Subsequent mvn clean package finds all deps already present|Without this: every build re-downloads all dependencies from the internet|Saves significant time on large projects." \
    "mvn dependency:resolve = pre-download deps into cache. Huge time saver."

  ask_mc "A developer runs 'docker compose up -d' but then connects to MySQL Workbench on port 3307 instead of 3306. Why?" \
    "Because MySQL inside Docker always switches to port 3307 automatically" \
    "Because the compose.yaml maps the host port 3307 to the container's internal port 3306" \
    "Because 3306 is blocked by the Docker network bridge" \
    "Because MySQL Workbench requires a different port than the MySQL server" \
    "B" 12 \
    "Docker does not switch ports automatically. The mapping is explicit." \
    "" \
    "The bridge network does not block 3306 by default." \
    "MySQL Workbench uses whatever port you tell it to. The port is determined by the mapping." \
    "Port mapping: HOST:CONTAINER|compose.yaml: - '127.0.0.1:3307:3306'|MySQL inside the container listens on 3306 (its default)|From OUTSIDE (host machine), you access it on 3307|This avoids conflict if you also have a local MySQL on 3306|When connecting: host=127.0.0.1, port=3307" \
    "Host 3307 -> container 3306. Always connect using the HOST port from outside."

  # -------------------------------------------------------------------------
  #  LAB 7A -- Add a volume mount to compose.yaml
  # -------------------------------------------------------------------------
  lab_header "Add a Volume Mount" \
    "Inject application.properties into the backend service at runtime"

  printf "  ${W}Open: ~/.dockermaster/lab/volumes/compose.yaml${RST}\n"
  blank
  printf "  ${DIM}  The backend service is missing a volumes: section.${RST}\n"
  printf "  ${DIM}  The application.properties file already exists in the same directory.${RST}\n"
  blank
  printf "  ${YLW}Add a volumes: entry that mounts the config file read-only:${RST}\n"
  blank
  printf "  ${CYN}    volumes:${RST}\n"
  printf "  ${CYN}      - ./application.properties:/app/application.properties:ro${RST}\n"
  blank
  printf "  ${DIM}  :ro means read-only inside the container -- a good security practice.${RST}\n"

  do_task \
    "Add the volume mount for application.properties in volumes/compose.yaml" \
    "grep -q 'application.properties' volumes/compose.yaml &&
     grep -q ':ro' volumes/compose.yaml" \
    15 \
    "volumes:|  - ./application.properties:/app/application.properties:ro" \
    "The volumes: key should be at the same indentation level as ports: and environment:."

  # -------------------------------------------------------------------------
  #  LAB 7B -- Optimise Dockerfile layer order
  # -------------------------------------------------------------------------
  lab_header "Optimise Build Cache Layer Order" \
    "Fix the Dockerfile in ~/.dockermaster/lab/cache/ to cache dependencies separately"

  printf "  ${W}Open: ~/.dockermaster/lab/cache/Dockerfile${RST}\n"
  blank
  printf "  ${DIM}  Current problem: src is copied before dependencies are resolved.${RST}\n"
  printf "  ${DIM}  Every source code change re-downloads ALL Maven dependencies.${RST}\n"
  blank
  printf "  ${YLW}Reorder the build stage so it reads:${RST}\n"
  blank
  printf "  ${CYN}    COPY pom.xml .${RST}\n"
  printf "  ${CYN}    RUN mvn dependency:resolve${RST}\n"
  printf "  ${CYN}    COPY src ./src${RST}\n"
  printf "  ${CYN}    RUN mvn clean package -DskipTests${RST}\n"
  blank
  printf "  ${DIM}  Now: changing a .java file only re-runs compilation -- not dependency download.${RST}\n"

  do_task \
    "Add 'RUN mvn dependency:resolve' before 'COPY src ./src' in cache/Dockerfile" \
    "grep -q 'mvn dependency:resolve' cache/Dockerfile" \
    15 \
    "COPY pom.xml .|RUN mvn dependency:resolve|COPY src ./src|RUN mvn clean package -DskipTests" \
    "The mvn dependency:resolve line must appear AFTER 'COPY pom.xml .' and BEFORE 'COPY src ./src'."

  blank; echo "  ${GRN}${BOLD}Zone 7 complete! -- ALL ZONES CLEARED!${RST}"; pause
}

# =============================================================================
#  RESULTS
# =============================================================================
results() {
  clear
  bigcap
  printf "  ${BOLD}${CYN}RESULTS -- ${W}%s${RST}\n" "$PLAYER_NAME"
  bigcap; blank

  local pct=0
  [[ $MAX_SCORE -gt 0 ]] && pct=$(( (SCORE * 100) / MAX_SCORE ))

  local grade grade_col grade_msg
  if   [[ $pct -ge 90 ]]; then grade="Expert";      grade_col="${GRN}"; grade_msg="Excellent command of Docker fundamentals."
  elif [[ $pct -ge 75 ]]; then grade="Proficient";  grade_col="${GRN}"; grade_msg="Solid Docker knowledge. A few gaps to revisit."
  elif [[ $pct -ge 55 ]]; then grade="Competent";   grade_col="${YLW}"; grade_msg="Good foundation. Review the zones you struggled with."
  elif [[ $pct -ge 35 ]]; then grade="Beginner";    grade_col="${Y}";   grade_msg="Getting there. Run it again from zone 1."
  else                          grade="Try again";   grade_col="${RED}"; grade_msg="Back to basics -- restart from zone 1."
  fi

  printf "  ${W}SCORE:${RST}   ${BOLD}${grade_col}%d${RST} / %d pts\n" "$SCORE" "$MAX_SCORE"
  pbar "$SCORE" "$MAX_SCORE" 50
  blank
  printf "  ${W}LEVEL:${RST}   ${grade_col}${BOLD} %s ${RST}\n" "$grade"
  printf "  ${W}NOTES:${RST}   ${DIM}%s${RST}\n" "$grade_msg"
  blank

  if [[ $LAB_TASKS -gt 0 ]]; then
    printf "  ${W}LAB TASKS:${RST}  ${GRN}%d${RST} / %d completed\n" "$LAB_CORRECT" "$LAB_TASKS"
    blank
  fi

  sep; blank
  echo "  ${W}BREAKDOWN${RST}"
  printf "  ${GRN}First-try correct:${RST}  %d\n" "$CORRECT"
  printf "  ${YLW}Correct on retry:${RST}   %d\n" "$RETRIED"
  printf "  ${RED}Missed entirely:${RST}    %d\n" "$WRONG"
  printf "  ${CYN}Total questions:${RST}    %d\n" "$((CORRECT + RETRIED + WRONG))"
  blank
  sep; blank
  echo "  ${W}KEY CONCEPTS TO LOCK IN${RST}"
  blank
  printf "  ${YLW}The holy trinity${RST}\n"
  printf "  ${DIM}  Dockerfile=recipe | Image=cake | Container=serving${RST}\n"
  blank
  printf "  ${YLW}Dockerfile instructions${RST}\n"
  printf "  ${DIM}  FROM=base image | WORKDIR=cd | COPY=files in at BUILD time${RST}\n"
  printf "  ${DIM}  RUN=execute at BUILD | ENTRYPOINT=execute at RUNTIME${RST}\n"
  blank
  printf "  ${YLW}Multi-stage builds${RST}\n"
  printf "  ${DIM}  FROM ... AS build -> name a stage${RST}\n"
  printf "  ${DIM}  COPY --from=build -> copy artifact from that stage${RST}\n"
  printf "  ${DIM}  Only the LAST stage ends up in the final image${RST}\n"
  blank
  printf "  ${YLW}Port mapping security${RST}\n"
  printf "  ${DIM}  3306:3306 = binds to 0.0.0.0 = world-accessible = DANGEROUS on cloud${RST}\n"
  printf "  ${DIM}  127.0.0.1:3306:3306 = localhost only = SAFE${RST}\n"
  blank
  printf "  ${YLW}COPY vs volumes${RST}\n"
  printf "  ${DIM}  COPY = build time = baked in = use for static code and libraries${RST}\n"
  printf "  ${DIM}  volumes = runtime = dynamic = use for secrets, configs, dev iteration${RST}\n"
  blank
  printf "  ${YLW}Build cache${RST}\n"
  printf "  ${DIM}  Each instruction = one layer | Change = rebuild that layer + all after${RST}\n"
  printf "  ${DIM}  Put frequently-changing instructions LAST${RST}\n"
  printf "  ${DIM}  Separate: COPY pom.xml -> RUN mvn dependency:resolve -> COPY src${RST}\n"
  blank
  printf "  ${YLW}Compose commands${RST}\n"
  printf "  ${DIM}  docker compose up -d = start all in background${RST}\n"
  printf "  ${DIM}  docker compose down  = stop AND remove containers${RST}\n"
  blank
  printf "  ${YLW}Your lab files are still available at:${RST}\n"
  printf "  ${DIM}  ~/.dockermaster/lab/${RST}\n"
  sep; blank
  bigcap
  printf "  ${GRN}Nice work, ${BOLD}%s${RST}${GRN}. Keep building.${RST}\n" "$PLAYER_NAME"
  blank
  log "Session ended. Score: ${SCORE}/${MAX_SCORE} (${pct}%) Level: ${grade}"
}

# =============================================================================
#  TRAP + MAIN
# =============================================================================
on_exit() {
  echo; blank
  printf "  ${YLW}Interrupted. Score so far: %d/%d${RST}\n" "$SCORE" "$MAX_SCORE"
  log "Interrupted at zone ${ZONE}. Score: ${SCORE}/${MAX_SCORE}"
  exit 0
}
trap on_exit INT TERM

main() {
  parse_args "$@"
  setup_game
  intro

  [[ $START_ZONE -le 1 ]] && zone_concepts
  [[ $START_ZONE -le 2 ]] && zone_dockerfile
  [[ $START_ZONE -le 3 ]] && zone_multistage
  [[ $START_ZONE -le 4 ]] && zone_commands
  [[ $START_ZONE -le 5 ]] && zone_compose
  [[ $START_ZONE -le 6 ]] && zone_ports
  [[ $START_ZONE -le 7 ]] && zone_volumes_cache

  results
}

main "$@"


