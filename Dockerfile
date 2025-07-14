FROM ubuntu:22.04

# arg
ARG DEBIAN_FRONTEND=noninteractive

# env
ENV TZ=Asia/Seoul \
    SERVER_DOMAIN=testmyeong.co.kr\
    WEB_ADDR1=apache1 \ 
    WEB_ADDR2=apache2 \
    WEB_N_LB_PORT=80\
    INLB_ADDR=nginx2 \
    WAS_ADDR1=tomcat1 \
    WAS_ADDR2=tomcat2 \
    DB_ADDR=mysql1 \
    DB_USERNAME=user \
    DB_PASSWORD=0710

# install systemctl and etc package
RUN apt update \
    && apt install -qq -y init systemd \
    && apt install -qq -y build-essential \
    && apt install -qq -y tzdata locales gettext\
    && apt install -qq -y openssh-server \
    && apt install -qq -y vim curl net-tools\
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/{apt, dpkg, cache, log}

# ect work
RUN systemctl enable ssh
RUN useradd -m user && echo 'user:0710' | chpasswd
RUN locale-gen ko_KR.UTF-8
ENV LC_ALL=ko_KR.UTF-8
WORKDIR /root

EXPOSE 22

# run systemctl
CMD ["/sbin/init"]