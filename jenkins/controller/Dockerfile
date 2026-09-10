FROM jenkins/jenkins:lts-jdk21

USER root

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# JCasC loads every *.yaml in this dir (mounted from the repo).
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc

# Mark the install as already-run so Jenkins skips the setup wizard/install-state
# logic entirely (JCasC provides security + admin instead of the wizard). The
# base image copies /usr/share/jenkins/ref/* into a fresh $JENKINS_HOME.
RUN echo 2.568.3 > /usr/share/jenkins/ref/jenkins.install.InstallUtil.lastExecVersion
# Force the install state to RUNNING: the install-state check runs BEFORE JCasC
# configures the security realm, so on a fresh boot it otherwise falls into
# InitialSecuritySetup -> SetupWizard.init() which downloads the update center
# and can block boot forever on a slow network.
RUN echo RUNNING > /usr/share/jenkins/ref/installState

# Optional HTTPS for the controller, configured via env at run time
# (e.g. JENKINS_OPTS="--httpsPort=8443 --httpsKeyStore=... --httpsKeyStorePassword=...").
# Leave empty to serve plain HTTP on 8080.
ENV JENKINS_OPTS=""

USER jenkins
