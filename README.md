# dreb4ci

Dockerized Ruby Environment Boilerplate for Continuous Integration

## Goals

Sharing a common Ruby development and continuous integration (CI) container
for a remote Linux/OsX team and keep most of test & CI code in repository:

* [ ] Bundler friendly (mounted `.bundle` with proper rights)
* [ ] custom Ruby version via `.ruby-version` file
* [ ] Debian based container
* [ ] dind (Docker-in-Docker) support for dockerized CI environment
* [ ] local environment settings (HTTP proxy, processor count, etc.)
* [ ] local rc files if present (`~/.bashrc`, `~/.gitconfig`, `~/.inputrc`, `~/.nanorc`, `~/.tmux.conf` and `~/.vimrc`)
* [ ] minimal but useful remote pair programming toolset (**curl**, **git**, **gnupg**, **less**, **make**, **rsync**, **ssh**, **tmate**, **tmux** and **vim**)
* [ ] speed up CI by rebuilding container on changes only (`Dockerfile`, new `master`)
* [ ] [user namespaces isolation](https://docs.docker.com/engine/security/userns-remap) if present
* [ ] works on OsX (tested on **High Sierra** with [Docker for Mac](https://github.com/docker/for-mac))
