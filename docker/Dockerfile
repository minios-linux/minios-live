
FROM ubuntu:rolling
COPY Dockerfile.0@install.sh /opt/install.sh
RUN chmod +x /opt/install.sh
RUN /opt/install.sh
RUN rm /opt/install.sh
VOLUME /build
WORKDIR /build/minios-live
CMD ["/build/minios-live/install", "-"]