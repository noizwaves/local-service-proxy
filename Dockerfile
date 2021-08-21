FROM alpine as build

RUN apk add build-base automake autoconf curl
RUN curl -L -o /tmp/source.tgz https://github.com/troglobit/redir/archive/refs/tags/v3.3.tar.gz && \
    mkdir /source && \
    cd /source && \
    tar --strip-components 1 -zxvf /tmp/source.tgz && \
    ./autogen.sh && \
    ./configure && \
    make -j5 && \
    make install-strip && \
    cd / && \
    rm -rf /source /tmp/source.tgz

FROM alpine as release
RUN apk add curl jq
COPY --from=build /usr/local/bin/redir /usr/local/bin/
COPY run.sh /

CMD /run.sh
