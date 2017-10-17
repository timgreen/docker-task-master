FROM docker:17.09.0-ce
MAINTAINER Tim Green "iamtimgreen@gmail.com"

RUN apk add --no-cache \
    bash \
    coreutils \
    git \
    openssh-client \
    curl \
    jq \
    python \
    py-pip \
    tmux \
    ncurses \
    inotify-tools \
    procps \
  && pip install yq

# papertrail
ARG papertrail=true
RUN if [[ $papertrail == true ]]; then \
      curl -L https://github.com/papertrail/remote_syslog2/releases/download/v0.20-beta2/remote_syslog_linux_amd64.tar.gz \
           -o remote_syslog.tar.gz \
      && tar xzf remote_syslog.tar.gz \
      && mv remote_syslog/remote_syslog /usr/bin/ \
      && rm -fr remote_syslog remote_syslog.tar.gz \
      ; \
    fi

# graph-easy
ARG graph_easy=true
RUN if [[ $graph_easy == true ]]; then \
      apk add --no-cache perl perl-utils make \
      && cpan Graph::Easy \
      ; \
    fi

ADD entry-point.sh /entry-point.sh
ADD status-manager.sh /status-manager.sh
RUN chmod a+rx /entry-point.sh /status-manager.sh \
    && ln -s /entry-point.sh /usr/bin/s

ADD .terminfo/ /root/.terminfo
ADD .tmux.conf /root/.tmux.conf

ENTRYPOINT ["/entry-point.sh"]
CMD ["daemon"]
