FROM rockylinux:9

RUN dnf install -y rpm-build rpmdevtools wget git && \
    dnf clean all && \
    rpmdev-setuptree

WORKDIR /build
CMD ["tail", "-f", "/dev/null"]
