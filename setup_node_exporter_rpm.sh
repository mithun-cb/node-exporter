#!/bin/bash
set -e

# ─────────────────────────────────────────
#  Prompt for version and architecture
# ─────────────────────────────────────────
read -rp "Enter node_exporter version (e.g. 1.11.1): " VERSION

if [[ -z "$VERSION" ]]; then
    echo "ERROR: Version cannot be empty."
    exit 1
fi

echo ""
echo "Select architecture:"
echo "  1) amd64   (x86_64)"
echo "  2) arm64   (aarch64)"
read -rp "Enter choice [1/2]: " ARCH_CHOICE

case "$ARCH_CHOICE" in
    1)
        TARBALL_ARCH="amd64"
        RPM_ARCH="x86_64"
        ;;
    2)
        TARBALL_ARCH="arm64"
        RPM_ARCH="aarch64"
        ;;
    *)
        echo "ERROR: Invalid choice. Enter 1 or 2."
        exit 1
        ;;
esac

NAME="node_exporter"
TARBALL="${NAME}-${VERSION}.linux-${TARBALL_ARCH}.tar.gz"
URL="https://github.com/prometheus/${NAME}/releases/download/v${VERSION}/${TARBALL}"
DATE=$(date +"%a %b %d %Y")

# ─────────────────────────────────────────
#  Version + arch specific repo folder
# ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_DIR="${SCRIPT_DIR}/${VERSION}/${TARBALL_ARCH}"

# ─────────────────────────────────────────
#  rpmbuild dirs
# ─────────────────────────────────────────
RPMBUILD_DIR="${HOME}/rpmbuild"

echo ""
echo "  Version    : ${VERSION}"
echo "  Architecture: ${TARBALL_ARCH} (RPM: ${RPM_ARCH})"
echo "  Repo folder: ${VERSION_DIR}"
echo "  Tarball    : ${TARBALL}"
echo "  URL        : ${URL}"
echo ""

# ─────────────────────────────────────────
#  1. Create version/arch folder in repo
# ─────────────────────────────────────────
if [[ -d "${VERSION_DIR}" ]]; then
    echo "WARNING: Folder ${VERSION_DIR} already exists. Overwriting files inside."
fi
mkdir -p "${VERSION_DIR}"
echo "[1/5] Version folder created: ${VERSION_DIR}"

# ─────────────────────────────────────────
#  2. Create node_exporter.service
# ─────────────────────────────────────────
cat > "${VERSION_DIR}/node_exporter.service" <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF
echo "[2/5] node_exporter.service created."

# ─────────────────────────────────────────
#  3. Create node_exporter.spec
# ─────────────────────────────────────────
cat > "${VERSION_DIR}/node_exporter.spec" <<EOF
Name:           node_exporter
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Prometheus exporter for hardware and OS metrics
License:        Apache License 2.0
URL:            https://github.com/prometheus/node_exporter
Source0:        %{name}-%{version}.linux-${TARBALL_ARCH}.tar.gz
Source1:        node_exporter.service

Requires:       systemd

%global debug_package %{nil}

%description
The Prometheus node_exporter exposes hardware and OS metrics from *NIX systems. It is used to gather system statistics for monitoring purposes.

%prep
%setup -q -n %{name}-%{version}.linux-${TARBALL_ARCH}

%build
# No build required, binaries are already compiled

%install
# Install the binary
install -D -m 0755 %{_builddir}/%{name}-%{version}.linux-${TARBALL_ARCH}/node_exporter %{buildroot}/usr/local/bin/node_exporter

# Install the systemd service file
install -D -m 0644 %{SOURCE1} %{buildroot}/usr/lib/systemd/system/node_exporter.service

%post
# Create a node_exporter user if it doesn't exist
getent passwd node_exporter > /dev/null || useradd -r -s /sbin/nologin -d / -c "Prometheus Node Exporter" node_exporter

#Change the binary ownership to "node_exporter"
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Enable and reload the systemd service
systemctl daemon-reload
systemctl enable node_exporter

%preun
# Stop and disable the service before uninstalling
if [ \$1 -eq 0 ]; then
    systemctl stop node_exporter || true
    systemctl disable node_exporter || true
fi

%files
/usr/local/bin/node_exporter
/usr/lib/systemd/system/node_exporter.service

%changelog
* ${DATE} Your Name <mithuneeecu@gmail.com> - ${VERSION}-1
- RPM build for node_exporter ${VERSION} (${RPM_ARCH})
EOF
echo "[3/5] node_exporter.spec created."

# ─────────────────────────────────────────
#  4. Download tarball into version/arch folder
#     + copy files to rpmbuild SOURCES/SPECS
# ─────────────────────────────────────────
mkdir -p "${RPMBUILD_DIR}"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}

echo "[4/5] Downloading ${TARBALL}..."
wget -q --show-progress -P "${VERSION_DIR}/" "${URL}"
echo "      Download complete."

# Sync to rpmbuild working dirs
cp "${VERSION_DIR}/${TARBALL}"             "${RPMBUILD_DIR}/SOURCES/"
cp "${VERSION_DIR}/node_exporter.service" "${RPMBUILD_DIR}/SOURCES/"
cp "${VERSION_DIR}/node_exporter.spec"    "${RPMBUILD_DIR}/SPECS/"

# ─────────────────────────────────────────
#  5. Build RPM → copy output to version/arch folder
# ─────────────────────────────────────────
echo "[5/5] Building RPM..."
rpmbuild -ba --target ${RPM_ARCH} "${RPMBUILD_DIR}/SPECS/node_exporter.spec"

RPM_FILE=$(find "${RPMBUILD_DIR}/RPMS/" -name "node_exporter-${VERSION}*.rpm" | head -1)
cp "${RPM_FILE}" "${VERSION_DIR}/"

echo ""
echo "All files for v${VERSION} (${RPM_ARCH}) are in: ${VERSION_DIR}"
echo ""
ls -1 "${VERSION_DIR}"
