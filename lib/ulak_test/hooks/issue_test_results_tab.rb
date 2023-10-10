require "action_view"
include ActionView::Helpers::SanitizeHelper

module UlakTest
  module Hooks
    class IssueTestResultsTab < Redmine::Hook::ViewListener
      def view_issues_show_details_bottom(context = {})
        Rails.logger.info(">>> IssueTestResultsTab.view_issues_show_details_bottom <<<<")

        issue = context[:issue]
        return render json: { error: "Issue not found" }, status: :not_found unless issue

        current_project = issue.project
        is_kiwi_test_module_enabled = current_project.module_enabled?($NAME_KIWI_TESTS)

        unless is_kiwi_test_module_enabled
          Rails.logger.info(">>> Kiwi Tests module is not enabled in the project #{current_project.name}, so the Kiwi Tests tab will not be created... !!!! <<<<")
          return
        end

        # Check if the user is authorized to view the plugin.
        unless User.current.allowed_to?(:view_tab_issue_test_results_tab, current_project)
          # The user is not authorized to view the plugin.
          Rails.logger.info(">>> #{User.current.login} does not have permission to view the Kiwi Tests tab, so this tab will not be created... !!!! <<<<")
          return
        end

        test_plan = IssueTestPlan
          .where(issue_id: issue.id)
          .select(:test_plan_id, :name)
          .first

        issue_data = { tests: test_plan, issue_id: issue.id }

        unless test_plan.blank?
          hook_caller = context[:hook_caller]
          controller = hook_caller.is_a?(ActionController::Base) ? hook_caller : hook_caller.controller

          output = controller.send(:render_to_string, {
            partial: "issues/tabs/tab_issue_test_results",
            locals: {
              tab_issue_assoc_revisions: {
                issue_data: issue_data.to_json,
              },
              tab_test_results: {
                issue_id: issue.id,
                issue: issue,
                tests: test_plan.to_json,
              },
            },
          })

          output
        end
      end
    end
  end
end
