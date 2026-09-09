FROM jenkins/jenkins:lts-jdk21

USER root

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# JCasC loads every *.yaml in this dir (mounted from the repo).
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc

# Optional HTTPS for the controller, configured via env at run time
# (e.g. JENKINS_OPTS="--httpsPort=8443 --httpsKeyStore=... --httpsKeyStorePassword=...").
# Leave empty to serve plain HTTP on 8080.
ENV JENKINS_OPTS=""

USER jenkins
