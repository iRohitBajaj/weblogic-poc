# LICENSE UPL 1.0
#
# Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
#
# ORACLE DOCKERFILES PROJECT
# --------------------------
# This Dockerfile extends the Oracle WebLogic image built under 12213-doma-home-in-image.
#
# It will deploy any package defined in APP_PKG_FILE.
# into the DOMAIN_HOME with name defined in APP_NAME
#
# HOW TO BUILD THIS IMAGE
# -----------------------
# Run:
#      $ docker build --build-arg APPLICATION_NAME=sample --build-arg APPLICATION_PKG=archive.zip -t 12213-domain-with-app .
#

# Pull base image
# ---------------
FROM  dockerish82/weblogicrepo:12.2.1.4


ARG CUSTOM_DOMAIN_NAME="${CUSTOM_DOMAIN_NAME:-domain1}"
ARG CUSTOM_ADMIN_PORT="${CUSTOM_ADMIN_PORT:-7001}"  
ARG CUSTOM_ADMIN_SERVER_SSL_PORT="${CUSTOM_ADMIN_SERVER_SSL_PORT:-7002}"  
ARG CUSTOM_MANAGED_SERVER_PORT="${CUSTOM_MANAGED_SERVER_PORT:-8001}"
ARG CUSTOM_MANAGED_SERVER_SSL_PORT="${CUSTOM_MANAGED_SERVER_SSL_PORT:-8002}"
ARG CUSTOM_DEBUG_PORT="${CUSTOM_DEBUG_PORT:-8453}"
ARG CUSTOM_ADMIN_NAME="${CUSTOM_ADMIN_NAME:-admin-server}"
ARG CUSTOM_ADMIN_HOST="${CUSTOM_ADMIN_HOST:-wlsadmin}"
ARG CUSTOM_CLUSTER_NAME="${CUSTOM_CLUSTER_NAME:-DockerCluster}"
ARG CUSTOM_SSL_ENABLED="${CUSTOM_SSL_ENABLED:-false}"
ARG APPLICATION_NAME="${APPLICATION_NAME:-blog-ear}"
ARG APPLICATION_PKG="${APPLICATION_PKG:-archive.zip}"

# WLS Configuration
# ---------------------------
# Define variables
ENV ORACLE_HOME=/u01/oracle \
    PROPERTIES_FILE_DIR="/u01/oracle/properties" \
    SSL_ENABLED="${CUSTOM_SSL_ENABLED}" \
    DOMAIN_NAME="${CUSTOM_DOMAIN_NAME}" \
    DOMAIN_HOME="/u01/oracle/user_projects/domains/${CUSTOM_DOMAIN_NAME}" \
    ADMIN_PORT="${CUSTOM_ADMIN_PORT}" \
    ADMIN_SERVER_SSL_PORT="${CUSTOM_ADMIN_SERVER_SSL_PORT}" \
    ADMIN_NAME="${CUSTOM_ADMIN_NAME}" \
    ADMIN_HOST="${CUSTOM_ADMIN_HOST}" \
    CLUSTER_NAME="${CUSTOM_CLUSTER_NAME}" \
    MANAGED_SERVER_PORT="${CUSTOM_MANAGED_SERVER_PORT}" \
    MANAGED_SERVER_SSL_PORT="${CUSTOM_MANAGED_SERVER_SSL_PORT}" \
    MANAGED_SERV_NAME="${CUSTOM_MANAGED_SERV_NAME}" \
    DEBUG_PORT="8453" \
    PATH=$PATH:/u01/oracle/oracle_common/common/bin:/u01/oracle/wlserver/common/bin:${DOMAIN_HOME}:${DOMAIN_HOME}/bin:/u01/oracle \
    APP_NAME="${APPLICATION_NAME}" \
    APP_FILE="${APPLICATION_NAME}.ear" \
    APP_PKG_FILE="${APPLICATION_PKG}" 

# Add files required to build this image
COPY --chown=oracle:root container-scripts/* /u01/oracle/

COPY --chown=oracle:root $APP_PKG_FILE /u01/oracle/

#Create directory where domain will be written to
USER root
RUN chmod +xw /u01/oracle/*.sh && \
    chmod +xw /u01/oracle/*.py && \
    mkdir -p ${PROPERTIES_FILE_DIR} && \
    mkdir -p $DOMAIN_HOME && \
    chown -R oracle:root $DOMAIN_HOME/.. && \
    chmod -R 775 $DOMAIN_HOME/.. && \
    chown -R oracle:root ${PROPERTIES_FILE_DIR}


COPY --chown=oracle:root properties/docker-build/domain*.properties ${PROPERTIES_FILE_DIR}/

# Configuration of WLS Domain
USER oracle

RUN /u01/oracle/createWLSDomain.sh && \
    chmod -R a+x $DOMAIN_HOME/bin/*.sh  && \
    echo ". $DOMAIN_HOME/bin/setDomainEnv.sh" >> /u01/oracle/.bashrc && \
    rm ${PROPERTIES_FILE_DIR}/*.properties

# Expose ports for admin, managed server, and debug
EXPOSE $ADMIN_PORT $ADMIN_SERVER_SSL_PORT $MANAGED_SERVER_PORT $MANAGED_SERVER_SSL_PORT $DEBUG_PORT

RUN cd /u01/oracle & $JAVA_HOME/bin/jar xf /u01/oracle/$APP_PKG_FILE && \
    /u01/oracle/deployAppToDomain.sh
    
WORKDIR $DOMAIN_HOME

# Define default command to start bash.
CMD ["startAdminServer.sh"]

