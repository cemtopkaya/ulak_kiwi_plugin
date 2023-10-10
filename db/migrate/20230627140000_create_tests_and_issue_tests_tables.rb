# 20230627140000_create_tests_and_issue_tests_tables.rb

class CreateTestsAndIssueTestsTables < ActiveRecord::Migration[5.2]
  def change
    puts "Running migration: CreateTestsAndIssueTestsTables"

    create_table :issue_test_plans do |t|
      t.references :issue, index: true
      t.integer :test_plan_id
      t.string :name
      t.timestamps
    end
  end
end
