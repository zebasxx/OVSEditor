#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:-x64}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${OVS_EDITOR_DOCKER_IMAGE:-mcr.microsoft.com/devcontainers/typescript-node:22-bookworm}"
WORKSPACE_VOLUME="${OVS_EDITOR_WORKSPACE_VOLUME:-ovs-editor-workspace}"
NPM_CACHE_VOLUME="${OVS_EDITOR_NPM_CACHE_VOLUME:-ovs-editor-npm-cache}"
ARTIFACT_DIR="$ROOT/.build/artifacts/deb"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
DOCKER_TTY_ARGS=()

if [ -t 1 ]; then
	DOCKER_TTY_ARGS=(-t)
fi

case "$ARCH" in
	x64) DEB_ARCH="amd64" ;;
	arm64) DEB_ARCH="arm64" ;;
	armhf) DEB_ARCH="armhf" ;;
	*)
		echo "Unsupported arch: $ARCH" >&2
		echo "Expected one of: x64, arm64, armhf" >&2
		exit 2
		;;
esac

mkdir -p "$ARTIFACT_DIR"
rm -f "$ARTIFACT_DIR"/ovs-editor_*_"$DEB_ARCH".deb
docker volume create "$WORKSPACE_VOLUME" >/dev/null
docker volume create "$NPM_CACHE_VOLUME" >/dev/null

docker run --rm "${DOCKER_TTY_ARGS[@]}" \
	-e "VSCODE_ARCH=$ARCH" \
	-e "npm_config_arch=$ARCH" \
	-e "HOST_UID=$HOST_UID" \
	-e "HOST_GID=$HOST_GID" \
	-v "$ROOT:/host:ro" \
	-v "$ARTIFACT_DIR:/artifacts" \
	-v "$WORKSPACE_VOLUME:/work" \
	-v "$NPM_CACHE_VOLUME:/home/node/.npm" \
	-w /work/repo \
	"$IMAGE" \
	bash --noprofile --norc -c "
		set -euo pipefail

		apt-get update
		apt-get install -y \
			build-essential \
			curl \
			dpkg-dev \
			fakeroot \
			file \
			libkrb5-dev \
			libnotify-bin \
			libx11-dev \
			libx11-xcb-dev \
			libxkbfile-dev \
			pkg-config \
			python-is-python3 \
			rsync

		mkdir -p /work/repo /home/node/.npm
		chown -R node:node /work /home/node/.npm

		rsync -a --delete \
			--exclude='.build' \
			--exclude='node_modules' \
			--exclude='out' \
			--exclude='out-*' \
			--exclude='VSCode-*' \
			/host/ /work/repo/

		chown -R node:node /work/repo

		sudo -u node git config --global --add safe.directory /work/repo
		sudo -u node npm install
		sudo -u node npm run gulp vscode-linux-$ARCH-min
		APP_NAME=\"\$(node -p \"require('./product.json').applicationName\")\"
		TUNNEL_APP_NAME=\"\$(node -p \"require('./product.json').tunnelApplicationName\")\"
		if [ ! -e \"/work/VSCode-linux-$ARCH/bin/\$TUNNEL_APP_NAME\" ]; then
			ln -s \"../\$APP_NAME\" \"/work/VSCode-linux-$ARCH/bin/\$TUNNEL_APP_NAME\"
		fi
		rm -rf \"/work/VSCode-linux-$ARCH/resources/app/node_modules/@parcel/watcher-linux-$ARCH-musl\"
		sudo -u node npm run gulp vscode-linux-$ARCH-prepare-deb
		sudo -u node npm run gulp vscode-linux-$ARCH-build-deb

		mkdir -p /artifacts
		cp .build/linux/deb/$DEB_ARCH/deb/*.deb /artifacts/
		chown \"\$HOST_UID:\$HOST_GID\" /artifacts/*.deb
		file /artifacts/*.deb
	"

echo
echo "Debian package written to:"
ls -1 "$ARTIFACT_DIR"/*.deb
