# class IssueTestPlan < ActiveRecord::Base
#   belongs_to :issue
#   # test_plan_id ve name alanlarını ekle
#   validates :test_plan_id, presence: true
#   validates :name, presence: true
# end

class IssueTestPlan < ActiveRecord::Base
  belongs_to :issue
  # Daha fazla ilişkilendirme veya doğrulama kuralları eklemek için buraya ekleyebilirsiniz

  # issue_id sütunu, issue modeli ile ilişkilendirilmiştir
  # test_plan_id ve name sütunlarına karşılık gelen özellikler tanımlanmıştır

  # Ek olarak, created_at ve updated_at sütunları otomatik olarak izlenir ve güncellenir
end
