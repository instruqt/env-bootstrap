FROM alpine
VOLUME /opt/instruqt/bootstrap
ENTRYPOINT ["cp", "-R", "/bootstrap", "/opt/instruqt/"]
ADD bootstrap /bootstrap
