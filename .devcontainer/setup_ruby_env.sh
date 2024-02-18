#!/bin/bash

# MySQL sunucusunun IP adresi ve portu
MYSQL_HOST=db
MYSQL_PORT=3306

# MySQL kullanıcı adı ve şifresi
MYSQL_USER=root
MYSQL_PASSWORD=admin

# Veritabanı adı
DATABASE="redmine"
# updated_on değeri şimdi olsun
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# MySQL sunucusuna bağlanma denemesi yapacak fonksiyon
check_mysql_connection() {

    mysqladmin ping -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD &> /dev/null
    
    # Bağlantı başarılıysa
    if [ $? -eq 0 ]; then
        echo "MySQL sunucusuna başarılı bir şekilde bağlandı."
    else
        # MySQL sunucusuna bağlanma denemesi yap
        echo "MySQL sunucusuna bağlanılamadı, bekleniyor..."
        sleep 5
        check_mysql_connection;
    fi
}

echo -e "\n\n----------------------------- CHECK IF MySQL SERVER IS UP ---------------------------------------------"
check_mysql_connection;

check_redmine_isup(){
    # -s parametresi, curl komutunun sessiz modda çalışmasını sağlar, yani çıktıya hiçbir şey yazdırmaz.
    # -o /dev/null, curl çıktısını null aygıtına (yani, çıktıyı atar) yönlendirir.
    # -w '%{http_code}', curl komutunun sadece HTTP durum kodunu (http_code) çıktı olarak yazmasını sağlar.
    # ! işareti, curl komutunun çıktısının başarısız olduğunu (yani, HTTP durum kodunun başarısız olduğunu) kontrol eder.
    # Bu döngü, HTTP isteğinin başarılı olana kadar bekler ve bir saniye aralıklarla tekrarlar (sleep 1).

    while ! curl -s -o /dev/null -w '%{http_code}' http://localhost:3000; do 
        echo "Redmine için PUMA sunucusuna bağlanılamadı, 4sn bekleyip tekrar denenecek..."
        sleep 4; 
    done;
}

echo -e "\n\n----------------------------- CHECK IF REDMINE SERVER IS UP -------------------------------------------"
check_redmine_isup;

# ------------------------------------------------------------------------------------------------------------

# REST Web servisini etkinleştirmek için veritabanında aşağıdaki komutla 
# settings tablosunda name alanı rest_api_enabled olan kaydın value alanı true olarak güncellenir

aktivateRestAPI() {
    # Redmine -> Ayarlar -> API sekmesinde rest_api_enabled ve jsonp_enabled aktif edilecek

    # REST_API name,value değerleri
    REST_API_NAME="rest_api_enabled"
    REST_API_VALUE="1"

    # JSONP name,value değerleri
    JSONP_NAME="jsonp_enabled"
    JSONP_VALUE="1"

    # settings Tablosu normalde boş olur ta ki sayfadan checkbox işaretlendikten sonra kayıtlar oluşuyor.
    # Bu yüzden önce "rest_api_enabled" isimli kayıt var mı kontrolü yapılıyor yoksa kayıt yaratılıyor
    rest_api_count=$(mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -sN -e "SELECT COUNT(*) FROM settings WHERE name='${REST_API_NAME}'")
    if [[ rest_api_count -eq 0 ]]; then
        echo "Inserting new record for ${REST_API_NAME}"
        sql="INSERT INTO settings (name, value, updated_on) VALUES ('${REST_API_NAME}', '${REST_API_VALUE}', '${CURRENT_TIME}');"
        mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"
    fi

    # İkinci kayıtı kontrol etme ve ekleme veya güncelleme
    jsonp_count=$(mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -sN -e "SELECT COUNT(*) FROM settings WHERE name='${JSONP_NAME}'")
    if [[ jsonp_count -eq 0 ]]; then
        echo "Inserting new record for ${JSONP_NAME}"
        sql="INSERT INTO settings (name, value, updated_on) VALUES ('${JSONP_NAME}', '${JSONP_VALUE}', '${CURRENT_TIME}');"
        mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "${sql}"
    fi

    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "UPDATE settings SET value='${REST_API_VALUE}', updated_on='${CURRENT_TIME}' WHERE name='${REST_API_NAME}';"
    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -e "UPDATE settings SET value='${JSONP_VALUE}', updated_on='${CURRENT_TIME}' WHERE name='${JSONP_NAME}';"
}

echo -e "\n\n----------------------------- ACTIVATE REST API WITH JSONP --------------------------------------------"
aktivateRestAPI;

