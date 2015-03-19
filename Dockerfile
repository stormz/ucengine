FROM debian:stable
MAINTAINER Laurent Arnoud <laurent@spkdev.net>

ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_PRIORITY critical
ENV DEBCONF_NOWARNINGS yes

ENV UCENGINE_USER ucengine
ENV UCENGINE_ROOT /code
ENV UCENGINE_REL_PATH ${UCENGINE_ROOT}/rel/ucengine
ENV UCENGINE_PKGS openssl erlang erlang-yaws
ENV UCENGINE_BUILD_PKGS make git

RUN groupadd -r ${UCENGINE_USER} \
    && useradd -r -m \
    --home-dir ${UCENGINE_ROOT} \
    -s /usr/sbin/nologin \
    -g ${UCENGINE_USER} ${UCENGINE_USER}

RUN apt-get update && apt-get -y upgrade \
    && apt-get install -y ${UCENGINE_PKGS} ${UCENGINE_BUILD_PKGS} --no-install-recommends

ENV ERL_LIBS /usr/lib/yaws/

WORKDIR ${UCENGINE_ROOT}
COPY . ${UCENGINE_ROOT}
RUN chown -R ${UCENGINE_USER}:${UCENGINE_USER} ${UCENGINE_ROOT}

# Install as user
USER ${UCENGINE_USER}

RUN make rel

USER root

# Cleanup
RUN apt-get purge -y \
    && apt-get purge -y ${UCENGINE_BUILD_PKGS} \
    && apt-get autoremove -y \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR ${UCENGINE_REL_PATH}

VOLUME ["${UCENGINE_REL_PATH}/etc"]

EXPOSE 5280

USER ${UCENGINE_USER}

CMD ["./bin/ucengine", "run"]
