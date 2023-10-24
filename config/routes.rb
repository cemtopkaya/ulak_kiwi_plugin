Rails.application.routes.draw do
  # Diğer rotalar burada

  # Kiwi API rotaları
  # Issue ile Test Planları arasında ilişki kurmak için bu uç nokta kullanılır. Issue eklenirken/düzenlenirken Test Planları buradan çekilir.
  get "#{$NAME_KIWI_TESTS}/test_plans", to: "kiwi_api#fetch_test_plans"
  # Kiwi sunucusuna bağlantı olup olmadığını kontrol etmek için kullanılır.
  get "#{$NAME_KIWI_TESTS}/kiwi/check", to: "kiwi_api#check_connection"

  # Issue Test rotaları
  # testleri göstereceğimiz sekmenin temel html yapısını çeker
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results", to: "issue_test#view_issue_tests"
  # issue ile ilişkili test planlarını <ol> olarak döner
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results/test_plans", to: "issue_test#view_issue_test_plans"
  # Kod değişiminin neticesinde derleme alınarak artifact'leri etiketleriz. Bu etiketleri <select> elemanı içinde döner
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results/changesets/:changeset_id/tags", to: "issue_test#view_changeset_tags"
  # Bir git tag ile yapılan test koşularını çeker
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tab/test_results/changesets/:changeset_id/tags/runs", to: "issue_test#view_changeset_tag_artifacts_runs"
  get "#{$NAME_KIWI_TESTS}/issues/:issue_id/tests/", to: "issue_test#get_issue_tests"
end
