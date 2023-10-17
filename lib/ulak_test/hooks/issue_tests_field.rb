# encoding: UTF-8
require "action_view"
include ActionView::Helpers::SanitizeHelper

module UlakTest
  module Hooks
    class IssueTestsField < Redmine::Hook::ViewListener
      def self.upsert_issue_test(issue_id, project, new_test_plan_ids)

        # Check if the user is authorized to view the plugin.
        unless User.current.allowed_to?(:edit_issue_tests, project)
          # The user is not authorized to view the plugin.
          Rails.logger.info(">>> #{User.current.login} does not have permission to view the Issue Edit for Kiwi Tests field, so this tab will not be created... !!!! <<<<")
          return
        end

        old_test_plan_ids = IssueTestPlan
          .where(issue_id: issue_id) # encoding: UTF-8
          .select(:test_plan_id, :name)
          .pluck(:test_plan_id)

        removed_test_plan_ids = old_test_plan_ids - new_test_plan_ids
        added_test_plan_ids = new_test_plan_ids - old_test_plan_ids

        # Silinmeden önce DB'den silinenlerin journal mesajı çekiliyor
        removed_tests_journal = IssueTestPlan.where(test_plan_id: removed_test_plan_ids).pluck(:name).map { |test| "-#{test}-" }.join("\n* ")
        removed_test_plan_ids.each do |plan_id|
          IssueTestController.remove_test_from_issue(issue_id, plan_id)
        end

        added_test_plan_ids.each do |plan_id|
          IssueTestController.add_test_to_issue(issue_id, plan_id)
        end
        # Eklendikten sonra DB'den eklenen journal mesajı çekiliyor
        added_tests_journal = IssueTestPlan.where(test_plan_id: added_test_plan_ids).pluck(:name).join("\n* ")

        # Eklenen ve silinene test plan ID değerlerini tarihçeye de yazıyoruz
        journalize_issue_test_change(issue_id, removed_tests_journal, added_tests_journal)
      end

      def controller_issues_new_after_save(context = {})
        process_issue_tests(context)
      end

      def controller_issues_edit_after_save(context = {})
        process_issue_tests(context)
      end

      def view_issues_form_details_bottom(context = {})

        # Check if the user is authorized to view the plugin.
        unless User.current.allowed_to?(:edit_issue_tests, context[:issue].project)
          # The user is not authorized to view the plugin.
          Rails.logger.info(">>> #{User.current.login} does not have permission to view the Issue Edit for Kiwi Tests field, so this tab will not be created... !!!! <<<<")
          return
        end

        if context[:issue].new_record?
          # Eğer yeni bir ISSUE oluşturuluyorsa test_planları boş gelecek
          select_options = []
        else
          # Varolan ISSUE ise atanmış test_planlarını getir
          issue = context[:issue]
          plans = IssueTestPlan.where(issue_id: issue.id)
          # seçilmiş testlet buna benzer olacak > select_options = [["Option 1", "1"], ["Option 2", "2"],...]
          select_options = plans.map { |t| [t.name, t.test_plan_id, selected: "selected"] }
        end

        controller = context[:controller]
        label_field = controller.view_context.label_tag(:test_select_input, l(:issue_test_plans), class: "test_selec_input")
        select_field = controller.view_context.select_tag(:test_select_input, options_for_select(select_options), { label: "Tests", style: "width:100%", class: "test_select_input", multiple: true })

        controller = context[:hook_caller].is_a?(ActionController::Base) ? context[:hook_caller] : context[:hook_caller].controller

        output = controller.send(:render_to_string, {
          partial: "hooks/issues/view_issues_form_details_bottom",
          locals: { select_options: select_options },
        })

        context[:controller].view_context.content_tag(:p) do
          label_field + select_field + output.html_safe
        end
      end

      def view_issues_history_journal_bottom5(context = {})
        journal = context[:journal]
        issue = journal.issue if journal.present? # Issue objesini almak için

        return if issue.blank?

        journals = issue.journals.includes(:details)
        issue_tests_journal = journals.select { |journal| journal.notes == "Test Change" }
        return if issue_tests_journal.empty?

        content = ""
        issue_tests_journal.each do |journal|
          content << context[:controller].view_context.render(
            partial: "hooks/issues/issue_tests_history",
            locals: { journal: journal },
          )
        end

        content.html_safe
      end

      private

      def process_issue_tests(context)
        Rails.logger.info(">>> process_issue_tests kısmına geldik <<<")
        # Issue insert/edit sırasında oluşturulan form içinde özel bir eklentinin input alanının bilgisini çekmek için:
        new_test_plan_ids = context.dig(:params, :test_select_input)&.map(&:to_i) || []
        issue_id = context[:issue].id
        project = context[:issue].project
        IssueTestsField.upsert_issue_test(issue_id, project, new_test_plan_ids)
      end

      private

      # def self.journalize_issue_test_change(issue_id, added_test_ids, removed_test_ids)
      def self.journalize_issue_test_change(issue_id, removed_tests_for_journal, added_tests_for_journal)
        issue = Issue.find_by(id: issue_id)
        return unless issue

        # eklenen veya silinen yoksa journal değişmesin
        return unless !added_tests_for_journal.empty? || !removed_tests_for_journal.empty?

        result = ""
        if !added_tests_for_journal.empty?
          result += "h5. #{l(:text_issue_test_plans_added)}\n\n* #{added_tests_for_journal}\n\n"
        end

        if !removed_tests_for_journal.empty?
          result += "h5. #{l(:text_issue_test_plans_removed)}\n\n* #{removed_tests_for_journal}"
        end

        journal = issue.init_journal(User.current)
        journal.notes = result
        journal.save
      end
    end
  end
end
