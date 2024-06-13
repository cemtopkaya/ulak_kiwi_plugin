# encoding: UTF-8

class KiwiApiController < ApplicationController
  def check_connection
    begin
      is_accesable = UlakTest::Kiwi.is_kiwi_accessable()
      return render json: is_accesable, status: :ok
    rescue => e
    end

    return render json: {
                    is_accessable: false,
                    message: "Kiwi server is NOT accessable",
                  }, status: :ok
  end

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
    query = params[:q].downcase
    Rails.logger.info(">>> Aranan test planı: #{query}")

    all_tests_before = Test.all
    plans = UlakTest::Kiwi.fetch_test_plans()
    Rails.logger.debug(">>> plans: #{plans}")

    result = plans.select do |plan|
      plan["name"].downcase.include?(query) || plan["id"].to_s.include?(query)
    end

    render json: result, status: :ok
  end
end
