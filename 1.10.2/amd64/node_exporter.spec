%define _rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.x86_64.rpm

Name:           node_exporter
Version:        1.10.2
Release:        1%{?dist}
Summary:        Prometheus exporter for hardware and OS metrics
License:        Apache License 2.0
URL:            https://github.com/prometheus/node_exporter
Source0:        %{name}-%{version}.linux-amd64.tar.gz
Source1:        node_exporter.service

AutoReqProv:    no
Requires:       systemd

%global debug_package %{nil}

%description
The Prometheus node_exporter exposes hardware and OS metrics from *NIX systems. It is used to gather system statistics for monitoring purposes.

%prep
%setup -q -n %{name}-%{version}.linux-amd64

%build
# No build required, binaries are already compiled

%install
# Install the binary
install -D -m 0755 %{_builddir}/%{name}-%{version}.linux-amd64/node_exporter %{buildroot}/usr/local/bin/node_exporter

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
if [ $1 -eq 0 ]; then
    systemctl stop node_exporter || true
    systemctl disable node_exporter || true
fi

%files
/usr/local/bin/node_exporter
/usr/lib/systemd/system/node_exporter.service

%changelog
* Sun Jun 07 2026 Your Name <mithuneeecu@gmail.com> - 1.10.2-1
- RPM build for node_exporter 1.10.2 (x86_64)
