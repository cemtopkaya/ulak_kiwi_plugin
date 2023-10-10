class KiwiApiController < ApplicationController
  def sync_test_cases
    all_tests_before = Test.all
    products = UlakTest::Kiwi.fetch_products()
    products.each do |product|
      cases = UlakTest::Kiwi.fetch_test_cases(product["id"])
      Rails.logger.info(">>> cases: #{cases}")
      cases.each do |c|
        test = Test.find_or_create_by({ test_case_id: c["id"], summary: c["summary"], product_id: product["id"], category: c["category"], category_name: c["category__name"] })
        puts "test: #{test}"
      end
    end
    all_tests_after = Test.all

    render json: {
      before: all_tests_before.count,
      after: all_tests_after.count,
    }, status: :ok
  end

  def fetch_test_plans
    all_tests_before = Test.all
    plans = UlakTest::Kiwi.fetch_test_plans()
    Rails.logger.info(">>> plans: #{plans}")

    render json: plans, status: :ok
  end

  def fetch_test_cases_by_plan_id()
    plan_id = params[:plan_id]
    Rails.logger.info(">>> plan_id: #{plan_id}")
    unless plan_id
      raise ArgumentError, "plan_id parameter can't be nil and must be greater than 0"
    end

    cases = UlakTest::Kiwi.fetch_test_cases_by_plan_id(plan_id)
    Rails.logger.info(">>> cases: #{cases}")
    cases.each do |c|
      # test = Test.find_or_create_by({ test_case_id: c["id"], summary: c["summary"], plan_id: plan["id"], category: c["category"], category_name: c["category__name"] })
      puts "case: #{c}"
    end

    render json: {
      cases: cases,
    }, status: :ok
  end
end