# admin Kullanıcısının şifresini (admin) değiştirmek zorunda kalmayalım 
keepAdminPasswordAdmin() {
    sql="UPDATE users SET must_change_passwd=0 WHERE login='admin';"
    # İlk kez giriş yaparken kullanıcı adı admin ve şifresi admin ancak ilk girişte şifreyi değiştirmem isteniyor
    # bunun önüne geçmek için users tablosunda must_change_passwd alanı admin kullanıcısı için 0 yapılır:
    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -v -e "${sql}"
}

echo -e "\n\n----------------------------- ADMIN PASSWORD WILL BE KEPT AS IT IS ------------------------------------"
keepAdminPasswordAdmin;

# ------------------------------------------------------------------------------------------------------------

createNewProject() {
    # Başlangıç projesini oluşturuyorum
    # Kullanıcı adı ve şifre değişkenleri
    REDMINE_ADMIN_USERNAME="admin"
    REDMINE_ADMIN_PASSWORD="admin"

    # Curl komutunu kullanarak POST isteği gönderme
    curl -vvv \
        -H "Content-Type: application/json" \
        --user "${REDMINE_ADMIN_USERNAME}:${REDMINE_ADMIN_PASSWORD}" \
        -X POST \
        -d '{"project":{"name":"YENI_PROJE_ISMI","identifier":"yeni_proje","description":"Proje açıklaması"}}' \
        http://localhost:3000/projects.json
}

echo -e "\n\n----------------------------- CREATE NEW PROJECT USING BY API -----------------------------------------"
createNewProject;

# ------------------------------------------------------------------------------------------------------------

install_dev_debug_packages(){
    # Redmine docker içinde aşağıdaki compose.yml ile çalışıyor ve içine VS Code ile debug için eklenti kuruyoruz.
    gem install ruby-debug-ide --conservative

    # Kod içinde gezinme, intellisense, yardım pencereleri sağlayacak alt yapı
    gem install solargraph --conservative

    # RUFO : RUby FOrmatter
    gem install rufo --conservative  

    # Ruby Formatter olarak rubocop da kullanılabilir
    # gem install rubocop --conservative

    # Aşağıdaki hata için çalıştırılacak:
    # Missing `secret_key_base` for 'production' environment, set this string with `bin/rails credentials
    # EDITOR="nano --wait" /usr/src/redmine/bin/rails credentials:edit
}

echo -e "\n\n----------------------------- INSTALL RUBY DEBUG & IDE PACKAGES ---------------------------------------"
install_dev_debug_packages;

# ------------------------------------------------------------------------------------------------------------

create_symlink_of_plugin(){
    # Kodu geliştireceğimiz dizin konteynere "/workspace" ismiyle bağlanacak.
    # "/workspace" dizini içinde "./ornek_eklenti" ismindeki klasörü "/usr/src/redmine/plugins" dizininin altına soft link ile bağlıyoruz
    # launch.json içinde `"program": "/usr/src/redmine/bin/rails",` ile kodumuzu başlatabiliyoruz.
    # Farklı isimlerde eklentiler için docker-compose.yml içinde mount edilmi "/workspace/volume/redmine/redmine-plugins" dizini içinde yaratarak kodlayabilirsiniz
    ln -s -v /workspace/ornek_markdown_makro /usr/src/redmine/plugins/ornek_markdown_makro  && echo "link created" || echo "link creation failed"
}

echo -e "\n\n----------------------------- CREATE SYMBOLIC LINK FOR REDMINE PLUGIN ---------------------------------"
create_symlink_of_plugin;

# ------------------------------------------------------------------------------------------------------------

enable_visual_editor_tab_for_switch(){
    sql="UPDATE settings
SET 
    value='--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess\nvisual_editor_mode_switch_tab: \'1\'\n',
    updated_on = '${CURRENT_TIME}'
WHERE 
    name='plugin_redmine_wysiwyg_editor'"

    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -v -e "${sql};"
}

echo -e "\n\n----------------------------- ENABLE VISUAL EDITOR AS TAB ---------------------------------"
enable_visual_editor_tab_for_switch;

# ------------------------------------------------------------------------------------------------------------

enable_visual_editor_module_for_new_project(){
    sql="INSERT INTO enabled_modules (project_id, name)
SELECT id, 'visual_editor'
FROM projects
WHERE identifier='yeni_proje'
AND NOT EXISTS (
    SELECT 1
    FROM enabled_modules
    WHERE project_id = (SELECT id FROM projects WHERE identifier='yeni_proje' LIMIT 1)
    AND name='visual_editor'
)
LIMIT 1;"

    mysql -h $MYSQL_HOST -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${DATABASE}" -v -e "${sql};"
}

echo -e "\n\n----------------------------- ENABLE Visual Editor MODULE FOR NEW PROJECT ---------------------------------"
enable_visual_editor_module_for_new_project;

# ------------------------------------------------------------------------------------------------------------