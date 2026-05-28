#!/usr/bin/env bash
set -euo pipefail

# Emit a complete CircleCI continuation config to stdout.
# Called by the setup job in config.yml.
#
# Tag builds:    single job for the personality matching the tag prefix.
# Branch builds: no-op (personalities are only published on tags).

KLAUSCTL_VERSION="0.0.92"

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
          name: Install cosign and crane
          command: |
            set -euo pipefail
            COSIGN_VERSION="v2.5.0"
            CRANE_VERSION="v0.20.5"
            mkdir -p "${HOME}/bin"
            curl -fsSL -o /tmp/cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
            install /tmp/cosign "${HOME}/bin/cosign"
            curl -fsSL -o /tmp/go-containerregistry.tgz "https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_x86_64.tar.gz"
            tar -xzf /tmp/go-containerregistry.tgz -C /tmp crane
            install /tmp/crane "${HOME}/bin/crane"
            echo 'export PATH="${HOME}/bin:${PATH}"' >> "${BASH_ENV}"
            source "${BASH_ENV}"
            cosign version
            crane version

      - run:
          name: Mint Sigstore OIDC token
          command: |
            set -euo pipefail
            SIGSTORE_ID_TOKEN=$(circleci run oidc get --claims '{"aud": "sigstore"}' --root-issuer)
            echo "export SIGSTORE_ID_TOKEN=\"$SIGSTORE_ID_TOKEN\"" >> "$BASH_ENV"

      - run:
          name: Push personality @@NAME@@
          command: |
            set -euo pipefail
            source "${BASH_ENV}"

            tag="${CIRCLE_TAG#@@NAME@@/}"
            ref="${REGISTRY}/${REGISTRY_PATH}/@@NAME@@:${tag}"
            echo "Pushing personality: @@NAME@@ -> ${ref}"
            klausctl personality push "personalities/@@NAME@@" "${ref}"

      - run:
          name: Sign and verify personality @@NAME@@ with cosign
          command: |
            set -euo pipefail
            source "${BASH_ENV}"

            tag="${CIRCLE_TAG#@@NAME@@/}"
            ref="${REGISTRY}/${REGISTRY_PATH}/@@NAME@@:${tag}"

            # Resolve to immutable digest before signing, mirroring the architect-orb
            # cosign step. Signing a tag would lose the binding if the tag is ever
            # repushed; signing a digest is permanent.
            digest=$(crane digest "${ref}")
            if [ -z "${digest}" ]; then
              echo "Could not resolve digest for ${ref}"
              exit 1
            fi
            echo "Signing ${ref}@${digest}"

            cosign sign --yes "${ref}@${digest}"

            echo "Verifying signature"
            cosign verify \
              --certificate-oidc-issuer-regexp '^https://oidc\.circleci\.com' \
              --certificate-identity-regexp '^https://circleci\.com/api/v2/projects/[a-f0-9-]+/pipeline-definitions/[a-f0-9-]+$' \
              "${ref}@${digest}" > /dev/null
            echo "OK: ${ref}@${digest}"

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
