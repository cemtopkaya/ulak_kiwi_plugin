Rails.application.routes.draw do
  # Diğer rotalar burada

  # Kiwi API rotaları
  get "#{$NAME_KIWI_TESTS}/tests", to: "issue_test#get_tests"
  get "#{$NAME_KIWI_TESTS}/test_plans", to: "kiwi_api#fetch_test_plans"
  get "#{$NAME_KIWI_TESTS}/test_plans/:plan_id/cases", to: "kiwi_api#fetch_test_cases_by_plan_id"
  get "#{$NAME_KIWI_TESTS}/kiwi/check", to: "kiwi_api#check_connection"

  # Issue Test rotaları
  # get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results", to: "issue_test#view_issue_test_results"
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results", to: "issue_test#view_issue_tests"
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results/test_plans", to: "issue_test#view_issue_test_plans"
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results/changesets/:changeset_id/tags", to: "issue_test#view_changeset_tags"
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results/changesets/:changeset_id/tags/json", to: "issue_test#json_changeset_tags"
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results/changesets/:changeset_id/tags/runs", to: "issue_test#view_changeset_tag_artifacts_runs"
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tests/", to: "issue_test#get_issue_tests"
  post "#{$NAME_KIWI_TESTS}/issues/:issue_id/tests/:test_id", to: "issue_test#add_test_to_issue"
  delete "#{$NAME_KIWI_TESTS}/issues/:issue_id/tests/:test_id", to: "issue_test#remove_test_from_issue"
end
