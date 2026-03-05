# syntax=docker/dockerfile:1
ARG BUILDPLATFORM=linux/amd64
FROM --platform=$BUILDPLATFORM rockylinux:9

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Core defaults (override at runtime)
ENV POSTGRES_USER=postgres \
    POSTGRES_DB=postgres \
    PGDATA=/var/lib/pgsql/18/data \
    PATH=/usr/pgsql-18/bin:$PATH

# New: preload libs are configurable; init dir is standard
ENV PG_SHARED_PRELOAD_LIBRARIES="pg_stat_statements,vector,pg_ivm,pg_background,pg_squeeze,pgaudit" \
    PG_INIT_DIR="/docker-entrypoint-initdb.d"

# Postgres tuning defaults (override at runtime)
ENV PG_MAX_CONNECTIONS=100 \
    PG_SHARED_BUFFERS=256MB \
    PG_EFFECTIVE_CACHE_SIZE=1GB \
    PG_WORK_MEM=4MB \
    PG_MAINTENANCE_WORK_MEM=64MB \
    PG_MAX_WAL_SIZE=2GB \
    PG_CHECKPOINT_TIMEOUT=10min \
    PG_LOG_MIN_DURATION_STATEMENT=1000 \
    \
    PG_MAX_REPLICATION_SLOTS=10 \
    PG_MAX_WAL_SENDERS=10 \
    PG_WAL_LEVEL=logical \
    PG_ARCHIVE_MODE=off \
    PG_ARCHIVE_COMMAND="" \
    PG_HOT_STANDBY=on \
    PG_MAX_LOGICAL_REPLICATION_WORKERS=4 \
    \
    PG_MAX_WORKER_PROCESSES=8 \
    PG_MAX_PARALLEL_WORKERS=8 \
    PG_MAX_PARALLEL_WORKERS_PER_GATHER=2 \
    PG_MAX_PARALLEL_MAINTENANCE_WORKERS=2 \
    \
    PG_LOG_DESTINATION=stderr \
    PG_LOGGING_COLLECTOR=on \
    PG_LOG_DIRECTORY=/var/log/postgresql \
    PG_LOG_FILENAME=postgresql-%Y-%m-%d.log \
    PG_LOG_ROTATION_AGE=1d \
    PG_LOG_ROTATION_SIZE=100MB \
    PG_LOG_LINE_PREFIX="\"%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h \"" \
    PG_LOG_STATEMENT=none \
    \
    PG_LISTEN_ADDRESSES="*" \
    PG_PORT=5432 \
    PG_SSL=off \
    PG_SSL_CERT_FILE="" \
    PG_SSL_CA_FILE="" \
    \
    PG_RANDOM_PAGE_COST=1.1 \
    PG_EFFECTIVE_IO_CONCURRENCY=200 \
    PG_DEFAULT_STATISTICS_TARGET=100 \
    PG_AUTOVACUUM=on \
    PG_AUTOVACUUM_MAX_WORKERS=3

################################################################################
# System update + base tools
################################################################################
RUN dnf -y update && dnf -y upgrade && dnf -y distro-sync && \
    dnf -y install --allowerasing \
      ca-certificates \
      curl \
      wget \
      git \
      vim \
      procps-ng \
      util-linux \
      python3 \
      python3-pip \
    && dnf clean all

################################################################################
# Build dependencies
################################################################################
RUN dnf -y groupinstall "Development Tools" && \
    dnf -y install \
      gcc gcc-c++ make cmake \
      libedit-devel readline-devel \
      openssl-devel \
      libxml2-devel libxslt-devel \
      openldap-devel pam-devel \
      perl perl-devel perl-ExtUtils-MakeMaker perl-Test-Simple perl-CPAN \
      python3-devel tcl-devel \
      libuuid-devel systemd-devel \
      icu libicu-devel \
      krb5-devel \
      bison flex gettext-devel \
      clang llvm-devel \
    && dnf clean all

################################################################################
# PGDG repo + PostgreSQL 18 + extensions (arch-aware)
################################################################################
ARG PGDG_RPM_URL_AMD64=https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
ARG PGDG_RPM_URL_ARM64=https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-aarch64/pgdg-redhat-repo-latest.noarch.rpm

RUN arch="$(uname -m)" && \
    if [[ "$arch" == "x86_64" ]]; then repo_rpm="$PGDG_RPM_URL_AMD64"; \
    elif [[ "$arch" == "aarch64" ]]; then repo_rpm="$PGDG_RPM_URL_ARM64"; \
    else echo "Unsupported arch: $arch" && exit 1; fi && \
    dnf -y install "$repo_rpm" && \
    dnf -y install epel-release dnf-plugins-core && \
    dnf -y config-manager --set-enabled crb && \
    dnf -y makecache && \
    dnf -y install perl-IPC-Run && \
    dnf -qy module disable postgresql && \
    dnf -y install \
      postgresql18-server \
      postgresql18-contrib \
      postgresql18-plpython3 \
      postgresql18-devel \
      pgvector_18 \
      pg_background_18 \
      pg_ivm_18 \
      pg_squeeze_18 \
      pgaudit_18 \
      plpgsql_check_18 \
    && dnf clean all

################################################################################
# Python packages (AI + DB tooling)
################################################################################
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --no-cache-dir \
      openai \
      requests \
      numpy \
      pandas \
      psycopg2-binary \
      sqlalchemy

################################################################################
# Runtime directories + permissions
################################################################################
RUN mkdir -p \
      "${PGDATA}" \
      /var/log/postgresql \
      /var/run/postgresql \
      "${PG_INIT_DIR}" \
    && chown -R postgres:postgres \
      /var/lib/pgsql \
      /var/log/postgresql \
      /var/run/postgresql \
      "${PG_INIT_DIR}"

################################################################################
# Copy scripts
################################################################################
COPY scripts/*.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

EXPOSE 5432

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
  CMD /usr/pgsql-18/bin/pg_isready -h localhost -p ${PG_PORT:-5432} -U ${POSTGRES_USER:-postgres} || exit 1

CMD ["/usr/local/bin/start-postgres.sh"]

LABEL maintainer="Vibhor Kumar <vibhor.aim@gmail.com>" \
      description="PostgreSQL 18 + extensions on Rocky 9 with env-driven conf.d includes and init scripts" \
      version="pg18-multi-extensions-rocky9" \
      postgresql.version="18" \
      base.image="rockylinux:9"
