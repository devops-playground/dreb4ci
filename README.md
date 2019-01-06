# dreb4ci

Dockerized Ruby Environment Boilerplate for Continuous Integration

## Goals

Sharing a common Ruby development and continuous integration (CI) container
for a remote Linux/OsX team and keep most of test & CI code in repository:

* [ ] Bundler friendly (mounted `.bundle` with proper rights)
* [ ] custom Ruby version via `.ruby-version` file
* [x] Debian based container
* [x] dind (Docker-in-Docker) support for dockerized CI environment
* [x] local environment settings (HTTP proxy, processor count, etc.)
* [x] local rc files if present (`~/.bashrc`, `~/.gitconfig`, `~/.inputrc`, `~/.nanorc`, `~/.tmux.conf` and `~/.vimrc`)
* [x] minimal but useful remote pair programming toolset (**curl**, **git**, **gnupg**, **less**, **make**, **rsync**, **ssh**, **tmate**, **tmux** and **vim**)
* [ ] speed up CI by rebuilding container on changes only (`Dockerfile`, new `master`)
* [x] [user namespaces isolation](https://docs.docker.com/engine/security/userns-remap) if present
* [x] works on OsX (tested on **High Sierra** with [Docker for Mac](https://github.com/docker/for-mac))

## In-line help

```Shell
targets:
  acl             Add nested ACLs rights (need sudo)
  build           Build project container
  clean           Clean acls
  clobber         Do clean, rmi, remove backup (*~) files
  help            Show this help
  info            Show Docker version and user id
  login           Login to Docker registry
  logout          Logout from Docker registry
  pull            Run 'docker pull' with image
  push            Run 'docker push' with image
  rebuild-all     Clobber all, build and run test
  rmi             Remove project container
  test-dind       Run 'docker run hello-world' within image
  test            Test (CI)
  usershell       Run user shell
```

## Overridable environment variables

| Name | default | build-arg | env-var | description
|:-|-|-|-|:-|
| `CI` | | N | Y (if defined) | Continuous Integration flag |
| `CIRCLECI` | | N | Y (if defined) | Circle CI flag |
| `DEB_COMPONENTS` | see `Dockerfile` | Y (if defined) | N | Debian sources components |
| `DEB_DIST` | see `Dockerfile` | Y (if defined) | N | Debian distribution |
| `DEB_DOCKER_GPGID` | see `Dockerfile` | Y (if defined) | N | Debian GPG Key for `docker-ce` Debian package |
| `DEB_DOCKER_URL` | see `Dockerfile` | Y (if defined) | N | Docker Debian package apt source URL |
| `DEB_MIRROR_URL` | see `Dockerfile` | Y (if defined) | N | Debian apt mirror URL |
| `DEB_PACKAGES` | see `Dockerfile` | Y (if defined) | N | Debian apt mirror URL |
| `DEB_SECURITY_MIRROR_URL` | see `Dockerfile` | Y (if defined) | N | Debian apt security mirror URL |
| `DOCKER_BUILD_TAG` | `$(id -u -n)/${PROJECT_NAME}` | N | Y (if defined) | Docker build tag (suffixed by `.ci` when `${CI}` is defined |
| `DOCKER_PASSWORD` | | N | Y (if defined) |  Docker registry password (for login/logout) |
| `DOCKER_REGISTRY` | from `docker info` | N | Y (if defined) |  Docker registry URL (for login/logout) |
| `DOCKER_USERNAME` | | N | Y (if defined) |  Docker registry username (for login/logout) |
| `DOCKER_USERNS_GROUP` | `dock-g` | N | N |  Docker user namespace remap group (for ACLs) |
| `DOCKER_USER_GID` | `8888` | Y | N |  normal account `uid` inside container |
| `DOCKER_USER_UID` | `8888` | Y | N |  normal account `uid` inside container |
| `DOCKER_USER` | `dev` | Y | Y (`USER`) | normal account `login` inside container |
| `GITLAB_CI` | | N | Y (if defined) | Gitlab CI flag |
| `HTTP_PROXY` | | Y (if defined) | Y (if defined) | HTTP proxy cache URL |
| `MAKEFLAGS` | | N | Y (if defined) | GNU make flags |
| `NB_PROC` | `$(nproc)` (Linux) or `sysctl -n hw.ncpu` (OsX) | Y | Y | Processor count |
| `PROJECT_NAME` | `$(basename $(pwd))` | N | Y (`hostname`) | Container build tag project name part (`user_name/project_name:branch`) / container hostname |
| `PROJECT_OWNER` | `${DOCKER_USERNAME}` | N | Y | Container build tag user name part (`user_name/project_name:branch`)  |
| `TERM` | `${TERM}` | N | Y | Terminal name |
| `TRAVIS` | | N | Y (if defined) | Travis CI flag |
| `USERNS` | from `docker info` | N | Y (if defined) | Docker user namespace isolation flag |
| `WORKING_DIR` | `/src/${PROJECT_NAME}` | N | Y | working directory inside container |

## Docker registry

You **must** set `DOCKER_USERNAME` and `DOCKER_PASSWORD` environment variables
to `login` in, `pull` from or `push` to Docker registry. `DOCKER_REGISTRY` is
set to configured default given by `docker info` command and can be overridden.

## User namespace isolation

It's activated if `dockerd` provides it, given by `docker info` command. It can
be desactivated by setting `USERNS` environment variable to anything but
`yes` string.

Please read [Isolate containers with a user namespace](https://docs.docker.com/engine/security/userns-remap/) to set a proper docker group remaping. Default remaping
group is `dock-g` and can be overridden by setting `DOCKER_USERNS_GROUP`.
Example of working configuration for a `foo` account:

* `/etc/passwd`
    ```
    # [...]
    foo:x:1000:1000:Foo account:/home/foo:/bin/bash
    # [...]
    ```
* `/etc/group`
    ```
    # [...]
    docker:x:888:foo
    foo:x:1000:
    dock-g:x:108887:foo
    # [...]
    ```
* `/etc/subuid`
    ```
    # [...]
    foo:1000:1
    foo:100000:65536
    # [...]
    ```

* `/etc/subgid`
    ```
    # [...]
    foo:888:1
    foo:100000:65536
    # [...]
    ```

Then run **dockerd** with valid user namespace parameter: `--userns-remap=foo`.
