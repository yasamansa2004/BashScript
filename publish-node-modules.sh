first
```
npm login   --registry=http://192.168.7.250:8081/repository/npm-hosted/
npm whoami   --registry=http://192.168.7.250:8081/repository/npm-hosted/

npm config set registry http://192.168.7.250:8081/repository/npm-group/
npm config get registry

```
then 
```
vim publish-node-modules.sh
sudo chmod +xpublish-node-modules.sh
```

#!/usr/bin/env bash

set -uo pipefail

REGISTRY="http://192.168.7.250:8081/repository/npm-hosted/"
BASE_DIR="$HOME/Desktop"

PROJECTS=(
    "$BASE_DIR/admin-npm-package"
    "$BASE_DIR/customer-npm-package"
    "$BASE_DIR/seller-npm-package"
)

PUBLISHED=0
SKIPPED=0
FAILED=0
FOUND=0

declare -A SEEN

echo "=============================================="
echo " NPM node_modules -> Nexus Hosted"
echo "=============================================="
echo "Registry: $REGISTRY"
echo

# ------------------------------------------------
# Check authentication
# ------------------------------------------------

echo "[INFO] Checking Nexus authentication..."

if ! npm whoami --registry="$REGISTRY" >/dev/null 2>&1; then
    echo
    echo "[ERROR] You are not logged in to Nexus."
    echo
    echo "Run:"
    echo
    echo "npm login --registry=$REGISTRY --auth-type=legacy"
    echo
    exit 1
fi

NEXUS_USER=$(npm whoami --registry="$REGISTRY")

echo "[OK] Logged in as: $NEXUS_USER"
echo

# ------------------------------------------------
# Process projects
# ------------------------------------------------

for PROJECT in "${PROJECTS[@]}"; do

    NODE_MODULES="$PROJECT/node_modules"

    echo
    echo "=============================================="
    echo "Project: $(basename "$PROJECT")"
    echo "=============================================="

    if [[ ! -d "$NODE_MODULES" ]]; then
        echo "[WARN] node_modules not found:"
        echo "       $NODE_MODULES"
        continue
    fi

    # Find package.json files directly under node_modules
    # including scoped packages.
    while IFS= read -r PACKAGE_JSON; do

        PACKAGE_DIR="$(dirname "$PACKAGE_JSON")"

        # Read package name
        PACKAGE_NAME=$(
            node -e '
                try {
                    const p = require(process.argv[1]);
                    if (p.name) process.stdout.write(p.name);
                } catch (_) {}
            ' "$PACKAGE_JSON"
        )

        # Read package version
        PACKAGE_VERSION=$(
            node -e '
                try {
                    const p = require(process.argv[1]);
                    if (p.version) process.stdout.write(p.version);
                } catch (_) {}
            ' "$PACKAGE_JSON"
        )

        # Invalid package.json
        if [[ -z "$PACKAGE_NAME" || -z "$PACKAGE_VERSION" ]]; then
            continue
        fi

        # Ignore private packages
        PRIVATE=$(
            node -e '
                try {
                    const p = require(process.argv[1]);
                    process.stdout.write(String(p.private === true));
                } catch (_) {}
            ' "$PACKAGE_JSON"
        )

        if [[ "$PRIVATE" == "true" ]]; then
            echo "[SKIP] $PACKAGE_NAME@$PACKAGE_VERSION (private)"
            ((SKIPPED++))
            continue
        fi

        KEY="${PACKAGE_NAME}@${PACKAGE_VERSION}"

        # ------------------------------------------------
        # Duplicate package/version
        # ------------------------------------------------

        if [[ -n "${SEEN[$KEY]+exists}" ]]; then
            continue
        fi

        SEEN["$KEY"]=1
        ((FOUND++))

        echo
        echo "[FOUND] $PACKAGE_NAME@$PACKAGE_VERSION"

        # ------------------------------------------------
        # Check Nexus
        # ------------------------------------------------

        if npm view "$PACKAGE_NAME@$PACKAGE_VERSION" \
            version \
            --registry="$REGISTRY" \
            >/dev/null 2>&1; then

            echo "[SKIP] Already exists in Nexus"
            ((SKIPPED++))
            continue
        fi

        # ------------------------------------------------
        # Create tarball
        # ------------------------------------------------

        echo "[PACK] $PACKAGE_NAME@$PACKAGE_VERSION"

        PACK_OUTPUT=$(
            cd "$PACKAGE_DIR" || exit 1
            npm pack --json 2>/dev/null
        )

        if [[ $? -ne 0 || -z "$PACK_OUTPUT" ]]; then
            echo "[ERROR] npm pack failed"
            ((FAILED++))
            continue
        fi

        TARBALL=$(
            echo "$PACK_OUTPUT" |
            node -e '
                let input = "";

                process.stdin.on("data", chunk => {
                    input += chunk;
                });

                process.stdin.on("end", () => {
                    try {
                        const data = JSON.parse(input);
                        process.stdout.write(data[0].filename || "");
                    } catch (_) {}
                });
            '
        )

        if [[ -z "$TARBALL" ]]; then
            echo "[ERROR] Could not determine tarball"
            ((FAILED++))
            continue
        fi

        TARBALL_PATH="$PACKAGE_DIR/$TARBALL"

        if [[ ! -f "$TARBALL_PATH" ]]; then
            echo "[ERROR] Tarball not found:"
            echo "        $TARBALL_PATH"
            ((FAILED++))
            continue
        fi

        # ------------------------------------------------
        # Publish
        # ------------------------------------------------

        echo "[PUBLISH] $PACKAGE_NAME@$PACKAGE_VERSION"

        if npm publish "$TARBALL_PATH" \
            --registry="$REGISTRY"; then

            echo "[OK] Published: $PACKAGE_NAME@$PACKAGE_VERSION"
            ((PUBLISHED++))

        else

            echo "[ERROR] Publish failed:"
            echo "        $PACKAGE_NAME@$PACKAGE_VERSION"

            ((FAILED++))
        fi

        # Remove generated tgz
        rm -f "$TARBALL_PATH"

    done < <(
        find "$NODE_MODULES" \
            -type f \
            -name "package.json" \
            -not -path "*/.cache/*" \
            -not -path "*/.pnpm/*" \
            2>/dev/null
    )

done

# ------------------------------------------------
# Summary
# ------------------------------------------------

echo
echo
echo "=============================================="
echo " SUMMARY"
echo "=============================================="
echo "Packages found : $FOUND"
echo "Published      : $PUBLISHED"
echo "Skipped        : $SKIPPED"
echo "Failed         : $FAILED"
echo "=============================================="
