FROM ubuntu:jammy

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y apt-transport-https ca-certificates curl gnupg

# docker-ce-cli yuklemek icin repo ayarlari
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu xenial stable" > /etc/apt/sources.list.d/docker.list

RUN apt-get update

# docker komutlarini calistirmak icin
RUN apt-get install -y docker-ce-cli

# mysqldump ile baska mysql veritabanini yedekler
RUN apt-get install -y mysql-client

# cron ile otomatik tetiklenecek isler icin
RUN apt-get install -y cron

# Mail ve Zip kütüphanesi
RUN apt-get install -y zip libio-socket-ssl-perl libnet-ssleay-perl sendemail

# Fluentd Kurulumu
RUN apt install gcc make ruby ruby-dev -y
RUN gem install fluentd
RUN gem install fluent-plugin-grafana-loki

# Supervisor kurulumu
RUN apt install -y supervisor
