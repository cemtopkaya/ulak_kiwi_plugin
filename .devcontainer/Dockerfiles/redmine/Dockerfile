FROM redmine:5.0.2

RUN apt update && apt install \
    graphviz vim unzip iputils-ping htop net-tools \
    # DEBUG işlemleri için gerekecek \
    ubuntu-dev-tools \    
    # libreoffice yüklenince dmsf inline editing yapabilecek \
    libreoffice liblibreoffice-java \
    # dms eklentisinin belgeleri endekleme araclari (indexing tools): \
    xapian-omega ruby-xapian libxapian-dev poppler-utils antiword  unzip catdoc libwpd-tools \
    libwps-tools gzip unrtf catdvi djview djview3 uuid uuid-dev xz-utils libemail-outlook-message-perl \
    # Redmine konteynerinden veritabanında değişiklikler yapmak için mysql istemcisini kuruyoruz. \
    default-mysql-client \
    # ağ işlemleri için gerekir \
    netcat \
    # Supervisor'u yükle \
    supervisor \
    -y 

# /home/redmine/repoScript.sh script'inin cronjob olarak çalışması için gerekli.
# RUN apt install -y cron # buradaki isi cron konteyneri yapacak


WORKDIR /usr/src/redmine

# Supervisor konfigürasyon dosyasını kopyala
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Supervisor'u başlat
ENTRYPOINT []
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
