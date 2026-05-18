#!/usr/bin/env bash
set -euo pipefail

# Emit a complete CircleCI continuation config to stdout.
# Called by the setup job in config.yml.
#
# Tag builds:    single job for the personality matching the tag prefix.
# Branch builds: no-op (personalities are only published on tags).

KLAUSCTL_VERSION="0.0.82"

emit_tag_job() {
  local name="$1"
  sed "s/@@NAME@@/${name}/g; s/@@KLAUSCTL_VERSION@@/${KLAUSCTL_VERSION}/g" <<'TEMPLATE'
version: 2.1

jobs:
  publish-personality-oci:
    docker:
      - image: cimg/base:stable
    environment:
      REGISTRY: gsoci.azurecr.io
      REGISTRY_PATH: giantswarm/klaus-personalities
      KLAUSCTL_VERSION: "@@KLAUSCTL_VERSION@@"
    steps:
      - checkout

      - run:
          name: Install klausctl
          command: |
            set -euo pipefail
            curl -fsSL -o /tmp/klausctl.tar.gz "https://github.com/giantswarm/klausctl/releases/download/v${KLAUSCTL_VERSION}/klausctl_Linux_x86_64.tar.gz"
            tar -xzf /tmp/klausctl.tar.gz -C /tmp --strip-components=1 klausctl_Linux_x86_64/klausctl
            mkdir -p "${HOME}/bin"
            install /tmp/klausctl "${HOME}/bin/klausctl"
            echo 'export PATH="${HOME}/bin:${PATH}"' >> "${BASH_ENV}"
            source "${BASH_ENV}"
            klausctl version

      - run:
          name: Configure registry credentials
          command: |
            set -euo pipefail

            username="${ACR_GSOCI_USERNAME:-${ACR_USERNAME:-}}"
            password="${ACR_GSOCI_PASSWORD:-${ACR_PASSWORD:-}}"

            if [ -z "${username}" ] || [ -z "${password}" ]; then
              echo "Missing OCI registry credentials in context."
              echo "Expected ACR_GSOCI_USERNAME/ACR_GSOCI_PASSWORD (or fallback ACR_USERNAME/ACR_PASSWORD)."
              exit 1
            fi

            mkdir -p "${HOME}/.docker"
            auth=$(printf '%s:%s' "${username}" "${password}" | base64 -w0)
            printf '{"auths":{"%s":{"auth":"%s"}}}' "${REGISTRY}" "${auth}" > "${HOME}/.docker/config.json"

      - run:
          name: Push personality @@NAME@@
          command: |
            set -euo pipefail
            source "${BASH_ENV}"

            tag="${CIRCLE_TAG#@@NAME@@/}"
            ref="${REGISTRY}/${REGISTRY_PATH}/@@NAME@@:${tag}"
            echo "Pushing personality: @@NAME@@ -> ${ref}"
            klausctl personality push "personalities/@@NAME@@" "${ref}"

workflows:
  publish-personality:
    jobs:
      - publish-personality-oci:
          context: architect
          filters:
            tags:
              only: /^@@NAME@@\/v.*/
            branches:
              ignore: /.*/
TEMPLATE
}

emit_noop() {
  cat <<'EOF'
version: 2.1

jobs:
  no-op:
    docker:
      - image: cimg/base:current
    steps:
      - run: echo "No personality directories changed"

workflows:
  noop:
    jobs:
      - no-op
EOF
}

# --- Main ---

if [[ -n "${CIRCLE_TAG:-}" ]]; then
  PREFIX="${CIRCLE_TAG%%/v*}"

  if [[ ! -d "personalities/${PREFIX}" ]]; then
    echo "ERROR: Tag ${CIRCLE_TAG} does not match any personalities/ directory" >&2
    exit 1
  fi

  emit_tag_job "$PREFIX"
  exit 0
fi

# Branch builds: no-op (personalities are only published on tag events)
emit_noop
