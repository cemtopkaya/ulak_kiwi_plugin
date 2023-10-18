# encoding: UTF-8

class IssueTestController < ApplicationController
  def remove_test_from_issue
    issue_id = params[:issue_id]
    test_id = params[:test_id]

    self.remove_test_from_issue(issue_id, test_id)
  end

  def self.remove_test_from_issue(issue_id, test_plan_id)
    issue = Issue.find_by(id: issue_id)
    return render json: { error: "Issue not found" }, status: :not_found unless issue

    test_plan = IssueTestPlan.find_by(issue_id: issue_id, test_plan_id: test_plan_id)
    return render json: { error: "The test plan bound to the issue could not be found" }, status: :not_found unless test_plan

    test_plan.destroy
    return render json: { message: "#{test_plan.name} named Test Plan removed from the issue successfully" }, status: :ok
  end

  def add_test_to_issue
    issue_id = params[:issue_id]
    test_plan_id = params[:test_plan_id]
    Rails.logger.debug("Test Plan ID: #{test_plan_id}")
    test_plan = UlakTest::Kiwi.fetch_test_plan_by_id(test_plan_id).first
    Rails.logger.debug("#{test_plan_id} ID'li Test Planı : #{test_plan}")

    if test_plans.nil?
      raise StandardError, "#{test_plan_id} Değerli Test Planı Kiwi sunucusunda bulunamadı!"
    end

    self.add_test_to_issue(issue_id, test_plan["id"], test_plan["name"])
  end

  def self.add_test_to_issue(issue_id, test_plan_id)
    issue = Issue.find(issue_id)
    test_plan = UlakTest::Kiwi.fetch_test_plan_by_id(test_plan_id).first

    # Use the "IssueTest" model to add the relationship
    issue_test_plan = IssueTestPlan.find_or_create_by(issue_id: issue_id, test_plan_id: test_plan_id, name: test_plan["name"])

    # Return a JSON response with the success message
    return render json: {
                    success: true,
                    message: "#{issue.id} Numaralı görev için #{issue_test_plan.id} numaralı test eklendi.",
                  }
  end

  def get_issue_tests
    issue_id = params[:issue_id]
    issue = Issue.find(issue_id)
    return render json: { error: "Issue not found" }, status: :not_found unless issue

    # Check if the user is authorized to view the plugin.
    unless User.current.allowed_to?(:get_issue_tests, issue.project)
      # The user is not authorized to view the plugin.
      Rails.logger.info(">>> #{User.current.login} does not have permission to get issue's tests will not be fetched... !!!! <<<<")
      return
    end

    tests = issue.tests.select(:id, :summary)

    # "tests" dizisini istenen formata dönüştürmek için map kullanıyoruz
    formatted_tests = tests.map { |test| { id: test.id, summary: test.summary } }

    Rails.logger.info(">>>> tests: #{tests}")
    render json: formatted_tests, status: :ok
  end

  def get_tests
    issue_id = params[:issue_id]
    q = params[:q]

    if q
      tests = Test
      # .joins(:issue_tests)
      # .where(issue_tests: { issue_id: issue_id })
        .where("tests.summary LIKE ?", "%#{q}%")
        .select(:id, :summary) # Sadece testin id ve summary alanlarını seçiyoruz
    else
      tests = Test
      # .joins(:issue_tests)
      # .where(issue_tests: { issue_id: issue_id })
        .where("tests.summary LIKE ?", "%#{q}%")
        .select(:id, :summary) # Sadece testin id ve summary alanlarını seçiyoruz
    end
    puts tests.to_sql

    render json: tests
  end

  # Test senaryolarının execute edilen koşuları bulur ve bu koşuların etiketlerinde geçen
  # paket_adı=versiyon değerini arar. Bulduklarını paketin olduğu test sonuçları olarak görüntüler.

  def view_tag_runs
    tag = params[:tag]
    changeset_id = params[:changeset_id]
    issue_id = params[:issue_id]

    @issue = Issue.find(issue_id)

    # Check if the user is authorized to view the plugin.
    unless User.current.allowed_to?(:view_tag_runs, @issue.project)
      # The user is not authorized to view the plugin.
      Rails.logger.info(">>> #{User.current.login} does not have permission to view the Issue Edit for Kiwi Tests field, so this tab will not be created... !!!! <<<<")
      @error_message = "Kullanıcının bu bilgiye erişme yetkisi yok!"
      html_content = render_to_string(
        template: "errors/401",
        layout: false,
      )
      return render html: html_content
    end

    # # Eğer kiwi erişilemezse hata dön!
    # result = UlakTest::Kiwi.is_kiwi_accessable()
    # if !result[:is_accessable]
    #   @error_message = "Kiwi is not accessible...!"
    #   render "errors/socket_error", layout: false
    #   # render json: result
    #   return
    # end

    @cs = @issue.changesets.find_by_id(changeset_id)

    begin
      # issue ile ilişkili Test Plan'ını çek
      # Test Plan'ına bağlı Test Case'leri çek
      #
      # Seçilen "git tag" açıklamasından (tag description) artifact'leri çek
      # Artifactlerin geçtiği Test Run'ları bul
      #
      #
      @test_plan_ids = IssueTestPlan.where(issue_id: issue_id).pluck(:test_plan_id)
      key_plan_cases_id_summary = "key_issue:#{issue_id}_test_plan_ids_#{@test_plan_ids.join(",")}_test_cases_id_summary"
      test_cases_id_summary_automated = session[key_plan_cases_id_summary]
      if !test_cases_id_summary_automated
        test_cases = UlakTest::Kiwi.fetch_test_cases_by_plan_ids(test_plan_ids)
        test_cases_id_summary_automated = test_cases.map { |tc| { "id" => tc["id"], "summary" => tc["summary"] } }
        session[key_plan_cases_id_summary] = test_cases_id_summary_automated
      end
      # @tests = UlakTest::Kiwi.fetch_test_cases_by_plan_ids(@test_plan_ids)
      @test_case_ids = test_cases_id_summary_automated.pluck("id")

      @artifacts = UlakTest::Git.tag_artifacts(@cs.repository.url, tag)
      if @artifacts.empty?
        @tag_description = UlakTest::Git.tag_description(@cs.repository.url, tag)
      end
      @artifact_kiwi_tags = @artifacts.map { |a| a.end_with?(".deb") ? "#{a.split("_")[0]}=#{a.split("_")[1]}" : a }

      # tag -> runs
      # Artifact'lerin kullanıldığı Test Koşularını bul
      # @kiwi_tags = UlakTest::Kiwi.fetch_tags_by_name__in(@edited_artifacts)

      # Bu issue için yapılan kod değişikliklerinden çıkartılan artifact'ler ile etiketlenmiş Test Koşularını getir
      @kiwi_run_tags = UlakTest::Kiwi.fetch_tags_by_name__in_and_run__isnull(@artifact_kiwi_tags, false)

      # Bu issue için yapılan kod değişikliklerinden çıkartılan artifact'ler ile etiketlenmiş Test Run ID değerleri
      @kiwi_run_ids = @kiwi_run_tags.pluck("run")

      # Test Senaryolarının koşulduğu Test Koşularının sonuçlarını, Test Execution'ları çekerek gösterime hazırla
      # Test Plan -> Test Run -> Her Test Case ID için -> Test Executions (run_id_in & case_id_in)
      @kiwi_executions = UlakTest::Kiwi.fetch_testexecution_by_run__id_in_case__id_in(@kiwi_run_ids, @test_case_ids)

      # Kodun çıktısı için yapılan Test Koşularının ayrıntılarını, ekranda test koşusunun hangi test planı için yapıldığını göstermek için çek ()
      @kiwi_runs = UlakTest::Kiwi.fetch_runs_by_id__in(@kiwi_run_ids)

      # plan: [
      #   {
      #     run : {
      #         executions: [
      #           tags : []
      #         ]
      #     },
      #     ...
      #   ]
      # }
      @kiwi_runs.each do |run|
        run["tags"] = []
        run["executions"] = []
      end

      @kiwi_executions.each do |execution|
        execution_run_id = execution["run"]
        run = @kiwi_runs.find { |r| r["id"] == execution_run_id }
        run["tags"] = @kiwi_run_tags.select { |t| t["run"] == execution_run_id }.map { |tag| tag["name"] }
        run["executions"].push(execution)
      end

      # run_ids = @kiwi_runs.pluck("run")
      # sonuc["plan_#{plan_id}"] = @kiwi_runs.select { |item| item[:plan] == plan_id }.map { |item| item[:name] }

      # sonuc = {}
      # @kiwi_runs.each do |plan|
      #   plan_id = plan["id"]
      #   sonuc["plan_#{plan_id}"] = @kiwi_runs.select { |run| run["plan"] == plan_id }
      # end

      # @edited_artifacts.each do |package|
      # end

      html_content = render_to_string(
        template: "templates/_tab_test_results.html.erb",
        # layout: false ile tüm Redmine sayfasının derlenMEmesini sağlarız
        layout: false,
        locals: {
          issue_id: issue_id,
        },
      )
      render html: html_content
    rescue SocketError => e
      @error_message = "#{l(:text_exception_name)}: #{e.message}"
      render "errors/socket_error", layout: false
    rescue StandardError => e
      puts "----- Error occurred: #{e.message}"
      @error_message = "#{l(:text_exception_name)}: #{e.message}"
      render "errors/error", layout: false
    end
  end

  def view_issue_test_results
    issue_id = params[:issue_id]
    issue = Issue.find(issue_id)

    # Check if the user is authorized to view the plugin.
    unless User.current.allowed_to?(:view_issue_test_results, issue.project)
      # The user is not authorized to view the plugin.
      Rails.logger.info(">>> #{User.current.login} does not have permission to view the Issue Edit for Kiwi Tests field, so this tab will not be created... !!!! <<<<")
      @error_message = "Kullanıcının bu bilgiye erişme yetkisi yok!"
      html_content = render_to_string(
        template: "errors/401",
        layout: false,
      )
      return render html: html_content
    end

    test_plan_ids = IssueTestPlan.where(issue_id: issue_id).pluck(:test_plan_id)
    if !test_plan_ids
      Rails.logger.info(">>> Redmine görevine ait bir test planı bulunamadı! <<<<")
      return
    end

    # key_plan_cases = "key_issue:#{issue_id}_test_plan_ids_#{test_plan_ids.join(",")}_test_cases"
    key_plan_cases_id_summary = "key_issue:#{issue_id}_test_plan_ids_#{test_plan_ids.join(",")}_test_cases_id_summary"
    test_cases_id_summary_automated = session[key_plan_cases_id_summary]
    if !test_cases_id_summary_automated
      test_cases = UlakTest::Kiwi.fetch_test_cases_by_plan_ids(test_plan_ids)
      test_cases_id_summary_automated = test_cases.map { |tc| { "id" => tc["id"], "summary" => tc["summary"], "is_automated" => tc["is_automated"] } }
      session[key_plan_cases_id_summary] = test_cases_id_summary_automated
    end

    #commit_with_artifacts = UlakTest::Git.commit_tags(issue.changesets)
    changeset_ids = issue.changesets.pluck("id")

    # Bu veriyi session içinde tutunca CookiesOverflow hatası alıyorum çünkü
    # session verisini cookie içine yazmaya çalışıyor ve bu da hataya neden oluyor.
    # çözüm için https://www.redmineup.com/pages/help/getting-started/how-to-fix-cookiesoverflow-error
    key_changeset_artifacts = "key_issue:#{issue_id}_chanageset_ids_#{changeset_ids.join(",")}_artifacts"
    commit_with_artifacts = session[key_changeset_artifacts]
    if !commit_with_artifacts
      commit_with_artifacts = UlakTest::Git.findTagsOfCommits(issue.changesets)
      # session[key_changeset_artifacts] = commit_with_artifacts
    end

    html_content = render_to_string(
      template: "templates/_tab_content_issue_test_results.html.erb",
      # layout: false ile tüm Redmine sayfasının derlenMEmesini sağlarız
      layout: false,
      locals: {
        commit_with_artifacts: commit_with_artifacts,
        issue: issue,
        issue_id: issue_id,
        tests: test_cases_id_summary_automated,
      },
    )
    render html: html_content
  end
end
