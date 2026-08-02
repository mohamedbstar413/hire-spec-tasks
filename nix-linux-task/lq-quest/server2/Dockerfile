FROM linux-lab-image:systemd

ENV DEBIAN_FRONTEND=noninteractive
USER root
# ---- Build-time parameters (override with --build-arg) ----------------
ARG DETECTIVE_USER=watson
ARG SERVER2_PASS=hunter2
ARG SSH_PORT=2222
ARG SUBDOMAIN=vault
ARG DOMAIN=chucknorris.quest.local

RUN apt-get update && apt-get install -y \
    openssh-server \
    nginx \
    vim \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ---- Task 6: account the student ssh's into (matches Task 4 + 5) -----
RUN useradd -m -s /bin/bash "${DETECTIVE_USER}" \
    && echo "${DETECTIVE_USER}:${SERVER2_PASS}" | chpasswd \
    && usermod -aG sudo "${DETECTIVE_USER}"
RUN echo "watson ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/watson && chmod 0440 /etc/sudoers.d/watson

# ---- sshd on the custom port from "the email" -------------------------
RUN sed -i "s/^#\?Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && mkdir -p /run/sshd

# ---- Task 7: nginx vhost left incomplete on purpose --------------------
# server_name / root are placeholders the student must fill in.
COPY files/web_page.conf /etc/nginx/conf.d/web_page.conf

# ---- Task 8: the reward page -------------------------------------------
RUN mkdir -p /var/www/web_page
COPY files/index.html /var/www/web_page/index.html
RUN chown -R www-data:www-data /var/www/web_page

# nginx.conf ships with a default "listen 80 default_server" site that
# would otherwise shadow web_page.conf - disable it so the student's own
# config is what actually needs to be correct.
RUN rm -f /etc/nginx/sites-enabled/default

# ---- systemd: bring back sshd; leave nginx OFF (Task 7 starts it) -----
RUN mkdir -p /etc/systemd/system/multi-user.target.wants \
    && ln -sf /lib/systemd/system/ssh.service \
       /etc/systemd/system/multi-user.target.wants/ssh.service
RUN sed -i 's/.*pam_nologin.so/# &/' /etc/pam.d/sshd
RUN chmod -R o+rwx /etc/nginx
RUN chmod -R o+rwx /var/www
# `sudo systemctl start nginx` will prompt for their own password -
# matching the "Note: you will need to use sudo" instruction in Task 7.

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
