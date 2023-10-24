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

  def fetch_artifact_run_tags(cs, tag_name)
    artifacts = UlakTest::Git.tag_artifacts(cs.repository.url, tag_name)
    if artifacts.empty?
      tag_description = UlakTest::Git.tag_description(cs.repository.url, tag_name)
    end
    artifact_kiwi_tags = artifacts.map { |a| a.end_with?(".deb") ? "#{a.split("_")[0]}=#{a.split("_")[1]}" : a }

    # tag -> runs
    # Artifact'lerin kullanıldığı Test Koşularını bul
    # Bu issue için yapılan kod değişikliklerinden çıkartılan artifact'ler ile etiketlenmiş Test Koşularını getir
    kiwi_run_tags = UlakTest::Kiwi.fetch_tags_by_name__in_and_run__isnull(artifact_kiwi_tags, false)

    return { "artifact_kiwi_tags": artifact_kiwi_tags, "kiwi_run_tags": kiwi_run_tags }
  end

  # Test senaryolarının execute edilen koşuları bulur ve bu koşuların etiketlerinde geçen
  # paket_adı=versiyon değerini arar. Bulduklarını paketin olduğu test sonuçları olarak görüntüler.
  def view_changeset_tag_artifacts_runs
    tag_name = params[:tag]
    if tag_name.empty?
      return
    end
    changeset_id = params[:changeset_id]
    issue_id = params[:issue_id]

    @issue = Issue.find(issue_id)

    # Check if the user is authorized to view the plugin.
    unless User.current.allowed_to?(:view_changeset_tag_artifacts_runs, @issue.project)
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

    begin
      @cs = @issue.changesets.find_by_id(changeset_id)

      # issue ile ilişkili Test Plan'ını çek
      # Test Plan'ına bağlı Test Case'leri çek
      #
      # Seçilen "git tag" açıklamasından (tag description) artifact'leri çek
      # Artifactlerin geçtiği Test Run'ları bul
      #
      #
      @test_plan_ids = IssueTestPlan.where(issue_id: issue_id).pluck(:test_plan_id)

      # tag -> runs
      # Artifact'lerin kullanıldığı Test Koşularını bul
      sonuclar = fetch_artifact_run_tags(@cs, tag_name)
      @artifact_kiwi_tags = sonuclar[:artifact_kiwi_tags]
      @kiwi_run_tags = sonuclar[:kiwi_run_tags]

      # Bu issue için yapılan kod değişikliklerinden çıkartılan artifact'ler ile etiketlenmiş Test Run ID değerleri
      @kiwi_run_ids = @kiwi_run_tags.pluck("run")

      # her test test plan id değeri için tüm test senaryolarını çekelim
      @kiwi_runs = UlakTest::Kiwi.fetch_testrun_by_id__in_plan__in(@kiwi_run_ids, @test_plan_ids)

      # plan :
      #      -> cases
      #      -> runs:
      #             -> tags
      #             -> executions
      #
      # plan: [
      #   {
      #     cases : { .. }
      #     runs : [
      #       {
      #         executions: [
      #           tags : []
      #         ]
      #       }, ...
      #     ]
      #   }, ...
      # ]
      #
      # Planların içinde dön
      #   Her plan'ın koşularını bul
      #     Her koşunun etiketini bul ve ilişkilendir

      @test_plans_all = {}

      @test_plan_ids.each do |plan_id|
        # Plan's CASES
        test_cases = UlakTest::Kiwi.fetch_test_cases_by_plan_id(plan_id)

        # Plan's RUNS
        plan_runs = @kiwi_runs.select { |r| r["plan"] == plan_id }

        # Run's TAGS
        test_case_ids = test_cases.pluck("id")
        plan_run_ids = plan_runs.pluck("id")
        plan_runs_executions = UlakTest::Kiwi.fetch_testexecution_by_run__id_in_case__id_in(plan_run_ids, test_case_ids)
        plan_runs.each do |run|
          run_id = run["id"]
          run["tags"] = @kiwi_run_tags.select { |tag| tag["run"] == run_id }.pluck("name")

          # Run's EXECUTIONS
          run["executions"] = plan_runs_executions.select { |e| e["run"] == run_id }
        end
      end

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

  def view_changeset_tags
    @issue_id = params[:issue_id]
    @changeset_id = params[:changeset_id]

    @issue = Issue.find(@issue_id)

    # Check if the user is authorized to view the plugin.
    unless User.current.allowed_to?(:view_changeset_tags, @issue.project)
      # The user is not authorized to view the plugin.
      Rails.logger.info(">>> #{User.current.login} does not have permission to view the Issue Test Plans... !!!! <<<<")
      @error_message = "Kullanıcının bu bilgiye erişme yetkisi yok!"
      html_content = render_to_string(
        template: "errors/401",
        layout: false,
      )
      return render html: html_content
    end

    html_content = render_to_string(
      template: "templates/_content_issue_changeset_tags.html.erb",
      # layout: false ile tüm Redmine sayfasının derlenMEmesini sağlarız
      layout: false,
    )
    render html: html_content
  end

  def view_issue_test_plans
    issue_id = params[:issue_id]
    issue = Issue.find(issue_id)

    # Check if the user is authorized to view the plugin.
    unless User.current.allowed_to?(:view_issue_test_plans, issue.project)
      # The user is not authorized to view the plugin.
      Rails.logger.info(">>> #{User.current.login} does not have permission to view the Issue Test Plans... !!!! <<<<")
      @error_message = "Kullanıcının bu bilgiye erişme yetkisi yok!"
      html_content = render_to_string(
        template: "errors/401",
        layout: false,
      )
      return render html: html_content
    end

    @issue_test_plans = IssueTestPlan.where(issue_id: issue_id)
    if !@issue_test_plans
      Rails.logger.info(">>> Redmine görevine ait bir test planı bulunamadı! <<<<")
      return
    end

    test_plan_ids = @issue_test_plans.pluck(:test_plan_id)

    html_content = render_to_string(
      template: "templates/_content_issue_test_plans.html.erb",
      # layout: false ile tüm Redmine sayfasının derlenMEmesini sağlarız
      layout: false,
    )
    render html: html_content
  end

  def view_issue_tests
    @issue_id = params[:issue_id]
    @issue = Issue.find(@issue_id)
    @test_plan_ids = IssueTestPlan.where(issue_id: @issue_id).pluck(:test_plan_id)

    html_content = render_to_string(
      template: "templates/_tab_content_issue_tests.html.erb",
      # layout: false ile tüm Redmine sayfasının derlenMEmesini sağlarız
      layout: false,
      locals: {},
    )
    render html: html_content
  end
end
