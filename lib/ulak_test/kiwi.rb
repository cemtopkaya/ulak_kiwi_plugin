# encoding: UTF-8

module UlakTest
  module Helper
    def self.convert_to_meaningful_duration(saniye)
      if !saniye
        return ""
      end

      dakika = (saniye / 60).floor
      saniye = saniye % 60  # Kalan saniyeleri al

      saat = (dakika / 60).floor
      dakika = dakika % 60  # Kalan dakikaları al

      gun = (saat / 24).floor
      saat = saat % 24  # Kalan saatleri al

      yil = (gun / 365).floor
      gun = gun % 365  # Kalan günleri al

      result = []

      result << "#{yil} yıl" if yil >= 1
      result << "#{gun} gün" if gun >= 1
      result << "#{saat} saat" if saat >= 1
      result << "#{dakika} dakika" if dakika >= 1
      result << "#{saniye} saniye"

      result.join(" ")
    end
  end

  module Kiwi

    # Test senaryolarının durumları
    # "BOŞTA"        : 1
    # "KOŞUYOR"      : 2
    # "DURAKLATILDI" : 3
    # "GEÇTİ"        : 4
    # "BAŞARISIZ"    : 5
    # "BLOKE"        : 6
    # "HATALI"       : 7
    # "VAZGEÇİLDİ"   : 8

    @headers = {
      # "Cookie" => cookie, # Cookie bilgisi
      "Content-Type" => "application/json", # İstenilen gövde türü
    }

    def self.create_http(_url)
      Rails.logger.debug(">>>> UlakTest::Kiwi.create_http() metodu çalıştırıldı")
      url = URI.parse(_url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true # Eğer HTTPS kullanılıyorsa bu satırı eklemeliyiz
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http
    end

    def self.is_kiwi_accessable
      Rails.logger.debug(">>>> UlakTest::Kiwi.is_kiwi_accessable() metodu çalıştırıldı")
      begin
        login()
        return {
                 is_accessable: true,
                 message: "Kiwi server is accessable",
               }
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
        raise e
        return {
                 is_accessable: false,
                 message: "Kiwi server is not accessable! Error:  #{e.message}",
               }
      end
    end

    def self.make_request_body(method = nil, params = {})
      Rails.logger.debug(">>>> UlakTest::Kiwi.make_request_body() metodu çalıştırıldı")
      body = {
        jsonrpc: "2.0",
        method: method,
        id: "jsonrpc",
      }

      body = body.merge({ :params => params }) unless params.empty?

      body
    end

    def self.login
      Rails.logger.debug(">>>> UlakTest::Kiwi.login() metodu çalıştırıldı")
      begin
        @headers.delete(:Cookie)
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Auth.login", {
          :username => rest.fetch(:username),
          :password => rest.fetch(:password),
        })

        # HTTP isteği oluşturma
        url = URI.parse(rest.fetch(:url))
        http = Net::HTTP.new(url.host, url.port)
        http.set_debug_output($stdout)
        http.use_ssl = true # Eğer HTTPS kullanılıyorsa bu satırı eklemeliyiz
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        # Yanıtı alıp işleme
        if response.is_a?(Net::HTTPSuccess)
          Rails.logger.debug("İstek başarılı. Yanıt: #{response.body}")
        else
          Rails.logger.warn("İstek başarısız. Hata kodu: #{response.code}, Hata mesajı: #{response.message}")
        end
      rescue StandardError => e
        Rails.logger.error("----- Error occurred: #{e.message}")
        raise e
      end
      @headers[:Cookie] = "sessionid=#{JSON.parse(response.body)["result"]}"
      JSON.parse(response.body)["result"]
    end

    def self.logout
      Rails.logger.debug(">>>> UlakTest::Kiwi.logout() metodu çalıştırıldı")
      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestCase.filter", [{ :category__product => "3" }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        Rails.logger.info(">>>> Cevap istisnasız geldi: #{response}")
      rescue StandardError => e
        Rails.logger.error("----- Error occurred: #{e.message}")
      end
    end

    def self.fetch_product(id = 3)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_product() metodu çalıştırıldı")
      login()
      result = nil

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Product.filter", [{ "id": id }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end
      result
    end

    def self.fetch_products()
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_products() metodu çalıştırıldı")
      login()
      result = nil

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Product.filter", [])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        if response.is_a?(Net::HTTPSuccess)
          Rails.logger.debug("İstek başarılı. Yanıt: #{response.body}")
          result = JSON.parse(response.body)["result"]
        else
          Rails.logger.debug("İstek başarısız. Hata kodu: #{response.code}, Hata mesajı: #{response.message}")
        end
      rescue StandardError => e
        Rails.logger.error("----- Error occurred: #{e.message}")
      ensure
        logout()
      end

      result
    end

    def self.fetch_product_categories(product_id = 3)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_product_categories() metodu çalıştırıldı")
      login()
      result = nil

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Category.filter", [{ product: product_id }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    def self.fetch_test_cases(category_product = "3")
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_test_cases() metodu çalıştırıldı")
      login()
      result = nil

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestCase.filter", [{ :category__product => category_product }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    # ID değerleri verilen test durumlarının (test case) koşturulduğu
    # ve sonuçlarında koşunun durumunu dönecek fonksiyon.

    # @param [Array<Integer>] case_ids Test durumu kimlik numaralarının bir dizisi
    # @return [Array] Test sürdürmelerinin bir dizisi
    def self.fetch_testexecution_by_case_id_in(case_ids)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_testexecution_by_case_id_in() metodu çalıştırıldı")
      unless case_ids.is_a?(Array)
        raise ArgumentError, "case_ids parameter must be an array"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestExecution.filter", [{ :case__id__in => case_ids }])
        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
        result
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    # ID değerleri verilen test durumlarının (test case) koşturulduğu
    # ve sonuçlarında koşunun durumunu dönecek fonksiyon.

    # @param [Array<Integer>] case_ids Test durumu kimlik numaralarının bir dizisi
    # @return [Array] Test sürdürmelerinin bir dizisi
    def self.fetch_testexecution_by_run__id_in_case__id_in(run_ids, case_ids)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_testexecution_by_run__id_in_case__id_in() metodu çalıştırıldı")
      unless run_ids.is_a?(Array)
        raise ArgumentError, "run_ids parameter must be an array"
      end

      unless case_ids.is_a?(Array)
        raise ArgumentError, "case_ids parameter must be an array"
      end

      if run_ids.empty? || case_ids.empty?
        Rails.logger.debug("run_ids or case_ids is empty")
        return []
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestExecution.filter", [{ :case__id__in => case_ids, :run__id__in => run_ids }])
        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
        result
      rescue StandardError => e
        Rails.logger.error("----- Error occurred: #{e.message}")
      ensure
        logout()
      end

      result
    end

    # RUN ID değerleri içinde etiketleri arar

    # @param [Array<Integer>] Test koşumlarının ID değerlerini içeren dizi
    # @param [String] Etiket adı içerisinde paket_adı=versiyonu değeri gelecek
    # @return [String] ???
    def self.fetch_tags_by_run_ids(run_ids, tag_name)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_tags_by_run_ids() metodu çalıştırıldı")
      unless run_ids.is_a?(Array)
        raise ArgumentError, "run_ids parameter must be an array"
      end

      if tag_name.empty?
        raise ArgumentError, "tag_name parameter must be a string"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Tag.filter", [{ :run__id__in => run_ids, :name => tag_name }])
        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    # RUN ID değerleri içinde etiketleri arar
    # @param [String] tag_name ile etiket adı gelir
    # @param [String] Etiket adı içerisinde paket_adı=versiyonu değeri gelecek
    # @return [String]
    def self.fetch_tags_by_tag_name(tag_name)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_tags_by_tag_name() metodu çalıştırıldı")
      if tag_name.empty?
        raise ArgumentError, "tag_name parameter must be a string"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Tag.filter", [{ :name => tag_name }])
        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    def self.fetch_tags_by_name__in(tag_names)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_tags_by_name__in() metodu çalıştırıldı")
      unless tag_names.is_a?(Array)
        raise ArgumentError, "tag_names parameter must be an array"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Tag.filter", [{ :name__in => tag_names }])
        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    # Etiket isimlerinde "tag_names" dizisindeki isimler geçecek olsun ve
    # Test Koşularında bu etiketler kullanılmış (is_run_null:false) veya kullanılmamış (is_run_null:true) olsun
    # @param [String[]] tag_names dizisinde etiket adları olacak
    # @param [boolean] is_run_null Etiketi "Test Koşularında" kullanılmış veya kullanılmamış olarak seç
    # @return [String[]]
    def self.fetch_tags_by_name__in_and_run__isnull(tag_names, is_run_null = false)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_tags_by_name__in_and_run__isnull() metodu çalıştırıldı")
      unless tag_names.is_a?(Array)
        raise ArgumentError, "tag_names parameter must be an array"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("Tag.filter", [{ :name__in => tag_names, :run__isnull => is_run_null }])
        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    # Case ID değerleri için yapılan testler
    # @param [Array<Integer>] case_ids Test durumu kimlik numaralarının bir dizisi
    # @return [Array] Test sürdürmelerinin bir dizisi
    def self.fetch_runs_by_id__in(run_ids)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_runs_by_id__in() metodu çalıştırıldı")
      unless run_ids.is_a?(Array)
        raise ArgumentError, "run_ids parameter must be an array"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestRun.filter", [{ :id__in => run_ids }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    # PLAN ID değerleri için yapılan test koşuları
    # @param [Array<Integer>] case_ids Test durumu kimlik numaralarının bir dizisi
    # @return [Array] Test sürdürmelerinin bir dizisi
    def self.fetch_testrun_by_id__in_plan__in(run_ids, plan_ids)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_testrun_by_id__in_plan__in() metodu çalıştırıldı")
      unless plan_ids.is_a?(Array) and run_ids.is_a?(Array)
        raise ArgumentError, "plan_ids, run_ids parameters must be an array"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestRun.filter", [{ :id__in => run_ids, :plan__in => plan_ids }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    def self.fetch_test_plans()
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_test_plans() metodu çalıştırıldı")
      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestPlan.filter", [{ "is_active": true }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    def self.fetch_test_plan_by_id(plan_id)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_test_plan_by_id() metodu çalıştırıldı")
      unless plan_id
        raise ArgumentError, "plan_id parameter can't be nil and must be greater than 0"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestPlan.filter", [{ "id": plan_id }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    def self.fetch_test_cases_by_plan_ids(plan_ids)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_test_cases_by_plan_ids() metodu çalıştırıldı")
      unless plan_ids
        raise ArgumentError, "plan_ids parameter can't be nil and must be greater than 0"
      end

      unless plan_ids.is_a?(Array)
        raise ArgumentError, "plan_ids parameter must be an array"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestCase.filter", [{ "plan__id__in": plan_ids }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end

    def self.fetch_test_cases_by_plan_id(plan_id)
      Rails.logger.debug(">>>> UlakTest::Kiwi.fetch_test_cases_by_plan_id() metodu çalıştırıldı")
      unless plan_id
        raise ArgumentError, "plan_id parameter can't be nil and must be greater than 0"
      end

      result = nil
      login()

      begin
        rest = UlakTest::PluginSetting.get_kiwi_settings()
        body = make_request_body("TestCase.filter", [{ "plan__id": plan_id }])

        # HTTP isteği oluşturma
        url = rest.fetch(:url)
        http = create_http(url)

        # POST isteği yapma
        response = http.post(url, body.to_json, @headers)
        result = JSON.parse(response.body)["result"]
      rescue StandardError => e
        puts "----- Error occurred: #{e.message}"
      ensure
        logout()
      end

      result
    end
  end
end
