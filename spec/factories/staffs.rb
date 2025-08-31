FactoryBot.define do
  factory :staff do
    account { nil }
    first_name { "MyString" }
    last_name { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    background_check_passed { false }
  end
end
